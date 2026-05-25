# Gateway 重启 Windows 兼容性分析

> 分析日期：2026-05-10
> 分析范围：`gateway/run.py` + `hermes_cli/gateway.py` 重启/关闭路径
> 版本：Hermes Agent v0.12.0 (2026.4.30)

## 重启路径概览

```
/restart 命令 (from 飞书/微信/Telegram)
  └─ _handle_restart_command() @ run.py:7357
      └─ await self.stop(restart=True, detached_restart=True, ...)
          └─ 1. 通知活跃 session 准备关闭
          └─ 2. _drain_active_agents(timeout) ← 等待当前对话完成
          └─ 3. 超时后 _interrupt_running_agents()
          └─ 4. _launch_detached_restart_command() ← ❌ 纯 Unix
              ├─ bash -lc "while kill -0 PID; do sleep 0.2; done; hermes gateway restart"
              └─ setsid / start_new_session=True
          └─ 5. 清理并退出

hermes gateway restart (从第二个终端)
  └─ hermes_cli/gateway.py:4453
      ├─ 尝试 systemd restart → 无 systemd → 走手动路径
      ├─ stop_profile_gateway() → 发 SIGTERM
      ├─ _wait_for_gateway_exit(timeout=10)
      └─ run_gateway() → asyncio.run(start_gateway())
```

## `_launch_detached_restart_command` 详细分析

### 原代码 (run.py:2631-2660)

```python
async def _launch_detached_restart_command(self) -> None:
    import shutil
    import subprocess

    hermes_cmd = _resolve_hermes_bin()
    if not hermes_cmd:
        logger.error("Could not locate hermes binary for detached /restart")
        return

    current_pid = os.getpid()
    cmd = " ".join(shlex.quote(part) for part in hermes_cmd)
    shell_cmd = (
        f"while kill -0 {current_pid} 2>/dev/null; do sleep 0.2; done; "
        f"{cmd} gateway restart"
    )
    setsid_bin = shutil.which("setsid")
    if setsid_bin:
        subprocess.Popen(
            [setsid_bin, "bash", "-lc", shell_cmd],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
    else:
        subprocess.Popen(
            ["bash", "-lc", shell_cmd],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
```

### Windows 上失败的层

| 调用 | Windows 行为 | 后果 |
|------|-------------|------|
| `shutil.which("setsid")` | 返回 `None` | 走 else 分支 |
| `shutil.which("bash")` | 可能返回 Git Bash 的 bash.exe | 若没有 Git Bash → `FileNotFoundError` → 仅 log，不做重启 |
| `"bash", "-lc", shell_cmd` | Git Bash MSYS2 运行 | `kill -0` 对原生 Windows PID 行为不可靠 |
| `kill -0 {pid}` | MSYS kill 对非 MSYS PID 可能返回 EPERM | wait 循环立即结束 |
| `shlex.quote()` | 生成 POSIX 风格引用 | Windows shell 不识别 |
| `start_new_session=True` | Windows 上不等同于 Unix setsid | 子进程可能随父进程死亡 |

### 对比正确的模式：`launch_detached_profile_gateway_restart`

`hermes_cli/gateway.py:439` 已经实现了一个跨平台兼容的模式：

```python
def launch_detached_profile_gateway_restart(profile: str, old_pid: int) -> bool:
    watcher = textwrap.dedent("""\
        import os, subprocess, sys, time
        pid = int(sys.argv[1]); cmd = sys.argv[2:]
        deadline = time.monotonic() + 120
        while time.monotonic() < deadline:
            try:
                os.kill(pid, 0)       # ← 跨平台：Windows 上检查进程存在
            except (ProcessLookupError, PermissionError):
                break
            time.sleep(0.2)
        subprocess.Popen(cmd, stdout=..., stderr=..., start_new_session=True)
    """)
    subprocess.Popen(
        [sys.executable, "-c", watcher, str(old_pid), *_gateway_run_args_for_profile(profile)],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True,
    )
```

关键区别：
- 用 `python -c` watch script 替代 `bash -lc` shell 脚本
- 用 `os.kill(pid, 0)` 替代 `kill -0`（Windows 上通过 `WaitForSingleObject` 检查进程存在）
- 用 `sys.executable` 确保正确的 Python 解释器

## 信号处理无声降级

### 代码位置：run.py:14804-14815

```python
loop = asyncio.get_running_loop()
if threading.current_thread() is threading.main_thread():
    for sig in (signal.SIGINT, signal.SIGTERM):
        try:
            loop.add_signal_handler(sig, shutdown_signal_handler, sig)
        except NotImplementedError:
            pass  # ← Windows 静默跳过
    if hasattr(signal, "SIGUSR1"):
        try:
            loop.add_signal_handler(signal.SIGUSR1, restart_signal_handler)
        except NotImplementedError:
            pass
```

### 后果分析

Windows 上没有信号处理，SIGTERM 触发 Python 默认行为：

```python
# Python 源码：signalmodule.c 中默认 SIGTERM 处理
# → PyErr_SetNone(PyExc_KeyboardInterrupt) → sys.exit(1)
```

断点分析：
1. `shutdown_signal_handler` 永不执行
2. `_signal_initiated_shutdown` 永不设为 True
3. `runner.stop()` 中的 drain/interrupt 逻辑永不执行
4. `.clean_shutdown` 标记不写入
5. `resume_pending` 标记不写入
6. 进程立即以 `sys.exit(1)` 退出

### `hermes gateway restart` CLI 路径分析

`stop_profile_gateway()` (`gateway.py:772`):
```python
write_planned_stop_marker(pid)   # 写入标记文件
os.kill(pid, signal.SIGTERM)      # 发信号
```

- `write_planned_stop_marker` 文件写入成功（纯文件操作）
- `os.kill(pid, SIGTERM)` → 进程退出
- `_wait_for_gateway_exit()` 用 `os.kill(pid, 0)` 轮询 → 能看到进程退出
- `run_gateway()` 启动新 gateway → 应能工作

但 `consume_planned_stop_marker_for_self()` 在信号处理中不被调用（因为信号处理根本没注册），所以 `_signal_initiated_shutdown` 保持 False → 最终 `_scan_gateway_pids` 时可能出问题。

## 修复优先级

### P0 — 必须修

`_launch_detached_restart_command()` 的 Windows 实现。影响 `/restart` 命令。

### P1 — 建议修

Windows 信号处理降级。至少添加 log warning，让 operator 知道优雅关闭不可用。

### P2 — 可选的

`_get_parent_pid` 的 Windows 实现（替代 `ps -o ppid=`），用 `wmic process where processid=XXX get parentprocessid`。当前影响 `_is_pid_ancestor_of_current_process` 和 SIGUSR1 路径（已优雅降级）。

## 测试计划

1. **`os.kill(pid, 0)` 在 Windows 上的行为验证**
   ```python
   # 父进程
   import os, subprocess, time
   p = subprocess.Popen(["python", "-c", "import time; time.sleep(30)"])
   print(f"child pid: {p.pid}")
   while True:
       try:
           os.kill(p.pid, 0)
           print("alive")
       except ProcessLookupError:
           print("dead")
           break
       time.sleep(1)
   ```

2. **`DETACHED_PROCESS` + `CREATE_NEW_PROCESS_GROUP` 验证**
   ```python
   import subprocess, time
   p = subprocess.Popen(
       ["python", "-c", "import time; time.sleep(300)"],
       creationflags=subprocess.DETACHED_PROCESS | subprocess.CREATE_NEW_PROCESS_GROUP,
   )
   print(f"detached pid: {p.pid}")
   # 关闭此脚本后检查子进程是否存活
   ```

3. **`python -c` watcher 脚本验证**
   ```python
   # 保存为 test_watcher.py，在 Windows 上单独运行
   ```

## 设计决策记录

- 选择 `python -c` watcher 而非 `pwsh -Command`：Python 是 Hermes 的运行时环境，保证存在；`os.kill(pid, 0)` 跨平台 API 一致
- `DETACHED_PROCESS` 标志使子进程无控制台，日志只能写文件 → 需要确保 gateway 初始化时日志已配置
- `start_new_session=True` 在 Windows 转换为 `CREATE_NEW_PROCESS_GROUP`（Python 内部处理）— 与显式 flags 等效，但 `creationflags` 更明确
