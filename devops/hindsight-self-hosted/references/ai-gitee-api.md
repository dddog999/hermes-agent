# AI Gitee API 参考（2026-05 实测）

## Token 获取

👉 https://ai.gitee.com/{username}/dashboard/settings/tokens

> ⚠️ **Token 必须绑定资源包**：所有模型（chat/embedding/reranker）都需要 token 绑定资源包后才能调用。未绑定时返回 `{"error":{"code":"400","message":"您正在使用的访问令牌尚未绑定到任何资源包，或账号未购买可用的资源包"}}`。

## 可用模型（`GET /v1/models`）

### Chat 模型
```
Qwen3-Embedding-8B
Qwen3-Embedding-4B
Qwen3-Embedding-0.6B
Qwen3-Reranker-8B
Qwen3-Reranker-4B
Qwen3-Reranker-0.6B
Qwen3.6-27B
Qwen3.6-35B-A3B
Qwen3.6-Max
Qwen3.6-Plus
Qwen3.5-9B
Qwen3.5-27B
Qwen3.5-35B-A3B
DeepSeek-V3
DeepSeek-R1
```

### Embedding 模型
```
Qwen3-Embedding-8B        # 1024 维，实测可用（2026-05）
Qwen3-Embedding-4B
Qwen3-Embedding-0.6B
jina-embeddings-v4
bge-m3
bge-small-zh-v1.5         # 384 维
bge-large-zh-v1.5
Youtu-Embedding
nomic-embed-code
bce-embedding-base_v1
```

### Reranker 模型
```
Qwen3-Reranker-8B
Qwen3-Reranker-4B
Qwen3-Reranker-0.6B
bge-reranker-large
bge-reranker-v2-m3         # 实测可用（2026-05）
bce-reranker-base_v1
jina-reranker-m0
Qwen3-VL-Reranker-2B
Qwen3-VL-Reranker-8B
```

## API 端点

- Base URL: `https://ai.gitee.com/v1`
- Chat: `POST /v1/chat/completions`
- Embedding: `POST /v1/embeddings`
- Rerank: `POST /v1/rerank`（部分模型支持）

## Hindsight 配置 AI Gitee Embedding/Reranker

### Embedding（OpenAI-compatible 模式）

```bash
export HINDSIGHT_API_EMBEDDINGS_PROVIDER=openai
export HINDSIGHT_API_EMBEDDINGS_OPENAI_API_KEY=your_token
export HINDSIGHT_API_EMBEDDINGS_OPENAI_BASE_URL=https://ai.gitee.com/v1
export HINDSIGHT_API_EMBEDDINGS_OPENAI_MODEL=Qwen3-Embedding-8B   # 1024 维
```

### Reranker（LiteLLM 模式）

```bash
export HINDSIGHT_API_RERANKER_PROVIDER=litellm
export HINDSIGHT_API_RERANKER_LITELLM_API_BASE=https://ai.gitee.com/v1
export HINDSIGHT_API_RERANKER_LITELLM_API_KEY=your_token
export HINDSIGHT_API_RERANKER_LITELLM_MODEL=bge-reranker-v2-m3
```

### 完整三组件混合配置（MiniMax LLM + AI Gitee Embedding + AI Gitee Reranker）

```bash
# LLM（MiniMax）
export HINDSIGHT_API_LLM_PROVIDER=openai
export HINDSIGHT_API_LLM_API_KEY=your_minimax_key
export HINDSIGHT_API_LLM_BASE_URL=https://api.minimax.chat/v1
export HINDSIGHT_API_LLM_MODEL=MiniMax-M2.7

# Embedding（AI Gitee）
export HINDSIGHT_API_EMBEDDINGS_PROVIDER=openai
export HINDSIGHT_API_EMBEDDINGS_OPENAI_API_KEY=your_gitee_token
export HINDSIGHT_API_EMBEDDINGS_OPENAI_BASE_URL=https://ai.gitee.com/v1
export HINDSIGHT_API_EMBEDDINGS_OPENAI_MODEL=Qwen3-Embedding-8B

# Reranker（AI Gitee，LiteLLM 模式）
export HINDSIGHT_API_RERANKER_PROVIDER=litellm
export HINDSIGHT_API_RERANKER_LITELLM_API_BASE=https://ai.gitee.com/v1
export HINDSIGHT_API_RERANKER_LITELLM_API_KEY=your_gitee_token
export HINDSIGHT_API_RERANKER_LITELLM_MODEL=bge-reranker-v2-m3
```

## 已知限制

- **embedding 维度必须匹配**：切换 embedding 模型时，如果新模型维度与数据库已有数据的维度不一致（例如 384 → 1024），启动时报错 `Cannot change embedding dimension from 384 to 1024`，应用退出。解法（无需 psql 密码，直接操作 PG 数据文件）：
  1. `taskkill //F //IM postgres.exe` 停掉所有 hindsight 内嵌 PG 进程
  2. `cp -r ~/.pg0/instances/hindsight/data ~/.pg0_backup_$(date +%Y%m%d)/` 备份数据
  3. `rm -rf ~/.pg0/instances/hindsight/data/*` 清空数据文件（强制用新维度重新初始化）
  4. 重启 hindsight-api，新模型会生成新维度的 embedding
  - 注意：所有旧记忆会丢失，需要重新 retain
