---
name: hermes-cli-command-syntax
description: Hermes CLI 命令语法规范——/model、/provider 等命令的正确用法和常见错误
trigger: 使用 /model、/provider 命令或配置 providers dict 时
---

# Hermes CLI 命令语法规范

## /model 命令（重要）

### ❌ 错误写法（会导致 HTTP 400）
```
/model sensenova:sensenova-6.7-flash-lite
/model minimax:MiniMax-M2.7
```
冒号会被当作 model 名的一部分，发给当前 provider，导致 unknown model 错误。

### ✅ 正确写法
```
/model sensenova-6.7-flash-lite --provider sensenova
/model MiniMax-M2.7 --provider minimax
/model <模型名> --provider <provider-key>
```

### /model 支持的格式
- `/model <name>` — 切换模型（当前 provider），仅当前会话有效
- `/model <name> --provider <provider>` — 切换 provider + 模型，仅当前会话
- `/model --provider <provider>` — 切换 provider，自动选模型，仅当前会话
- `/model <name> --global` — 切换并**持久化**到 config.yaml（写入 `model.default` 和 `model.provider`）

**`--global` 的作用：** 不加则所有新会话（`/new`、gateway 重启后）仍用 config.yaml 的默认值；加了才写到 `model.default` + `model.provider`，永久生效。Gateway 模式下重启后 session 恢复但配置读 config.yaml，所以 gateway 要持久化必须加 `--global`。

**没有冒号语法！** 冒号不会被 `/model` 命令识别。

## /provider 命令
```
/provider sensenova
```
切换到 provider，自动选择该 provider 的默认模型。

## 常见 Provider 切换示例

### 百度千帆 (qianfan)
```yaml
providers:
  qianfan:
    api_mode: chat_completions
    base_url: https://qianfan.baidubce.com/v2
    key_env: QIANFAN_API_KEY
    model: ERNIE-4.5-8K
```

切换：
```
/model ERNIE-4.5-8K --provider qianfan          # 当前会话
/model ERNIE-4.5-8K --provider qianfan --global  # 持久化
/key_env 方式 API key 存在 .env 文件中。
```

### 商汤 (sensenova)
```yaml
providers:
    name: sensenova
    api_mode: chat_completions
    base_url: https://token.sensenova.cn/v1
    key_env: SENSENOVA_API_KEY
```

## 陷阱清单
1. **没有冒号语法** —— `/model` 命令不支持 `provider:model` 格式
2. **providers dict key 不能冲突** —— 不能用 `minimax`、`openrouter` 等内置 key
3. **API key 用 key_env** —— 引用 .env 中的环境变量，不硬编码
4. **模型字段名是 `default_model`** —— 不是 `model`

## 相关文件
- `hermes_cli/model_switch.py` —— `/model` 命令实现（`parse_model_flags()` 只解析 `--provider` 和 `--global`）
- `hermes_cli/runtime_provider.py:349-429` —— `_get_named_custom_provider()`
