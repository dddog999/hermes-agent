# hermes-windows Phase 1-3 成果存档
> 本次 session 完成 Phase 1（扫描）+ Phase 2（P0/P1/P2 修复）+ Phase 3（平台检测函数）

## 目录结构

- **开发路径**：`/home/dddog/hermes-windows-wsl/`（WSL 原生，单 d）
- **安装目标**：`C:\Users\dddog\hermes-agent-windows\hermes-agent\`（pip install -e . 在这层执行）
- **GitHub repo**：`dddog999/hermes-windows`（私有，空，push 被 Tailscale TUN 阻断）

## Phase 1 发现（P0=5 阻断，P1=PATH分隔符，P2=20+已有分支）

| 级别 | 问题 | 文件 | 状态 |
|------|------|------|------|
| P0 | termios/fcntl 导入 | hermes_cli/pty_bridge.py | 已修复 |
| P0 | os.killpg/os.getpgid | gateway/platforms/whatsapp.py | 已修复 |
| P0 | pwd 模块导入 | scripts/profile-tui.py | 已修复 |
| P0 | os.killpg | tools/browser_tool.py | 已修复 |
| P0 | termios/fcntl 导入 | tools/environments/local.py | 已修复 |
| P1 | PATH 分号分隔符 | local.py, code_execution_tool.py | 已修复 |
| P1 | temp 路径 is_absolute() | local.py, code_execution_tool.py, process_registry.py | 已修复 |

## git archive prefix 陷阱

`git archive --prefix=hermes-agent/ HEAD -o zip` 会在 zip 里创建 `hermes-agent/` 子目录。

Windows 安装时必须 cd hermes-agent 后再 pip install -e .

## Tailscale TUN 阻断 git push

绕过方案：WSL 端 `git archive HEAD | python3 -m http.server`，Windows 端 `curl` 下载。
