---
name: hermes-windows-uninstall
description: Hermes Agent Windows 版完全卸载流程——逆向 install.ps1 的所有操作，含符号链接/ junction 安全处理
category: devops
---

# Hermes Agent Windows 卸载完全指南

## 触发场景

用户要求卸载 Windows 原生 Hermes Agent，或重装前需要清理旧版本。

## 核心风险：符号链接/目录联接

**卸载前必须检查 `skills` 和 `memories` 目录是否是符号链接或 junction。**

```bash
# WSL 中检查
ls -la ~/.hermes/skills     # lrwxrwxrwx → symlink
ls -la ~/.hermes/memories   # lrwxrwxrwx → symlink
```

如果 `skills` 或 `memories` 是符号链接或 junction：
- **只删除链接本身**，绝对不要 `rm -rf` 整个目录
- 坚果云同步目录中的原始文件必须保留

```bash
# WSL 中安全删除符号链接
unlink ~/.hermes/skills      # 只删链接，不碰目标
unlink ~/.hermes/memories

# Windows 中安全删除 junction
cmd /c "rmdir \"%LOCALAPPDATA%\hermes\skills\""
cmd /c "rmdir \"%LOCALAPPDATA%\hermes\memories"
```

## 安装脚本做了什么（→ 卸载时反向操作）

| 步骤 | 安装操作 | 卸载操作 |
|------|---------|---------|
| 1 | 安装 uv → `~/.local/bin/uv.exe` | `uv self uninstall`（可选） |
| 2 | uv 安装 Python 3.11 | 通常保留（其他项目可能用） |
| 3 | 安装 PortableGit → `%LOCALAPPDATA%\hermes\git\` | 删除（可选） |
| 4 | 安装 Node.js → `%LOCALAPPDATA%\hermes\node\` | 删除（可选） |
| 5 | 克隆仓库 → `%LOCALAPPDATA%\hermes\hermes-agent\` | 删除 |
| 6 | 创建 venv → `hermes-agent\venv\` | 删除（含在仓库目录中） |
| 7 | 添加 `venv\Scripts` 到用户 PATH | 从 PATH 移除 |
| 8 | 设置 `HERMES_HOME` 环境变量 | 删除 env var |
| 9 | 写 config.yaml / .env 模板 | 按需保留或删除 |

## 完整卸载步骤

```powershell
# 1. 停止 hermes 进程
Stop-Process -Name hermes -Force -ErrorAction SilentlyContinue

# 2. 安全删除符号链接（如果有）
# 先检查：dir %LOCALAPPDATA%\hermes\ 看是否有 <JUNCTION> 或 <SYMLINKD> 标记
cmd /c "rmdir \"%LOCALAPPDATA%\hermes\skills\""     # 仅删链接
cmd /c "rmdir \"%LOCALAPPDATA%\hermes\memories\""   # 仅删链接

# 3. 删除安装目录（仓库 + venv）
Remove-Item -Recurse -Force "$env:LOCALAPPDATA\hermes\hermes-agent"

# 4. 从用户 PATH 移除
$path = [Environment]::GetEnvironmentVariable("Path", "User")
$newPath = ($path -split ";" | Where-Object { $_ -notlike "*hermes-agent*" }) -join ";"
[Environment]::SetEnvironmentVariable("Path", $newPath, "User")

# 5. 删除环境变量
[Environment]::SetEnvironmentVariable("HERMES_HOME", $null, "User")

# 6. 删除 PortableGit / portable Node（可选）
Remove-Item -Recurse -Force "$env:LOCALAPPDATA\hermes\git"
Remove-Item -Recurse -Force "$env:LOCALAPPDATA\hermes\node"

# 7. 删除配置和数据（按需，⚠️ 包含 .env、sessions、logs）
Remove-Item -Recurse -Force "$env:LOCALAPPDATA\hermes"
```

## 保留配置的重装场景

```powershell
# 先备份
Copy-Item "$env:LOCALAPPDATA\hermes\.env" "$env:USERPROFILE\hermes-env-backup"
Copy-Item "$env:LOCALAPPDATA\hermes\config.yaml" "$env:USERPROFILE\hermes-config-backup"

# 卸载（保留 skills/memories 链接）

# 重装后恢复
Copy-Item "$env:USERPROFILE\hermes-env-backup" "$env:LOCALAPPDATA\hermes\.env"
Copy-Item "$env:USERPROFILE\hermes-config-backup" "$env:LOCALAPPDATA\hermes\config.yaml"
```

## 卸载脚本

完整可用的 PowerShell 卸载脚本见 `references/uninstall.ps1`。

用法：
```powershell
# 预览模式（不实际删除）
powershell -ExecutionPolicy ByPass -File uninstall.ps1 -DryRun

# 完全卸载
powershell -ExecutionPolicy ByPass -File uninstall.ps1

# 保留配置
powershell -ExecutionPolicy ByPass -File uninstall.ps1 -KeepConfig

# 保留 uv / Git / Node
powershell -ExecutionPolicy ByPass -File uninstall.ps1 -KeepUv -KeepGit -KeepNode
```

## 注意事项

- Hermes 没有内置 `uninstall` 命令（截至 2026-05），需手动清理
- `hermes.exe uninstall` 命令不存在，不要尝试
- 如果 hermes 是通过 `pip install hermes-agent` 安装的（非 install.ps1），卸载方式不同：`pip uninstall hermes-agent`
- 删除 `%LOCALAPPDATA%\\hermes` 会同时删除 sessions、logs、cron 等数据

## ⚠️ 实战踩坑（2026-05-20）

### hermes-agent 目录删除失败
venv 中的 `python.exe` 被当前 Hermes 进程占用时，`Remove-Item -Recurse -Force` 报错。
**解决**：先 `Get-Process -Name 'python' | Stop-Process -Force`，等 2 秒再删。

### uv self uninstall 不存在
`uv self uninstall` 命令不存在（截至 2026-05）。`uv self` 只有 `update` 和 `version` 子命令。
**解决**：手动 `Remove-Item "$env:USERPROFILE\.local\bin\uv.exe"`，或保留 uv（其他项目可能用）。

### PowerShell 变量转义
从 WSL 调用 `pwsh.exe -Command "$var = ..."` 时，`$` 会被 WSL bash 解释为空。
**解决**：复杂命令一律写 `.ps1` 脚本文件再 `pwsh.exe -File` 执行。

### WSL 中 cmd 不可用
WSL 环境中没有 `cmd.exe`，`cmd /c` 会报 "command not found"。
**解决**：用 `pwsh.exe` 替代，或从 WSL 直接操作 Windows 文件系统路径。
