# WSL Hermes Gateway 开机自启配置

## 问题

WSL 的 hermes-gateway 通过 systemd user service 管理，但有两个问题：
1. WSL 重启后 systemd 服务不会自动启动（需要交互式 shell 触发）
2. Windows 开机后 WSL 本身不会自动启动

## 解决方案：Windows 计划任务 + systemd 双层保活

### 第一层：systemd 服务（WSL 内）— 进程级保活

```bash
# 安装 systemd user service
hermes gateway install --force

# 服务文件位置
~/.config/systemd/user/hermes-gateway.service
```

服务配置关键参数（已内置）：
```
Restart=always           # 总是自动重启
RestartSec=60            # 失败后等 60 秒再重启
RestartMaxDelaySec=300   # 最大延迟 5 分钟
RestartSteps=5           # 5 次失败后逐步退避
```

### 第二层：Windows 计划任务 — 开机自启

**⚠️ PowerShell 转义陷阱**：通过 `pwsh.exe -Command` 传递含 `$` 的脚本时，变量会被 WSL bash 吃掉。必须用脚本文件（`-File`）方式执行。

```bash
# 1. 写脚本文件到 Windows 路径
cat > /tmp/create-task.ps1 << 'EOF'
$taskName = "HermesGateway"
$description = "Hermes Agent Gateway - auto start on Windows login"
Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
$action = New-ScheduledTaskAction -Execute "wsl.exe" -Argument "--user kangle -- systemctl --user start hermes-gateway"
$trigger = New-ScheduledTaskTrigger -AtLogon -User "kangle"
$principal = New-ScheduledTaskPrincipal -UserId "kangle" -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description $description -Force | Out-Null
Write-Host "[OK] Scheduled task created"
Get-ScheduledTask -TaskName $taskName | Select-Object TaskName, State
EOF

# 2. 复制到 Windows 路径
cp /tmp/create-task.ps1 /mnt/c/Users/kangle/AppData/Local/hermes/create-task.ps1

# 3. 执行
pwsh.exe -NoLogo -NoProfile -File "C:\Users\kangle\AppData\Local\hermes\create-task.ps1"

# 4. 清理临时文件
rm /mnt/c/Users/kangle/AppData/Local/hermes/create-task.ps1
```

### 验证

```bash
# 从 Windows 侧检查 gateway 状态
pwsh.exe -NoLogo -NoProfile -Command "wsl.exe --user kangle -- systemctl --user is-active hermes-gateway"
# 期望输出: active

# 从 WSL 内侧检查
hermes gateway status
```

## 注意事项

- **systemd linger**：确保已启用 `loginctl enable-linger <user>`，否则用户服务在 logout 后停止
- **WSL systemd**：确保 `/etc/wsl.conf` 中有 `[boot] systemd=true`
- **计划任务触发器**：使用 `-AtLogon` 而非 `-AtStartup`，确保 WSL 的 systemd 已初始化后再启动服务
- **服务名**：systemd service 名为 `hermes-gateway`（不是 `hermes-gateway.service`）
