# Openviking Cross Machine
> Absorbed from `openviking-cross-machine` — OpenViking vector DB configuration and usage notes.

---


# OpenViking 跨机器记忆共享

## 架构
- **Server 机器 (wooking)**: 运行 openviking-server，绑定 `0.0.0.0:1933`
- **Client 机器 (kangle)**: 通过 Tailscale IP 连接 server

## ⚠️ 关键发现：Provider 选择在 config.yaml，不在 .env

**最常见的坑**：`.env` 里的 `MEMORY_PROVIDER=openviking` **不会生效**！

实际 provider 选择在 `~/.hermes/config.yaml`：

```yaml
memory:
  provider: openviking    # ← 这里决定用哪个 provider
```

代码逻辑：`run_agent.py` 读 `mem_config.get("provider", "")`，不读环境变量。

## 配置步骤

### 1. Server 端 (wooking)
确保 openviking-server 绑定 `0.0.0.0:1933`（非 127.0.0.1）：
```bash
ss -tlnp | grep 1933
curl http://127.0.0.1:1933/health
```

### 2. Client 端 (.env)
```bash
# ~/.hermes/.env
OPENVIKING_ENDPOINT=http://<server-tailscale-ip>:1933
OPENVIKING_API_KEY=<server上的API key>
OPENVIKING_USER=kangle          # 可选：每台机器不同值，用于记忆隔离
OPENVIKING_AGENT=hermes-kangle  # 可选：agent 标识
OPENVIKING_ACCOUNT=default      # 默认即可
```

### 3. Client 端 (config.yaml)
```bash
# 修改 ~/.hermes/config.yaml
memory:
  provider: openviking
```

### 4. 重启 Gateway
kangle 的 gateway 是 **systemd user service** 管理的：
```bash
# 查看进程
ps aux | grep "gateway run" | grep -v grep
# 杀掉后 systemd 自动重启
kill <PID>
# 查看重启日志
journalctl --user -u hermes-gateway --no-pager -n 20
```

### 5. 验证连通性
```bash
# 从 client 测试 server
curl -s --connect-timeout 5 http://<server-ip>:1933/health
# 测试 API 认证
API_KEY=$(grep "^OPENVIKING_API_KEY=" ~/.hermes/.env | cut -d= -f2)
curl -s -H "Authorization: Bearer $API_KEY" http://<server-ip>:1933/api/v1/system/status
```

## 记忆隔离（多机器场景）

OpenViking 租户隔离有三层：

| 层级 | 环境变量 | 作用 |
|------|---------|------|
| Account | `OPENVIKING_ACCOUNT` | 账号级隔离 |
| User | `OPENVIKING_USER` | 用户级隔离（每台机器不同值） |
| Agent | `OPENVIKING_AGENT` | 代理标识 |

**同 account、不同 user**：各自写自己的命名空间，同一 API key 下可跨读。

## ⚠️ 跨 Agent 记忆共享问题 (2026-04-20)

**发现：** `viking_remember` 存在 `viking://agent/{agent_id}/memories/`，是 **agent 私有空间**，其他 agent 查不到（返回 403）。

**解决方案：配置多租户**

### 步骤 1：server 端配置 root_api_key
```toml
[server]
auth_mode = "api_key"
root_api_key = "<openssl rand -hex 16>"
```

### 步骤 2：创建共享 account
```bash
curl -X POST http://<host>:1933/api/v1/admin/accounts \
  -H "Content-Type: application/json" \
  -H "X-API-Key: <root-key>" \
  -d '{"account_id": "home", "admin_user_id": "wooking"}'
```

### 步骤 3：注册其他机器
```bash
curl -X POST http://<host>:1933/api/v1/admin/accounts/home/users \
  -H "Content-Type: application/json" \
  -H "X-API-Key: <root-key>" \
  -d '{"user_id": "kangle", "role": "user"}'
```

### 步骤 4：更新 .env
各机器的 `OPENVIKING_API_KEY` 换成新 user_key。

### 步骤 5：共享 agent 记忆
namespace policy 设 `isolate_agent_scope_by_user = false`，同一 account 内 agent 记忆互通。

## 共享与隔离

| 数据 | account 内共享 | 隔离边界 |
|------|---------------|----------|
| resources | ✅ 是 | account |
| user 记忆 | ❌ 否 | user |
| agent 记忆 | 可配置 | 默认 agent |
| session | ❌ 否 | user/session |

## 常见问题

### Gateway 不加载 OpenViking
检查顺序：
1. `config.yaml` 的 `memory.provider` 是否为 `openviking`（不是 .env！）
2. `.env` 的 key 是否完整（终端显示可能脱敏）
3. Gateway 是否重启（systemd 自动重启有延迟 ~30s）

### API Key 被截断
终端输出会对 API key 脱敏（显示 `139ec7...9a68`），但文件内容是完整的。验证：
```bash
python3 -c "with open('/home/kangle/.hermes/.env') as f: [print(repr(l.strip())) for l in f if 'OPENVIKING_API_KEY' in l]"
```

## 参考
- [多租户文档](https://github.com/volcengine/OpenViking/blob/main/docs/zh/concepts/11-multi-tenant.md)
- [Admin API](https://github.com/volcengine/OpenViking/blob/main/docs/zh/api/08-admin.md)
