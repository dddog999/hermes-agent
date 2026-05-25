---
name: hermes-minimax-provider-guide
description: MiniMax 自定义 provider 配置完全指南——OpenAI/Anthropic 端点、reasoning_split、认证坑
trigger: 配置 MiniMax provider、mm provider、reasoning_split、MiniMax-M2.7
---

# MiniMax 自定义 Provider 配置指南

## 概述

MiniMax 提供两种 API 兼容端点：
- **OpenAI 兼容**：`https://api.minimaxi.com/v1` — 推荐，Hermes 完全支持
- **Anthropic 兼容**：`https://api.minimaxi.com/anthropic` — 不推荐，认证路由有问题

## 推荐配置

### config.yaml

```yaml
providers:
  mm:
    base_url: https://api.minimaxi.com/v1
    default_model: MiniMax-M2.7
    key_env: MM_API_KEY
```

### .env

```
MM_API_KEY=sk-cp-你的key
```

### 使用

```yaml
# 在 config.yaml 中添加 model_aliases 以获得 /model 自动补全
model_aliases:
  mm:
    model: MiniMax-M2.7
    provider: mm

providers:
  mm:
    base_url: https://api.minimaxi.com/v1
    default_model: MiniMax-M2.7
    key_env: MM_API_KEY
```

```bash
# CLI 启动
hermes --provider mm

# 会话内切换（有 model_aliases 则 Tab 可补全）
/model mm
# 或直接用 provider/model 格式（即使没有别名也能用）
/model mm/MiniMax-M2.7

# 持久化
/model mm --global
```

## `reasoning_split` 配置

MiniMax 支持 `reasoning_split: true` 参数，将思考内容分离到 `reasoning_details` 字段，而非嵌入 `content` 的 `<think>` 标签。

**现状：Hermes 没有内置机制传递 `extra_body_additions`。** 需手动 patch `run_agent.py`：

1. 在 `_build_api_kwargs` 中添加 MiniMax 检测标志：

```python
_is_minimax = "api.minimaxi.com" in self._base_url_lower
```

2. 在 Qwen metadata block 前注入 `extra_body_additions`：

```python
_extra_body_additions: dict | None = None
if _is_minimax:
    _extra_body_additions = {"reasoning_split": True}
```

3. 在 legacy flag path 的 `build_kwargs` 调用中传入：

```python
extra_body_additions=_extra_body_additions,
```

### 效果

- 响应中 `content` 不含 `<think>` 标签
- 思考内容在 `reasoning_details` 字段
- 纯文本回复更简洁，便于后续 tool call 处理

## 已知陷阱

### ❌ `api_mode: anthropic_messages` 无效

Hermes 的 Anthropic 认证走内置 Anthropic provider 的 auth 流（`ANTHROPIC_API_KEY`/`ANTHROPIC_TOKEN`），自定义 provider 的 `key_env` **不会被传递到 Anthropic client**。表现为 HTTP 401：

```
HTTP 401: login fail: Please carry the API secret key in the 'X-Api-Key' field
```

**解决方案：** 必须用 `api_mode: chat_completions` + OpenAI 兼容端点。

### ✅ 直接用 curl 验证

```bash
MM_KEY=$(grep '^MM_API_KEY=' ~/.hermes/.env | cut -d'=' -f2-)
curl -s https://api.minimaxi.com/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $MM_KEY" \
  -d '{
    "model": "MiniMax-M2.7",
    "max_tokens": 100,
    "reasoning_split": true,
    "messages": [{"role": "user", "content": "hi"}]
  }'
```

## 可用模型

| 模型 | 上下文 | 说明 |
|------|--------|------|
| MiniMax-M2.7 | 204,800 | 默认，约60 TPS |
| MiniMax-M2.7-highspeed | 204,800 | 极速版，约100 TPS |
| MiniMax-M2.5 | 204,800 | 性价比，约60 TPS |
| MiniMax-M2.5-highspeed | 204,800 | 极速版，约100 TPS |
| MiniMax-M2.1 | 204,800 | 编程增强，约60 TPS |

## 相关文件

- `~/.hermes/config.yaml` — providers.mm 配置
- `~/.hermes/.env` — MM_API_KEY
- `run_agent.py` — _build_api_kwargs / _is_minimax / reasoning_split 注入
- `agent/transports/chat_completions.py:364-366` — extra_body_additions 合并点
