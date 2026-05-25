# WSL hermes-gateway 自启动管理

## 背景

WSL 的 hermes-gateway 通过 systemd user service 管理：

- service 文件：`~/.config/systemd/user/hermes-gateway.service`
- systemd 已启用（`/etc/wsl.conf` 设置 `systemd=true`）
- 因此 hermes-gateway 随 WSL 自动启动，无需手动运行

## 当前状态检查

```bash
# 查看 service 文件内容
cat ~/.config/systemd/user/hermes-gateway.service

# 查看 gateway 进程是否在运行
ps aux | grep hermes_gateway | grep -v grep
# 示例输出：
# dddog  438  ...  /home/dddog/.hermes/hermes-agent/venv/bin/python -m hermes_cli.main gateway run --replace
```

## 禁用 hermes-gateway 自启动

**操作**：禁用 service + 移走 service 文件

```bash
# 1. 禁用 service（下次 WSL 启动不再自动加载）
systemctl --user disable hermes-gateway 2>/dev/null || true

# 2. 移走 service 文件（防止 systemd 找到它）
mv ~/.config/systemd/user/hermes-gateway.service \
   ~/.config/systemd/user/hermes-gateway.service.bak
```

**使配置生效**：必须在 PowerShell 中重启 WSL：
```powershell
wsl --shutdown
```

重启后 WSL 会自动启动 systemd，但 hermes-gateway 不会启动。

## 只杀进程、保留自启动

如果只是想停掉当前 gateway，但保留自启动能力：

```bash
# 找到进程 PID
ps aux | grep hermes_gateway | grep -v grep | awk '{print $2}'

# 杀掉进程（WSL 重启后会重新自动启动）
kill <PID>
```

## 重新启用 hermes-gateway

```bash
# 1. 恢复 service 文件
mv ~/.config/systemd/user/hermes-gateway.service.bak \
   ~/.config/systemd/user/hermes-gateway.service

# 2. 重新加载 systemd
systemctl --user daemon-reload

# 3. 启动 service
systemctl --user start hermes-gateway

# 4. 验证状态
systemctl --user status hermes-gateway
```

## 当前 session 无法执行的操作

由于 WSL 当前 session 的 systemd bus 不可用（`Failed to connect to bus`），以下命令在当前 session 中无法生效：

- `systemctl --user enable/disable/start/stop hermes-gateway`
- `systemctl --user status`

**必须在 PowerShell 中执行 `wsl --shutdown` 后，新 WSL session 才能正常控制 systemd。**
