# WSL 命令调用模式（从 Windows 调用 WSL 内的 Hermes）

## 核心原则

从 **Windows Git Bash / MSYS** 调用 WSL 内命令时：
- **必须用完整路径**，不要依赖 PATH
- `wsl -d Ubuntu -- bash -c "command"` 的命令中，MSYS 会转换 `/mnt/c` 路径，导致命令失败
- **`wsl -- bash -c "command"`**（不带 `-d Ubuntu`）使用默认发行版，通常更可靠

## 经验证可用的模式

```bash
# ✅ 方式 A（推荐）：wsl -- bash -c + 完整路径
wsl -- bash -c "cd /home/kangle && /home/kangle/.hermes/hermes-agent/venv/bin/hermes gateway status"

# ✅ 方式 B：直接 wsl + 命令（不用 bash -c）
wsl hermes gateway status   # 仅当 hermes 在 PATH 中可用

# ❌ 方式 C（失败）：wsl -d Ubuntu -- bash -c + 含路径的命令
wsl -d Ubuntu -- bash -c "/home/kangle/.hermes/hermes-agent/venv/bin/hermes gateway status"
# 错误：C:/Program: No such file or directory（MSYS 路径转换干扰）
```

## systemctl 调用

```bash
# ✅ 停止 WSL systemd 服务
wsl -- bash -c "systemctl --user stop hermes-gateway.service && systemctl --user disable hermes-gateway.service"

# ✅ 查看服务状态
wsl -- bash -c "systemctl --user status hermes-gateway.service"
```

## 为什么 `wsl -d Ubuntu -- bash -c "command"` 会失败

当命令字符串中包含 Unix 风格路径（如 `/home/kangle/...`）时：
- MSYS 的路径自动化将 `/mnt/c` 转换为 `C:\`
- 但 `-d Ubuntu` 参数已经指定了发行版，`bash -c` 后续的路径解析在 MSYS 上下文而非 WSL 上下文
- 导致 `C:/Program: No such file or directory` 错误

## 日志位置

WSL systemd 服务的日志用 `journalctl`：
```bash
wsl -- bash -c "journalctl --user -u hermes-gateway -n 20"
```

WSL Hermes 日志：
```bash
wsl -- bash -c "tail -20 /home/kangle/.hermes/logs/gateway.log"
```
