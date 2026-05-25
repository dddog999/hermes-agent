# Gateway 保活脚本修订版 (2026-05-22)

## 问题诊断

2026-05-22 gateway 日志停在 09:02（最后一条飞书消息处理），之后无记录。
检查发现 `gateway-start.sh` 保活脚本虽然以 `setsid` 启动，但它本身的进程也可能挂掉（因为通过 `bash script.sh` 而不是 `nohup` 启动），导致 `while true` 循环终止。

## 原有保活脚本的 bug

旧版 `gateway-start.sh` 有两个问题：

1. **setsid 本身不保活脚本进程**：`setsid cmd &` 只是把 cmd 放到新 session，但启动脚本自身的进程如果被 kill/PTS 断开，保活也会停
2. **PID 文件不更新**：保活脚本用 `gateway-autostart.pid` 记录 gateway PID，但保活脚本自己重启后 pid 文件变旧，`kill -0 old_pid` 失败后依赖 `pgrep -f 'hermes.*gateway.*run'` → 这个 pgrep 如果匹配到当前 CLI 会话会产生误判（"already running" 但实际 gateway 死了）

## 修订要点（已部署）

新版 `gateway-start.sh` 的关键改进：

### 1. 记录自身 PID
```bash
SELF_PID_FILE="$HOME/.hermes/gateway-keepalive.pid"
echo $$ > "$SELF_PID_FILE"
```
方便 `.bashrc` 补启逻辑检测保活脚本本身是否在运行。

### 2. 不再用 setsid，改用 nohup
```bash
nohup "$HERMES_VENV" gateway run >> "$LOG_FILE" 2>&1 &
```
不隔绝 session（因为通过 `.bashrc` 或 VBS 启动的脚本，session 由 WSL 的 init 管理）。关键是不让启动 shell 退出时中断子进程。

### 3. 双重检测 + 排除自身
```bash
pgrep -f '[h]ermes.*gateway.*run' | while read p; do
    [ "$p" = "$$" ] && continue     # 排除保活脚本自身
    [ "$p" = "$(cat $SELF_PID_FILE)" ] && continue
    if kill -0 "$p" 2>/dev/null; then
        return 0
    fi
done
```
`[h]ermes` 的 `[]` 技巧避免 pgrep 匹配到 `grep` 命令自身。

## 三层保活架构（已验证 2026-05-22 生效）

| 层 | 组件 | 触发 | 描述 |
|----|------|------|------|
| 1 | `gateway-start.sh` | 30秒轮询 | gateway 崩溃后自动重启，脚本本身不掉 |
| 2 | Windows Startup VBS | 登录时 | `wsl.exe -d Ubuntu-24.04 -e bash -lc 'bash ~/.hermes/gateway-start.sh'` |
| 3 | `.bashrc` | 手动开 WSL 终端 | 检测 `pgrep -f 'gateway-start'` 和 `hermes.*gateway.*run`，缺则补起 |

### VBS 文件位置
```
C:\Users\dddog\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\hermes-wsl-gateway.vbs
```

### .bashrc 补启逻辑（已有，在 ~/.bashrc 第130-133行）
```bash
if ! pgrep -f "hermes.*gateway.*run" > /dev/null 2>&1; then
    nohup bash ~/.hermes/gateway-start.sh > /dev/null 2>&1 &
fi
```

## 不采用 systemd 的原因

WSL 中 `systemd --user` 虽然在跑（PID 371），但 dbus socket `/run/user/1000/bus` 缺失 → `systemctl --user hermes-gateway.service` 报 `Failed to connect to bus: No such file or directory`。这是 WSL 的已知问题（dbus 启动顺序缺陷），此前已经花费大量时间调试都未解决。

**终止条件**：当 `systemctl --user` 不恢复时，用 keepalive 脚本 + 三层启动是最可靠的方案。
