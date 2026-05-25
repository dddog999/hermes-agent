# MiniMax API URL 配置

## 关键区别

MiniMax 有两个 API 端点，**不要混淆**：

| 环境 | Base URL | 用途 |
|------|----------|------|
| **CN（中国）** | `https://api.minimaxi.com/v1` | dddog 使用的 |
| **International** | `https://api.minimax.io/v1` | 海外版 |

> 拼写：不是 `.io`，不是 `.com/anthropic`，是 `.minimaxi.com`（CN 站）。

## auth.json credential pool 配置

路径：`~/.hermes/auth.json` → `credential_pool`

```json
{
  "minimax-cn": [
    {
      "label": "MINIMAX_CN_API_KEY",
      "source": "env:MINIMAX_CN_API_KEY",
      "base_url": "https://api.minimaxi.com/v1"   ← 正确
    }
  ],
  "minimax": [
    {
      "label": "MINIMAX_API_KEY",
      "source": "env:MINIMAX_API_KEY",
      "base_url": "https://api.minimaxi.com/v1"   ← 错误常写成 https://api.minimax.io/anthropic
    }
  ]
}
```

**正确 base_url**：`https://api.minimaxi.com/v1`（两个条目都应相同）

**常见错误**：
- 写成 `https://api.minimax.io/anthropic` → 404 page not found
- 写成 `https://api.minimaxi.com/anthropic` → 多余的 /anthropic 路径

## 验证命令

```bash
python3 -c "
import json, os
path = os.path.expanduser('~/.hermes/auth.json')
with open(path) as f:
    data = json.load(f)
for k in ['minimax', 'minimax-cn']:
    entries = data['credential_pool'].get(k, [])
    for e in entries:
        url = e.get('base_url', 'N/A')
        ok = '✅' if 'minimaxi.com/v1' in url and 'anthropic' not in url else '❌'
        print(f'{ok} {k}: {url}')
"
```

## 子代理调用链路

1. 子代理用 `MINIMAX_API_KEY` → 匹配 `credential_pool.minimax`
2. 如果 base_url 错误 → `https://api.minimax.io/anthropic` → 404
3. 修复后 → `https://api.minimaxi.com/v1/chat/completions` → 正常

## config.yaml vs auth.json

- `config.yaml` 里的 `model.base_url` 和 `providers.minimax.base_url` 是主会话用的
- `auth.json` 的 `credential_pool` 是子代理 API key 匹配时用的
- **两者都必须正确**，子代理才会通
