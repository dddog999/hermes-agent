# 两个 Hermes 实例分析（2026-05-10 会话记录）

## 背景

系统运行着两个独立的 Hermes Agent 实例，各有各的痛点。

## 问题 1：Windows 原生 Hermes — gateway 重启自动关闭

| 项目 | 值 |
|------|-----|
| 进程路径 | `C:\Users\dddog\AppData\Local\Programs\Python\Python312\Scripts\hermes.exe` |
| `sys.platform` | `"win32"` |
| 触发方式 | 飞书/微信发 `/restart` 或 CLI `hermes gateway restart` |

**根因**：`gateway/run.py:2631-2660` 的 `_launch_detached_restart_command()` 是纯 Unix 实现：

- `bash -lc` → Windows 无原生 bash
- `setsid` → Windows 不存在
- `kill -0` → 无 Unix 信号机制

三样全不可用 → `subprocess.Popen` 抛 `FileNotFoundError` → catch 后只 log error → gateway 停止不重启。

**辅助问题**：`loop.add_signal_handler(SIGTERM)` 在 Windows 上抛 `NotImplementedError`，被 `except: pass` 静默吃掉 → 发 SIGTERM 时无 drain/无 resume_pending 标记 → 上下文丢失。

**修复方向**：加 `sys.platform == "win32"` 分支，用 `sys.executable -c` watcher + `subprocess.DETACHED_PROCESS` 替代。

## 问题 2：WSL Hermes（微信 gateway）— 终端不能用 pwsh

| 项目 | 值 |
|------|-----|
| 进程路径 | `/home/dddog/.hermes/hermes-agent/venv/bin/hermes`（bash alias） |
| `sys.platform` | `"linux"` |
| 终端 shell | `/bin/bash`（WSL bash） |

**根因**：`_find_bash()` 在 POSIX（包括 WSL）上永远返回 `/bin/bash`，完全不读 config.yaml 的 `terminal.shell` 配置。

**config 配置了但无效**：
```yaml
terminal:
  shell: pwsh.exe
  shell_args:
  - -NoProfile
  - -Command
```

`_find_bash()` 不读 config，`gateway/run.py` 的 config→env 桥接也不包含 `shell`/`shell_args`。

**`_wrap_command()` 的 bash 语法假设**：base.py 生成的包裹脚本（`source`、`export -p`、`||`、`&&`、`builtin cd`）全是 bash 语法，与 pwsh 完全不兼容。

**可用但局限的 workaround**：
```bash
# WSL bash 中直接调用 pwsh.exe（通过 WSL interop）
terminal(background=true, command="pwsh.exe -NoLogo -NoProfile -Command '...'")
```

**修复方向**：三种可能：
1. `_find_bash()` 读取 `terminal.shell` 配置 + env var 桥接
2. `_wrap_command()` 检测 pwsh 输出 PS 语法
3. 不改 shell 二进制，命令前加 `pwsh.exe -c` 包装

## config.yaml 共享

两个实例通过坚果云共享同一份 `~/.hermes/config.yaml`。`terminal.shell` 改动会影响两边——WSL 上配置 `pwsh.exe` 对未来修复有利，但改动前需确认 Windows 原生不受影响。

## 错误修正记录

**初始分析错误**：我假设 gateway 跑在 Windows 原生 Python 上，`_launch_detached_restart_command()` 是重启 bug 的唯一根因。

**用户纠正**：
1. 微信消息来自于 WSL Hermes（`sys.platform == "linux"`），其分析和我的初始前提无关
2. 实际要修两个问题：Windows 原生 gateway 重启 + WSL 终端 pwsh
3. 用户的 WSL 环境分析揭示了 `_find_bash()` 不读 config 的根本设计缺口

**吸取教训**：遇到平台相关问题时，先确认当前对话的 Hermes 实例运行在哪个环境，不要假设。
