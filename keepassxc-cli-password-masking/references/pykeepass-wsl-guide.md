# pykeepass WSL 读取坚果云 KeePass DB 完整指南

## 路径映射

- Windows: `C:\Users\<username>\Nutstore\...`
- WSL: `/mnt/c/Users/<username>/Nutstore/...`
- 注意：WSL 用户名和 Windows 用户名可能不同，用 `ls /mnt/c/Users/` 确认实际目录名

## 完整工作流

```python
import pykeepass

# 1. 找到正确的 DB 路径
#坚果云同步路径：
db_path = "/mnt/c/Users/<windows_user>/Nutstore/1/keepass/Database.kdbx"

# 2. 如果遇到 DPAPI keyfile 问题（pykeepass.CredentialsError: Invalid credentials）
#    需要在 Windows KeePass 里禁用 DPAPI:
#    文件 → 数据库设置 → 安全 → 
#    取消勾选「使用 Windows 用户账户作为额外保护」→ 确定 → 重新保存

# 3. 用主密码打开（不是坚果云密码）
kp = pykeepass.PyKeePass(db_path, password="KeePass主密码")

# 4. 搜索条目
for e in kp.entries:
    if "keyword" in ((e.url or "") + (e.title or "")).lower():
        print(f"标题: {e.title}")
        print(f"用户名: {e.username}")
        print(f"密码: {e.password}")
        print(f"URL: {e.url}")
        if e.notes:
            print(f"备注: {e.notes[:300]}")
```

## 常见错误

| 错误 | 原因 | 解法 |
|------|------|------|
| ModuleNotFoundError: pykeepass | 没安装 | `pip install pykeepass` |
| Invalid credentials | 密码错 或 DPAPI keyfile | 禁用 DPAPI |
| No such file | 路径错误 | 用 `ls /mnt/c/Users/` 确认目录名 |
| FileNotFoundError | Nutstore 没同步 | Windows 上打开坚果云确认同步完成 |

## 已知局限性

- pykeepass 读不到被 KeePass 标记为 "hidden" 的字段
- 某些特大家庭版 KeePass 加密插件不兼容
- 坚果云可能缓存旧版 DB，多等等或手动触发同步
