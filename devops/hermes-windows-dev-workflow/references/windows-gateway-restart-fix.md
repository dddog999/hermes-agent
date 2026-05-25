# Windows Gateway 重启修复记录

## 问题

Windows 原生 Hermes gateway 执行 `/restart` 后彻底关闭，没有新进程启动。

## 根因

`_launch_detached_restart_command()` 是纯 Unix 实现（`bash -lc` + `setsid` + `kill -0`），Windows 上完全不可用。

## 修复方案

### 1. `_launch_detached_restart_command()` 加 win32 分支

用 `sys.executable -c` 内联 Python watcher 脚本替代 `bash -lc`：

```python
if sys.platform == "win32":
    watcher_code = textwrap.dedent("""\
        import os, subprocess, sys, time
        parent_pid = {parent_pid}
        cmd = {cmd!r}
        # 轮询等旧进程退出
        for i in range(200):  # max ~60s
            try:
                os.kill(parent_pid, 0)
            except OSError:
                break
            time.sleep(0.3)
        time.sleep(0.5)  # 等文件锁释放
        # 启动新 gateway（不是 os.execv！）
        subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            creationflags=subprocess.DETACHED_PROCESS | subprocess.CREATE_NEW_PROCESS_GROUP)
    """)
    subprocess.Popen([sys.executable, "-c", watcher_code],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        creationflags=subprocess.DETACHED_PROCESS | subprocess.CREATE_NEW_PROCESS_GROUP)
    return
```

**关键点：**
- `os.execv` 在 Windows 上不可靠（不替换当前进程），必须用 `subprocess.Popen`
- `os.kill(pid, 0)` 在 Windows 上可用（通过 `WaitForSingleObject` 检查进程存活）
- `DETACHED_PROCESS | CREATE_NEW_PROCESS_GROUP` = 脱离父进程控制台
- watcher 日志写到 `%USERPROFILE%\.hermes\logs\watcher.log`（调试用）

### 2. 信号降级：`add_signal_handler` → `signal.signal`

Windows 上 `loop.add_signal_handler(SIGTERM)` 抛 `NotImplementedError`，被静默 pass。修复：降级到 `signal.signal`。

```python
for sig in (signal.SIGINT, signal.SIGTERM):
    try:
        loop.add_signal_handler(sig, shutdown_signal_handler, sig)
    except NotImplementedError:
        try:
            signal.signal(sig, shutdown_signal_handler)
        except (OSError, ValueError):
            pass
```

**注意**：`signal.signal` 回调中不能直接调 `asyncio.create_task`（非线程安全）。需要捕获 `_gateway_loop` 引用：

```python
_gateway_loop = None  # 在 start_gateway() 中设置

# 在 shutdown_signal_handler 中：
if _gateway_loop is not None and _gateway_loop.is_running():
    try:
        asyncio.create_task(runner.stop())
    except RuntimeError:
        asyncio.run_coroutine_threadsafe(runner.stop(), _gateway_loop)
```

### 3. `_find_bash()` 排除 WSL bash

Windows 上 `shutil.which("bash.exe")` 可能返回 WSL bash（`C:\Windows\System32\bash.exe`），不能运行 bash 脚本。

```python
def _is_wsl_bash(path: str) -> bool:
    lower = path.lower()
    return (r"\windows\system32\bash.exe" in lower
        or r"\windows\sysnative\bash.exe" in lower
        or r"\windowsapps\bash.exe" in lower)
```

查找顺序：
1. `shutil.which("bash.exe")` → 如果不是 WSL bash → 返回
2. 硬编码路径找 Git Bash（ProgramFiles / LOCALAPPDATA）
3. 都没有 → fallback powershell.exe + warning

## 测试方法

```powershell
# 1. 查看当前 gateway 进程
Get-Process hermes -ErrorAction SilentlyContinue | Select-Object Id, Path

# 2. 在微信发 /restart

# 3. 等 3-5 秒，查看新进程
Get-Process hermes -ErrorAction SilentlyContinue | Select-Object Id, Path

# 4. 检查 watcher 日志
Get-Content "$env:USERPROFILE\.hermes\logs\watcher.log" -Tail 20

# 5. 检查 gateway 日志
Get-Content "$env:USERPROFILE\.hermes\logs\gateway.log" -Tail 30
```

## 文件改动

| 文件 | 改动 |
|------|------|
| `gateway/run.py` | `_launch_detached_restart_command()` 加 win32 分支 |
| `gateway/run.py` | `start_gateway()` 信号降级 `signal.signal` |
| `gateway/run.py` | `_gateway_loop` 变量 + 安全调度 `runner.stop()` |
| `tools/environments/local.py` | `_is_wsl_bash()` + `_find_bash()` 排除 WSL bash |
