# Hermes Gateway 启动失败修复指南

> Absorbed from `hermes-gateway-fix` during 2026-05-22 consolidation. Under `hermes-internals`.

---


# Hermes Gateway 启动失败修复指南

## 常见症状

- `curl http://localhost:8642/health` 连接失败
- `systemctl --user status hermes-gateway.service` 显示 `ModuleNotFoundError: No module named 'httpx'`
- `ERROR gateway.run: PID file race lost to another gateway instance. Exiting.`
- 飞书显示"已离线"或无法收发消息

## 诊断步骤

```bash
# 1. 检查端口是否监听
ss -tlnp | grep 8642

# 2. 检查 systemd 服务状态
systemctl --user status hermes-gateway.service

# 3. 查看最近 gateway 日志
tail -30 ~/.hermes/logs/gateway.log

# 4. 检查 PID 文件是否过期
cat ~/.hermes/gateway.pid
kill -0 $(cat ~/.hermes/gateway.pid) 2>&1  # 进程是否存在
```

## 修复流程

### Step 1: 给 hermes-agent venv 安装 httpx

hermes-agent 使用自己的 venv（Python 3.11），不在系统 Python 路径下：

```bash
# 检查 venv Python 版本
/home/kangle/.hermes/hermes-agent/venv/bin/python --version

# 如果 venv 里没有 pip，先引导
/home/kangle/.hermes/hermes-agent/venv/bin/python -m ensurepip

# 安装 httpx
/home/kangle/.hermes/hermes-agent/venv/bin/pip3 install httpx
```

### Step 2: 删除 stale PID 文件

如果 PID 文件指向一个已不存在的进程，会导致 "PID file race" 错误：

```python
import os
pid_file = "/home/kangle/.hermes/gateway.pid"
if os.path.exists(pid_file):
    os.remove(pid_file)
```

### Step 3: 启动 Gateway

```bash
# 方式A: 直接启动（前台测试用）
/home/kangle/.hermes/hermes-agent/venv/bin/python -m hermes_cli.main gateway run --replace

# 方式B: 通过 systemd
systemctl --user start hermes-gateway.service
```

### Step 4: 验证

```bash
# 检查端口
ss -tlnp | grep 8642

# 检查飞书连接（看日志）
grep -i "feishu.*connect\|Lark.*connect" ~/.hermes/logs/agent.log | tail -5
```

## 关键文件路径

| 文件 | 路径 |
|------|------|
| hermes-agent venv | `/home/kangle/.hermes/hermes-agent/venv/` |
| Gateway PID 文件 | `/home/kangle/.hermes/gateway.pid` |
| Gateway 日志 | `~/.hermes/logs/gateway.log` |
| Agent 日志 | `~/.hermes/logs/agent.log` |
| 启动脚本 | `/home/kangle/.hermes/hermes-agent/scripts/hermes-gateway` |

## WSL 特殊问题：systemd user session 不可用

**错误信息：**
```
Failed to connect to bus: No such file or directory
✗ User systemd not reachable:
  User systemd control sockets are missing
```

**原因：** WSL 不提供 systemd user session，所以 `hermes gateway start/restart/start` 全都失败。

**解决方案：** 使用前台模式 + SSH background：

```bash
# 激活 venv 后，前台运行（background=true 让 Hermes 跟踪进程）
terminal(background=true) {
  ssh user@host "cd ~/.hermes/hermes-agent && source venv/bin/activate && hermes gateway run"
}

# 等待几秒后验证
ssh user@host "hermes gateway status"
```

注意：不要用 `nohup ... &` 或 `disown`，Hermes 的 terminal tool 会报错"shell-level background wrappers"。必须用 `background=true` 参数。

## 注意事项

- Gateway 绑定 Tailscale IP（`100.125.109.54`），不在 127.0.0.1
- hermes-agent venv 是 Python 3.11，系统是 Python 3.12，别混淆
- systemd 服务可能在 auto-restart 循环中，先 `stop` 再启动
- 飞书 websocket 断连后会自动重连，发条消息触发即可
- WSL 下必须用 `hermes gateway run` + `background=true`，不能用 systemd 管理
