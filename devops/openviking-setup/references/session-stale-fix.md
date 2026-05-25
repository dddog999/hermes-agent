## 配置变更后必须（两步）

修改 `config.yaml`（memory.provider）或 `.env`（OPENVIKING_API_KEY）后，需要**两步**：

1. **重启 gateway**（让新的 memory provider 配置生效）
2. **开新会话 /new**（让 AIAgent 的 OV client 缓存刷新）

缺任一步都不行。gateway 重启只刷新 memory provider 的服务端连接；AIAgent 会话级的 OV client 缓存只有开新会话才刷新。

```bash
# systemd 管理的
systemctl --user restart hermes-gateway

# 手动启动的
kill $(ps aux | grep "gateway run" | grep -v grep | awk '{print $2}')
nohup python -m hermes_cli.main gateway run --replace &
```

**判断是否两步都做了**：开新会话后，`viking_search` 有返回（哪怕结果少），说明 OV client 初始化成功。如果开新会话后 search 仍然空 → 查 embedding 是否正常（search 500 排查）。
