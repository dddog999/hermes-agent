# pwsh.exe 替代 WSL bash 工作流

> 2026-05-10 实测记录

## 背景

Hermes gateway 运行在 WSL 别名下（`/home/dddog/.hermes/hermes-agent/venv/bin/hermes`），terminal 工具使用 WSL bash（`/bin/bash`）。用户希望用 pwsh（PowerShell）替代 WSL bash。

## 测试结果

| 测试 | 结果 |
|------|------|
| `terminal(command="echo hello")` foreground | ❌ exit 126 |
| `terminal(command="echo hello", pty=true)` | ❌ exit 126 |
| `terminal(background=true, command="echo hello")` | ✅ exit 0 |
| `process(action="log", session_id="proc_xxx")` | ✅ 正常读取输出 |
| `terminal(background=true, command="pwsh -NoLogo -NoProfile -Command 'Get-Host \| Select Version'")` | ✅ pwsh 7.6.1（WSL） |
| `terminal(background=true, command="pwsh.exe -NoLogo -NoProfile -Command 'Get-Host \| Select Version'")` | ✅ pwsh.exe 7.5.5（Windows） |

## 关键发现

1. **exit code 126 与后台进程无关** — `process list` 返回空列表，foreground 仍然 126
2. **background 模式绕过此问题** — 每次创建独立子进程
3. **config.yaml 无 terminal 段** — Hermes 使用默认 local backend，硬编码找 bash
4. **pwsh.exe 可从 WSL bash 调用** — WSL interop 机制允许执行 Windows 可执行文件

## 推荐工作流

当需要执行 Windows 命今时：

```
terminal(background=true, command="pwsh.exe -NoLogo -NoProfile -Command '...'")
# 等几秒
process(action="log", session_id="proc_xxx")
```
