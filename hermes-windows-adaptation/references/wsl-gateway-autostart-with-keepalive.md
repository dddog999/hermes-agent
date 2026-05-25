# WSL Hermes Gateway 三层自启保活架构

适用场景：Windows 原生 Hermes 已卸载，仅 WSL 内的 Hermes 需要开机自动启动 gateway。

## 架构概览

```
Windows 开机登录
    │
    ├─ (方式A) Startup 文件夹快捷方式 → hermes-wsl-startup.bat
    └─ (方式B) Task Scheduler ONLOGON → hermes-wsl-startup.bat
                                               │
                          wsl.exe -d Ubuntu-24.04 -e bash ~/.hermes/gateway-start.sh
                                               │
                              ┌────────────────┴────────────────┐
                              │  bash gateway-start.sh          │
                              │  ┌─ 用 setsid 启动 gateway     │
                              │  └─ 30秒一次检查 + 自动重启     │
                              └─────────────────────────────────┘
                                               │
                    (补启) WSL 终端手动打开时：.bashrc 检测 + 启动
```

## 三层说明

### Layer 1: keepalive 脚本 (`~/.hermes/gateway-start.sh`)

核心守护脚本，30秒检查一次 gateway 进程是否存活，崩溃后自动重启：

```bash
#!/bin/bash
HERMES_VENV="$HOME/.hermes/hermes-agent/venv/bin/hermes"
LOG_FILE="$HOME/.hermes/logs/gateway-autostart.log"
PID_FILE="$HOME/.hermes/gateway-autostart.pid"
CHECK_INTERVAL=30

is_running() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE" 2>/dev/null)
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            return 0
        fi
    fi
    pgrep -f 'hermes.*gateway.*run' > /dev/null 2>&1 && return 0
    return 1
}

start_gateway() {
    if is_running; then
        log "Gateway already running, skipping"
        return 0
    fi
    log "Starting Hermes Gateway..."
    setsid "$HERMES_VENV" gateway run >> "$LOG_FILE" 2>&1 &
    echo $! > "$PID_FILE"
    log "Gateway started PID $(cat $PID_FILE)"
}
```

关键点：
- `setsid` 确保 gateway 进程不受终端生命周期影响
- `pgrep -f` 后备检测避免 PID 文件丢失后重复启动
- 日志记录到 `~/hermes/logs/gateway-autostart.log`

### Layer 2: Windows 自启 (`hermes-wsl-startup.bat`)

```bat
wsl.exe -d Ubuntu-24.04 -e bash -c "nohup setsid bash /home/dddog/.hermes/gateway-start.sh > /home/dddog/.hermes/logs/gateway-startup.log 2>&1 &"
exit
```

**部署方式**：
- **Startup 文件夹**（推荐，无需管理员）：用 PowerShell COM 创建 .lnk 快捷方式：
  ```powershell
  $ws = New-Object -ComObject WScript.Shell
  $sc = $ws.CreateShortcut("C:\Users\dddog\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\HermesWSLGateway.lnk")
  $sc.TargetPath = "C:\Users\dddog\hermes-wsl-startup.bat"
  $sc.Save()
  ```
- **Task Scheduler**（系统级，需管理员）：
  ```cmd
  schtasks /create /tn HermesWSLGateway /tr "C:\Users\dddog\hermes-wsl-startup.bat" /sc ONLOGON /rl LIMITED /f
  ```
  ⚠️ 注意：`/rl LIMITED`（非管理员）下，`schtasks /create` 会报 `Access is denied`，需要管理员权限运行。Startup 文件夹方案是更简单的替代。

### Layer 3: .bashrc 补启

在 WSL `~/.bashrc` 末尾添加，手动打开终端时自动补启：

```bash
# Hermes Gateway auto-start
if ! pgrep -f "hermes.*gateway.*run" > /dev/null 2>&1; then
    nohup bash ~/.hermes/gateway-start.sh > /dev/null 2>&1 &
fi
```

## 验证步骤

```bash
# 1. 检查日志
cat ~/.hermes/logs/gateway-autostart.log

# 2. 检查 gateway 是否在运行
pgrep -a -f 'hermes.*gateway.*run'

# 3. 杀掉 gateway 验证自动重启
kill $(pgrep -f 'python.*hermes.*gateway')
sleep 35  # 等待一轮检查
ps aux | grep 'python.*hermes.*gateway'  # 应该重新出现了
```

## 已知问题

### ⚠️ keepalive 脚本自身崩溃（高频）

**症状**：`gateway-start.sh` 脚本进程消失（`ps aux | grep gateway-start` 无结果），导致 gateway 崩溃后无法自动恢复。

**多次确认的根因**：
- WSL 的 OOM killer 或系统资源压力下可能杀掉长期运行的 shell 脚本
- `setsid` + `&` 后台执行后，脚本的 `while true` 循环依赖脚本进程存活，如果 shell 脚本因任何原因退出（被信号终止、OOM、父进程中断），循环立即停止
- `is_running()` 的 `pgrep -f 'hermes.*gateway.*run'` 模式在 gateway 实际已死时不匹配任何进程，所以检测结果是\"未运行\"→但在脚本被 kill 后根本不会执行到检测代码

**解决方向**（任选一）：

1️⃣ **systemd --user 服务**（推荐，最可靠）：
```bash
mkdir -p ~/.config/systemd/user/
cat > ~/.config/systemd/user/hermes-gateway.service << 'SERVICEEOF'
[Unit]
Description=Hermes Gateway (WSL)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=%h/.hermes/hermes-agent/venv/bin/hermes gateway run
Restart=always
RestartSec=30
RestartMaxDelaySec=300

[Install]
WantedBy=default.target
SERVICEEOF

systemctl --user daemon-reload
systemctl --user enable hermes-gateway
systemctl --user start hermes-gateway
```

2️⃣ **升级 keepalive 脚本**——增加双层进程监护 + trap 处理退出信号：
```bash
# 在 gateway-start.sh 顶部添加
set -o pipefail
trap 'log "Keepalive script terminating"' EXIT

# 在 while 循环中用 sleep 0.2 替代 sleep 30（更频繁检查，减少空闲空缺）
# 同时增加一个子进程看门狗
```

3️⃣ **添加 Windows 计划任务定时健康检查**——每隔 N 分钟从 Windows 侧检测 WSL 内 gateway 是否存活：
```powershell
$action = New-ScheduledTaskAction -Execute "wsl.exe" `
  -Argument "-d Ubuntu-24.04 -e bash -c 'pgrep -f hermes.*gateway.run || nohup bash ~/.hermes/gateway-start.sh &'"
$trigger = New-ScheduledTaskTrigger -Daily -At "00:00" `
  -RepetitionInterval (New-TimeSpan -Minutes 10) `
  -RepetitionDuration (New-TimeSpan -Days 1)
Register-ScheduledTask -TaskName "HermesGatewayHealthCheck" -Action $action -Trigger $trigger -Force
```

**已确认的症状案例**（2026-05-22）：
- gateway 在 09:02 崩溃（最后一条 gateway.log 再未更新）
- keepalive 脚本进程（PID 38895）此时已死
- PID 文件仍记录今早的旧 PID（35293），`kill -0 35293` 实际返回 false，但因为脚本进程终止，检测循环不再执行
- 直到晚上 19:32 手动重启才恢复

### ⚠️ `is_running()` 的 `pgrep` 误匹配风险

`pgrep -f 'hermes.*gateway.*run'` 的优点是可以兜底找到任何含\"gateway run\"关键字的进程。但如果 CLI 中出现类似 cmdline，可能导致误判为\"already running\"。目前实测不会匹配到普通 CLI 进程（CLI 的 cmdline 是 `python ./venv/bin/hermes`，不含\"gateway run\"）。

### 重复 keepalive 进程

如果多次手动执行 `gateway-start.sh`，会启动多个 keepalive 进程。每个 keepalive 都会检查 gateway 存活，所以功能上不会重复，但会产生冗余进程。清理方法：

```bash
# 杀掉所有 keepalive（保留 gateway）
pkill -f gateway-start.sh
# 再重新启动一个
bash ~/.hermes/gateway-start.sh
```

### 从 Windows 原生迁移后的注意事项

如果之前用的是 Windows 原生 Hermes 的自启方案，需要先清理：

| 旧方案 | 清理方法 |
|--------|---------|
| Task Scheduler `HermesGateway` | `schtasks /delete /tn HermesGateway /f` |
| Startup 文件夹 | 删除 `.lnk` |
| Watchdog `.bat` | 删除文件 |

### WSL 的 `schtasks /create` 限制

从 WSL 的 CMD 中运行 `schtasks /create` 会因为 UNC 路径前缀导致 `Access is denied`。需要在 **Windows 的 PowerShell/CMD** 中直接运行，或者在 WSL 中通过 Python 的 `subprocess.run(cwd='C:\\Users\\dddog')` 绕开 UNC 路径问题。
