# hermes-upstream-windows-integration 参考补遗

## 配置路径对照（2026-05-18 实测）

| 安装 | HERMES_HOME 默认值 | Windows 实际路径 |
|---|---|---|
| WSL hermes（旧生产） | `~/.hermes/` | `C:\Users\dddog\.hermes\` |
| Windows 官方 hermes（v0.14.0） | `%LOCALAPPDATA%\hermes` | `C:\Users\dddog\AppData\Local\hermes\` |

**两者完全不同**，WSL 配置（`~/.hermes/.env`、`config.yaml`）不会自动被 Windows 官方版读取。

## 配置迁移命令（2026-05-18 实测成功）

```bash
# 必选：API keys + 完整配置
cp ~/.hermes/.env "/mnt/c/Users/dddog/AppData/Local/hermes/.env"
cp ~/.hermes/config.yaml "/mnt/c/Users/ddddog/AppData/Local/hermes/config.yaml"

# 可选（按需）
cp -r ~/.hermes/sessions "/mnt/c/Users/ddddog/AppData/Local/hermes/sessions"
cp -r ~/.hermes/skills "/mnt/c/Users/ddddog/AppData/Local/hermes/skills"
cp ~/.hermes/state.db "/mnt/c/Users/ddddog/AppData/Local/hermes/state.db"
```

## 上游 vs WSL fork 配置内容对比

WSL `.env` 包含：MINIMAX_API_KEY、MINIMAX_CN_API_KEY、DEEPSEEK_API_KEY、FEISHU_APP_ID/APP_SECRET、API_SERVER_*、JINA_API_KEY、GITHUB_TOKEN、CLAWMEM_* 等真实 key。

Windows 官方模板 `.env` 是注释模板，没有任何真实 key。

直接覆盖即可，Windows 官方版模板无用，直接丢弃。
