---
name: hermes-multi-machine-sync
description: 跨机器同步 Hermes Agent 技能和配置 — 通过云存储（坚果云 Nutstore / Dropbox / Syncthing）实现多设备共享
trigger: 用户要求同步技能到多台设备 / 设置符号链接指向云盘 / 让 Hermes 技能在多设备间共享 / 坚果云同步
tags: [windows, symlink, nutstore, sync, multi-machine, junction, mklink]
---

# Hermes 多机同步工作流

## 概述

将 `~/.hermes/skills/` 指向云盘同步目录，使所有设备共享同一套技能库。其他 AI 助手（Claude Code, Cursor 等）也可以指向同一目录共享技能。

## 关键概念

- **符号链接** (symlink) — Linux/Mac 使用 `ln -s`
- **目录联接** (junction) — Windows 使用 `mklink /D`（不需要管理员权限）
- **云盘** — 坚果云、Dropbox、Syncthing、OneDrive 等自动同步的工具

## 步骤

### 前置：理解两种场景

**场景 A：从零开始** — 云盘还没有技能目录，需要复制本地技能过去
**场景 B：双向合并** — 云盘已有技能（来自另一台设备/之前的备份），需要合并两个方向的技能

无论哪种场景，最终目标都是让云盘目录包含**所有**技能（既有本地的，也有云盘已有的）。

### 1. 双向合并（关键步骤）

**无论哪种场景，都要先合并再建链接**，确保云盘目录是完整的超集。

#### 1a. 先将云盘中的技能复制到本地（场景 B 必需）

```bash
# 如果云盘已有技能，先复制到本地
cp -r <cloud-dir>/hermes-sync/skills/* ~/.hermes/skills/
cp -r <cloud-dir>/hermes-sync/skills/.[!.]* ~/.hermes/skills/  # 隐藏文件
```

#### 1b. 再将本地内置技能回填到云盘

```bash
# 检查差异
diff <(cd <cloud-dir>/hermes-sync/skills && find . -name "SKILL.md" | sort) \
     <(cd ~/.hermes/skills && find . -name "SKILL.md" | sort)
# 输出中 "^<" 是云盘有但本地缺的，">" 是本地有但云盘缺的

# 把本地有而云盘缺的技能逐个复制回去（注意保持目录结构）
for dir in autonomous-ai-agents/claude-code autonomous-ai-agents/codex; do
  target="<cloud-dir>/hermes-sync/skills/$dir"
  mkdir -p "$target" && cp -r "$HOME/.hermes/skills/$dir/"* "$target/"
done

# 批量复制整个分类目录下的技能
mkdir -p "<cloud-dir>/hermes-sync/skills/openclaw-imports"
for dir in ~/.hermes/skills/openclaw-imports/*/; do
  skillname=$(basename "$dir")
  target="<cloud-dir>/hermes-sync/skills/openclaw-imports/$skillname"
  mkdir -p "$target" && cp -r "$dir"* "$target/"
done

# 别忘了 Hermes 元数据文件
cp ~/.hermes/skills/.bundled_manifest "<cloud-dir>/hermes-sync/skills/"
cp ~/.hermes/skills/.curator_state "<cloud-dir>/hermes-sync/skills/"
```

#### 1c. 验证合并完成

```bash
# 用 `diff` 确认两个目录一致（不应该有差异了）
diff <(cd ~/.hermes/skills && find . -name "SKILL.md" | sort) \
     <(cd "<cloud-dir>/hermes-sync/skills" && find . -name "SKILL.md" | sort)
```

### 2. 建立符号链接

**Windows (目录联接 / Junction)：**

推荐用 **PowerShell** 创建目录联接，兼容所有上下文（包括从 WSL bash 调用）：

```powershell
# PowerShell（推荐，从 WSL 或 Windows 终端均可）
New-Item -ItemType Junction -Path "$env:USERPROFILE\.hermes\skills" -Target "<cloud-dir>\hermes-sync\skills" -Force
New-Item -ItemType Junction -Path "$env:USERPROFILE\.hermes\memories" -Target "<cloud-dir>\hermes-sync\memories" -Force
```

如果从 WSL 调用（`powershell.exe -Command`）：

```bash
# 从 WSL bash 创建 Windows 目录联接
powershell.exe -Command "New-Item -ItemType Junction -Path 'C:\Users\%USERNAME%\.hermes\skills' -Target '<cloud-dir>\hermes-sync\skills' -Force"
```

备选（仅限 Windows 原生 CMD 环境）：

```cmd
:: 仅限 Windows 原生 CMD（不能在 WSL 中使用）
move %USERPROFILE%\.hermes\skills %USERPROFILE%\.hermes\skills.bak
mklink /D %USERPROFILE%\.hermes\skills <cloud-dir>\hermes-sync\skills
```

> ⚠️ 在 Git Bash/MSYS2 中 `ln -s` 通常**不可用**（即使 Windows 支持符号链接，MSYS2 默认模式也可能失败）。
>
> ⚠️ **`cmd.exe /c mklink` 从 WSL 调用会失败。** 根因：cmd.exe 启动时继承 WSL 的 UNC 当前目录（`\\wsl.localhost\Ubuntu\home\kangle`），而 `mklink` 不支持 UNC 路径。报错："UNC paths are not supported." + "The filename, directory name, or volume label syntax is incorrect." **始终用 PowerShell 的 `New-Item -ItemType Junction` 替代。**

**Linux/macOS：**

```bash
mv ~/.hermes/skills ~/.hermes/skills.bak
ln -s <cloud-dir>/hermes-sync/skills ~/.hermes/skills
```

### 3. 验证

```bash
# 确认技能可访问
ls ~/.hermes/skills/dddog-profile/SKILL.md
ls ~/.hermes/skills/ | head -10
# 准确计数：统计 SKILL.md 文件数
find ~/.hermes/skills/ -name "SKILL.md" 2>/dev/null | wc -l
```

## 陷阱

### 1. `cp -r source/* dest/` 遗漏隐藏文件
`*` 通配符在 bash 中不匹配以 `.` 开头的文件。需要**两次** copy：
```bash
cp -r source/* dest/
cp -r source/.[!.]* dest/       # 复制 .xxx 隐藏文件
```
或者使用 rsync（默认包含隐藏文件）：
```bash
rsync -a source/ dest/
```

常见遗漏文件：
- `.archive/` — 归档的历史技能
- `.usage.json` — 使用统计
- `.bundled_manifest` — Hermes 内置技能清单
- `.curator_state` — curator 状态

### 2. Windows 符号链接权限
- `mklink /D`（目录联接）不需要管理员权限
- `mklink`（硬符号链接）需要管理员或开发者模式
- Git Bash `ln -s` 的行为取决于 MSYS2 的 `MSYS=winsymlinks` 环境变量设置。默认不开 symlink 模式

### 3. cmd.exe 路径中的空格
路径中有空格时用引号包裹即可，Windows 原生支持带空格路径。

### 4. 删除原目录后终端当前目录失效
删除 `~/.hermes/skills/` 后如果终端当前正在该目录中，后续命令会报 `No such file or directory`。
**解法：** 在 cmd.exe 调用中指定工作目录（`workdir`），或删除前先 `cd ~`。

### 5. Git Bash find 穿过 mklink/D 返回 0 条

在 Git Bash (MSYS2) 中，`find` 遍历 `mklink /D` 创建的 Windows 目录联接时可能返回 0 条记录，尽管文件确实存在且可直接访问。

```bash
# ❌ 会输出 0（误报）
find /c/Users/dddog/.hermes/skills -name "SKILL.md" | wc -l

# ✅ 用 ls 逐一验证关键路径
ls /c/Users/dddog/.hermes/skills/dddog-profile/SKILL.md
ls /c/Users/dddog/.hermes/skills/creative/sketch/SKILL.md
ls -d /c/Users/dddog/.hermes/skills/*/ | wc -l   # 只数子目录，可靠
```

### 6. WSL 中创建 Windows 目录联接只能用 PowerShell

从 WSL bash 调用 `cmd.exe /c mklink` 会失败（UNC 路径问题）。始终用 `powershell.exe -Command "New-Item -ItemType Junction ..."` 替代。

### 7. 云盘冲突

两台设备同时修改同一 skill 会产生冲突文件（如 `SKILL.md (冲突 2026-05-10).md`），需要定期清理。

```bash
# 查找云盘产生的冲突文件
find ~/.hermes/skills -name "*(冲突*" -o -name "*conflict*" 2>/dev/null
```

## 多 AI 助手共享

同步目录可供其他 AI 工具共享。技能路径下的 `.bundled_manifest` 和 `.curator_state` 是 Hermes 专用元数据，其他工具会忽略它们。

## 用户配置共享（USER.md）

设备间共享用户偏好信息（姓名、语言风格、工具偏好等），可以通过符号链接共享 `USER.md`：

### 前置：合并内容

两份 USER.md 通常有重叠和互补内容。用 `diff` 或肉眼检查，将两边的**独有条目**（`§` 分隔）合并到云盘上的版本，确保一条不丢。

```bash
# 内容概览
grep '^§' file1.md | wc -l    # 条目数
head -3 file1.md               # 看一眼
```

### 建立链接

**Windows：**
```cmd
rem 先备份原文件
move %USERPROFILE%\.hermes\memories\USER.md %USERPROFILE%\.hermes\memories\USER.md.bak

rem ⚠️ 删掉云盘上遗留的 .lock 文件（来自另一台机器的孤儿锁）
del <cloud-dir>\hermes-sync\memories\USER.md.lock
del <cloud-dir>\hermes-sync\memories\MEMORY.md.lock

rem 建立文件符号链接
mklink %USERPROFILE%\.hermes\memories\USER.md <cloud-dir>\hermes-sync\memories\USER.md
```

注意：`mklink`（不加 `/D`）创建**文件**符号链接，`mklink /D` 创建目录联接。

**Linux/macOS：**
```bash
mv ~/.hermes/memories/USER.md ~/.hermes/memories/USER.md.bak
ln -s <cloud-dir>/hermes-sync/memories/USER.md ~/.hermes/memories/USER.md
```

### 重要限制

- **USER.md 可以共享**，因为用户偏好通用性强
- **MEMORY.md 不能共享**，每台机器的环境信息、凭证、项目路径不同
- 多机同时写入可能相互覆盖。Hermes 的 `memory(action="add"/"replace", target="user")` 是整段操作，不是三路合并
- 冲突时坚果云会创建 `USER.md (冲突副本).md`，需手动整理

## 归档参考

旧版方案（已归档在 `.archive/` 下的技能）：
- `multi-machine-nutstore-sync` — 旧版 Nutstore 多机同步
- `multi-pc-hermes-setup` — 旧版多 PC 配置
- `openviking-cross-machine` — OpenViking 跨机器设置
