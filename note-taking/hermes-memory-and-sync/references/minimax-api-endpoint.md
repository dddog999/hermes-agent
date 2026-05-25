# MiniMax API 配置参考

## Anthropic 兼容端点（2026-05 实测有效）

```
ANTHROPIC_BASE_URL=https://api.minimaxi.com/anthropic
ANTHROPIC_API_KEY=${MINIMAX_API_KEY}
```

MiniMax 同时提供两个端点：
- `https://api.minimaxi.com/anthropic` — Anthropic API 兼容格式（支持 Claude 模型调用方式）
- `https://api.minimaxi.com/v1` — 标准 OpenAI 兼容格式

## .env 配置示例

```env
MINIMAX_CN_API_KEY=sk-cp-xxx
MINIMAX_CN_BASE_URL=https://api.minimaxi.com/v1
```

## 401 排查

如果 `MINIMAX_CN_API_KEY` 返回 401 invalid api key：
1. 确认 key 还有额度（登录 https://www.minimax.io 查看）
2. 尝试用 `ANTHROPIC_BASE_URL=https://api.minimaxi.com/anthropic` + `ANTHROPIC_API_KEY`
3. `.env` 中 key 前面有 `#` 注释符会导致 key 被当成注释
