# Nutstore 同步锁导致 skill_manage 写入失败调查记录

> 日期：2026-05-25
> 环境：WSL (Ubuntu) → 9p/DrvFs → Windows NTFS → 坚果云 (Nutstore)

## 症状

技能目录中积累大量 `.SKILL.md.tmp.XXXX` 文件。2026-05-25 实测：245 个 tmp 文件分布在 66 个技能目录中。

## 诊断

### 1. 确认 WSL 符号链接指向

```bash
~/.hermes/skills -> /mnt/c/Users/kangle/Nutstore/1/myNutstore (1)/hermes-sync/skills
```

### 2. 确认 9p 挂载选项

```
C:\ on /mnt/c type 9p (rw,noatime,aname=drvfs;path=C:\;...,cache=5,access=client,...)
```

`cache=5` = 松散缓存模式；`access=client` = 客户端权限控制。

### 3. 创建+写 tmp 成功，但 rename 失败

```python
# skill_manager_tool.py _atomic_write_text() 流程：
fd, temp_path = tempfile.mkstemp(prefix=".SKILL.md.tmp.")  # ✅ 成功
f.write(content)                                              # ✅ 成功
os.replace(temp_path, target)                                 # ❌ PermissionError [Errno 13]
```

### 4. 压力测试复现

20 次循环中 3 次 `os.replace` 失败（~15% fail rate）。同一时刻 Nutstore 在同步 SKILL.md 时持有文件锁。

### 5. 清理同样可能失败

```python
except Exception:
    try:
        os.unlink(temp_path)  # 也可能 PermissionError
    except OSError:
        # 日志记录但 temp 文件残留
```

## 根因

**WSL 9p/DrvFs 没有文件锁的相干视图**。Windows NTFS 支持文件锁，Nutstore 同步时锁住 SKILL.md，但 WSL 的 9p 驱动看不到这个锁的语义——写操作被放行（通过缓存），但 `rename` 操作在写入锁文件时被 Windows 拒绝。

## 影响范围

- 所有通过 `skill_manage` 修改 Nutstore 上技能的操作
- 包括：`patch`、`edit`、`create`、`write_file` 等所有调用 `_atomic_write_text` 的动作
- 仅在 Nutstore 同步活跃时触发，非 100% 复现
- 不触发于 Linux ext4 原生文件系统

## 修复方案

1. **短期**：手动清理 tmp 文件，每次 `skill_manage` 后验证
2. **中期**：~/.hermes/skills 从 Nutstore 符号链接改为本地 ext4 + Git 同步
3. **长期**：可考虑提交 PR 给 Hermes，增加 `os.replace` 失败时的重试/退避逻辑