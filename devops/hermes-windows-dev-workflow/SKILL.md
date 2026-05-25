---
name: hermes-windows-dev-workflow
description: Hermes Agent Windows 适配开发工作流——独立目录原则、WSL pathlib 陷阱、Session 文件持久化
category: devops
---

# Hermes Windows 适配开发工作流

## 核心原则

**开发和生产彻底分离，永远不在跑着 Hermes 的目录里改代码。**

```
源仓库
    ↙              ↘
WSL 生产版          Windows 开发版
~/.hermes/hermes-agent/    C:\Users\dddog\hermes-windows\
永远不改动           独立克隆，独立 git
```

## 克隆到 Windows 目录

```bash
# 在 WSL 终端执行
git clone --branch feat/windows-native \
  https://ghp_X9...@github.com/dddog999/hermes-agent.git \
  /mnt/c/Users/ddddog/hermes-windows/
```

## WSL pathlib 路径陷阱

WSL 中 Python `pathlib` 访问 Windows 路径时，**必须带尾斜杠**：

```python
import pathlib
p = pathlib.Path("/mnt/c/Users/ddddog/hermes-windows/")  # ✅
p = pathlib.Path("/mnt/c/Users/ddddog/hermes-windows")   # ❌ exists=False
```

bash `cd` 两种都能用，但 Python `os.chdir()` 和 `subprocess.run(cwd=...)` 必须带尾斜杠。
原因：WSL DrvFs 挂载行为差异。

## Session 文件持久化陷阱（重要）

**Subagent 子进程写入的文件不一定持久化到磁盘。**

子进程调用 `write_file` 时，返回成功不代表数据已 fsync 到磁盘。如果子进程被 kill 或会话意外结束，文件会丢失。

**防御措施：**
1. 所有关键文件写入后，立即用 `ls` 或 `cat` 验证存在
2. 改完 config.yaml 后立刻 grep 验证内容正确
3. 重要改动在当前 agent 主进程（不是子 agent）完成

```bash
# 验证示例
ls -la /home/ddddog/.hermes/config.yaml
grep sensenova /home/ddddog/.hermes/config.yaml
```

## GitHub 私有仓库创建前提

需要 `repo` scope，否则 API 返回 `401 Bad credentials`：

- **Fine-grained token**：https://github.com/settings/tokens → Repository access: All repositories → Contents ✅ + Administration ✅ → Save
- **Classic token**：勾选 `repo` scope

## ⚠️ hermes 命令路径陷阱（重要）

`hermes` 在 WSL bash 终端里是 **bash 别名**，不是 Windows 原生 exe：

```bash
$ type hermes
hermes is aliased to `cd ~/.hermes/hermes-agent; ./venv/bin/hermes'
```

终端工具实际运行在 **WSL bash**（`HOME=/home/dddog`, `SHELL=/bin/bash`），所以直接敲 `hermes` 会调用 WSL 版本（`/home/dddog/.hermes/hermes-agent/venv/bin/hermes`），**不是** Windows 原生版本。

**Windows 原生 hermes.exe 路径：**

```
C:\Users\dddog\AppData\Local\Programs\Python\Python312\Scripts\hermes.exe
```

**全平台 Gateway 启动：**
```bash
/mnt/c/Users/dddog/AppData/Local/Programs/Python/Python312/Scripts/hermes.exe gateway run --replace
```

### 检查当前 shell 环境
```bash
echo "SHELL: $SHELL"
echo "HOME: $HOME"
# 如果 HOME=/home/dddog → 这是 WSL bash
# 如果 HOME=/c/Users/dddog → 这是 Git Bash
```

### Windows Gateway 开机自启（Task Scheduler）

不能用 `hermes gateway install`（只支持 Linux systemd）。用 PowerShell 注册计划任务：

```powershell
Register-ScheduledTask -TaskName HermesGateway -Action (New-ScheduledTaskAction -Execute "C:\Users\dddog\AppData\Local\Programs\Python\Python312\Scripts\hermes.exe" -Argument "gateway run --replace") -Trigger (New-ScheduledTaskTrigger -AtLogon -User dddog) -Principal (New-ScheduledTaskPrincipal -UserId dddog -RunLevel Limited) -Force
```

开机登录后自动启动 Gateway，无需手动干预。

### WeChat/Weixin 原生 Windows 配置

1. 微信使用腾讯 iLink Bot API（个人微信机器人，非公众号）
2. Token 有失效期，过期后必须重新扫码登录
3. 通过 `hermes gateway setup` 交互式扫码，或直接调 `qr_login()` 获取新 token
4. 扫码后 iLink API 返回字段名：`bot_token`、`ilink_bot_id`（非 `token`/`account_id`）
5. 微信单条消息上限 `MAX_MESSAGE_LENGTH = 2000` 字符
6. 微信配置存于 `.env` 的 `WEIXIN_*` 变量

## ⚠️ 代码同步：hermes-windows → site-packages（重要）

**改 `hermes-windows` 目录的代码不会自动生效。** Windows 上实际运行的 gateway 是 pip 安装到 site-packages 的版本：

```
实际运行：C:\Users\dddog\AppData\Local\Programs\Python\Python312\Lib\site-packages\
开发目录：C:\Users\dddog\hermes-windows\
```

**每次改完代码必须手动复制：**

```powershell
# 复制 gateway/run.py
Copy-Item -Path 'C:\Users\dddog\hermes-windows\gateway\run.py' `
  -Destination 'C:\Users\dddog\AppData\Local\Programs\Python\Python312\Lib\site-packages\gateway\run.py' -Force

# 复制 tools/environments/local.py
Copy-Item -Path 'C:\Users\dddog\hermes-windows\tools\environments\local.py' `
  -Destination 'C:\Users\dddog\AppData\Local\Programs\Python\Python312\Lib\site-packages\tools\environments\local.py' -Force
```

**验证复制成功：**
```powershell
# 检查文件修改时间
Get-Item 'C:\Users\dddog\AppData\Local\Programs\Python\Python312\Lib\site-packages\gateway\run.py' | Select-Object LastWriteTime
```

**注意**：不要用 `pip install -e .`（editable install），因为 WSL 的 site-packages 可能通过 .pth 文件指向 WSL 路径，导致 Windows Python 加载错误的模块。

### Windows 上 os.execv 不可靠

`os.execv` 在 Windows 上**不会替换当前进程**（Windows 没有 POSIX exec 语义）。watcher 脚本中应使用 `subprocess.Popen` 启动新进程，然后让 watcher 自然退出：

```python
# ❌ Windows 上不可靠
os.execv(cmd[0], cmd)

# ✅ Windows 上正确做法
subprocess.Popen(
    cmd,
    stdout=subprocess.DEVNULL,
    stderr=subprocess.DEVNULL,
    creationflags=(
        subprocess.DETACHED_PROCESS
        | subprocess.CREATE_NEW_PROCESS_GROUP
    ),
)
```

### Watcher 进程调试技巧

watcher 的 stdout/stderr 都重定向到 DEVNULL，无法直接看到输出。**调试时写文件日志：**

```python
log_path = os.path.join(os.environ.get('USERPROFILE', '.'), '.hermes', 'logs', 'watcher.log')

def log(msg):
    try:
        with open(log_path, 'a') as f:
            f.write('[watcher] ' + msg + '\n')
    except Exception:
        pass
```

然后检查 `C:\Users\dddog\.hermes\logs\watcher.log`。

### WSL bash.exe 与 Git Bash 区分

Windows 上 `_find_bash()` 可能错误返回 WSL bash（`C:\Windows\System32\bash.exe`），因为 `shutil.which("bash.exe")` 先找到 WSL 的。WSL bash 不能运行 `_wrap_command()` 生成的 bash 脚本。

**检测方法**（通过路径特征排除 WSL bash）：

```python
def _is_wsl_bash(path: str) -> bool:
    lower = path.lower()
    return (
        r"\windows\system32\bash.exe" in lower
        or r"\windows\sysnative\bash.exe" in lower
        or r"\windowsapps\bash.exe" in lower
    )
```

## 上游同步

`feat/windows-native` 单独同步：
```bash
cd /mnt/c/Users/ddddog/hermes-windows/
git fetch origin
git merge origin/fix/patch-timeout
git push
```

`fix/patch-timeout` 的每天 03:00 Cronjob 不影响 `feat/windows-native`，两个分支独立。

## ⚠️ Gateway 重启在 Windows 上自动关闭（重要）

### 根因

`gateway/run.py` 的 `_launch_detached_restart_command()` (line 2631) 是纯 Unix 实现：

```python
# gateway/run.py:2631-2660
async def _launch_detached_restart_command(self) -> None:
    shell_cmd = (
        f"while kill -0 {current_pid} 2>/dev/null; do sleep 0.2; done; "
        f"{cmd} gateway restart"
    )
    setsid_bin = shutil.which("setsid")
    if setsid_bin:
        subprocess.Popen([setsid_bin, "bash", "-lc", shell_cmd], ...)
    else:
        subprocess.Popen(["bash", "-lc", shell_cmd], ...)
```

三个 Windows 不兼容点：

| 问题 | 原因 | 后果 |
|------|------|------|
| `kill -0 PID` | Windows 没有 Unix 信号 kill | 等待循环失败或立即完成 |
| `setsid` | Windows 不存在 | 永远走 else 分支 |
| `bash -lc` | Windows 无原生 bash | `FileNotFoundError` 或 Git Bash 下的不可靠行为 |

**结果：** 子进程抛 `FileNotFoundError`（catch 后只 log error），或提前执行 → 旧网关进程未退出 → PID 文件冲突 → **gateway 彻底停止不重启**。

### 触发路径

```
/restart 命令 → _handle_restart_command() (line 7357)
→ 无 INVOCATION_ID（非 systemd）→ request_restart(detached=True)
→ _launch_detached_restart_command() 失败 → gateway 停止
```

### 信号处理也静默降级

`start_gateway()` (line 14804-14815)：
```python
for sig in (signal.SIGINT, signal.SIGTERM):
    try:
        loop.add_signal_handler(sig, shutdown_signal_handler, sig)
    except NotImplementedError:
        pass  # ← Windows 上静默跳过！无 graceful shutdown！
```

后果：`os.kill(pid, SIGTERM)` 触发 Python 默认 SIGTERM 处理 → `sys.exit(1)` → **无 drain、无 resume_pending 标记**。

### 修复方向

给 `_launch_detached_restart_command()` 加 `sys.platform == "win32"` 分支：

```python
if sys.platform == "win32":
    # 用 python -c watcher 替代 bash -lc
    watcher_script = textwrap.dedent("""\
        import os, subprocess, sys, time
        pid = int(sys.argv[1])
        cmd = sys.argv[2:]
        deadline = time.monotonic() + 120
        while time.monotonic() < deadline:
            try:
                os.kill(pid, 0)  # Windows 上通过 WaitForSingleObject 检查
            except (ProcessLookupError, PermissionError):
                break
            time.sleep(0.2)
        subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            creationflags=subprocess.CREATE_NEW_PROCESS_GROUP | subprocess.DETACHED_PROCESS)
    """)
    subprocess.Popen(
        [sys.executable, "-c", watcher_script, str(current_pid),
         *_rebuild_hermes_cmd_parts()],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        creationflags=subprocess.CREATE_NEW_PROCESS_GROUP | subprocess.DETACHED_PROCESS,
    )
    return
```

关键：
- `os.kill(pid, 0)` 在 Windows 上可用（通过 `WaitForSingleObject` 检查进程存活）
- `subprocess.DETACHED_PROCESS` = Windows 原生分离进程（无控制台）
- `subprocess.CREATE_NEW_PROCESS_GROUP` = 新进程组（避免 Ctrl+C 传播）
- `sys.executable` 确保使用相同 Python 解释器

### CLI `hermes gateway restart` 路径

`hermes_cli/gateway.py:4530-4538` 的 manual restart（无 systemd 时）：
1. `stop_profile_gateway()` → `os.kill(pid, SIGTERM)` → 因信号处理未注册，直接 `sys.exit(1)` → **无优雅关闭**
2. `_wait_for_gateway_exit(timeout=10.0, force_after=5.0)` → 等待 PID 退出
3. `run_gateway(verbose=0)` → 启动新 gateway

PID 扫描已有 Windows 分支（`_scan_gateway_pids` 用 `wmic`），但信号处理和重启机制仍需修复。

## 远程调试 Windows Hermes（从 WSL）

WSL 可以读写 Windows 文件系统 `/mnt/c/`，并调用 `powershell.exe` 执行 Windows 命令，实现从 WSL 远程调试 Windows Hermes。

### 查询 Windows Hermes session 数据库

```bash
# 1. 确认 state.db 存在
powershell.exe -Command "if (Test-Path 'C:\Users\dddog\.hermes\state.db') { echo 'FOUND' } else { echo 'NOT FOUND' }"

# 2. 写 Python 脚本查询 session
# 注意：state.db 的 schema 与 WSL 版不同
# sessions 表用 started_at 而非 created_at
# messages 表直接有 session_id 列（无 session_messages 关联表）
```

示例查询脚本（保存为 `query_session.py`）：
```python
import sqlite3, json

conn = sqlite3.connect(r"C:\Users\dddog\.hermes\state.db")
conn.row_factory = sqlite3.Row
cur = conn.cursor()

# 查会话
cur.execute("SELECT id, title, started_at, message_count, model FROM sessions WHERE id = ?", (session_id,))

# 查消息
cur.execute("SELECT role, content, tool_calls FROM messages WHERE session_id = ? ORDER BY timestamp ASC", (session_id,))
```

```bash
# 3. 用 Windows Python 执行
powershell.exe -Command "& '.venv/Scripts/python.exe' C:\Users\dddog\hermes-windows\query_session.py"
```

### 验证代码改动（Windows 上 import 测试）

```bash
# 1. 从 WSL 改代码（文件在 /mnt/c/Users/dddog/hermes-windows/）

# 2. 用 WSL python3 检查语法
python3 -c "import ast; ast.parse(open('file.py').read()); print('OK')"

# 3. 用 Windows Python 验证 import 链
powershell.exe -Command "& '.venv/Scripts/python.exe' -c \"from hermes_constants import is_windows; print(is_windows())\""

# 4. 跑单元测试（注意 pyproject.toml 可能有 -n auto 导致 xdist 失败）
powershell.exe -Command "& '.venv/Scripts/python.exe' -m pytest tests/agent/test_prompt_builder.py -x -q -o 'addopts='"
```

### 注意点

- `powershell.exe -Command "..."` 的双引号嵌套容易出问题，复杂脚本建议写 `.py` 文件到 Windows 路径再执行
- Windows Python 路径需要用 `&` 调用：`& '.venv/Scripts/python.exe' script.py`
- `2>&1` 在 PowerShell 中不是重定向 stdout，会被解析为参数，导致 `cmdlet args` 错误
- WSL 直接 `cd /mnt/c/Users/dddog/...` 再 `powershell.exe -Command "..."` 也能工作

## 参考资料

以下参考文件记录了 Windows 终端执行问题的两次修复：

| 文件 | 范围 | 日期 |
|------|------|------|
| `references/windows-terminal-bug-trilogy.md` | **三大根因完整修复**：Git Bash 优先级、Windows 路径转换、`select.select()` 管道不兼容 | 2026-05-10 |
| `references/windows-powershell-terminal-fix.md` | 旧修复：PowerShell `-Command` vs `-c` 参数问题（已被 supersede） | 2026-05-08 |

**注意**：新 session 发现的问题比 PowerShell `-Command` 参数更深。新文件 `windows-terminal-bug-trilogy.md` 是当前正确的参考。

## Windows 实机验证步骤

```powershell
# 在 Windows cmd/PowerShell 中执行
cd C:\Users\dddog\hermes-windows

# 安装
python -m pip install -e .

# CLI 测试（非交互模式，避开 TUI PTY 限制）
hermes --help
hermes model

# Gateway 测试
hermes gateway run
```

注意：`hermes --tui` 在 Windows 原生上不可用（PTY 限制），这是架构问题非 bug。
