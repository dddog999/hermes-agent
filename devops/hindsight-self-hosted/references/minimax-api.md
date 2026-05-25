# MiniMax API 参考（2026-05 实测）

## 可用模型（`GET /v1/models`）

```
MiniMax-M2.7
MiniMax-M2.7-highspeed
MiniMax-M2.5
MiniMax-M2.5-highspeed
MiniMax-M2.1
MiniMax-M2.1-highspeed
MiniMax-M2
```

> ⚠️ `MiniMax-Text-01` 已废弃/改名，用 `MiniMax-M2.7`。错误信息：`your current token plan not support model, MiniMax-Text-01 (2061)`

## LLM 调用

```bash
curl https://api.minimax.chat/v1/chat/completions \
  -H "Authorization: Bearer $MINIMAX_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"MiniMax-M2.7","messages":[{"role":"user","content":"hi"}]}'
```

base_url: `https://api.minimax.chat/v1`
provider 填 `openai`（Hindsight 用 OpenAI-compatible 方式调用）

## Embedding API

```bash
curl https://api.minimax.chat/v1/embeddings \
  -H "Authorization: Bearer $MINIMAX_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"embo","type":"db_code","texts":["hello"]}'
```

实测：默认余额 `insufficient balance`。Hindsight 本地 embedding（`BAAI/bge-small-en-v1.5`）无需 API key。

## Hindsight 推荐配置

| 参数 | 值 |
|------|-----|
| `HINDSIGHT_API_LLM_PROVIDER` | `openai` |
| `HINDSIGHT_API_LLM_BASE_URL` | `https://api.minimax.chat/v1` |
| `HINDSIGHT_API_LLM_MODEL` | `MiniMax-M2.7` |
| Embeddings | 本地（默认 `BAAI/bge-small-en-v1.5`，无需配置） |
