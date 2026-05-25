# Provider/Model 切换调试指南

## Provider 名称精确匹配

**核心规则**：`/model --provider <name>` 中的 `<name>` 必须与 `config.yaml` 中 `providers:` 下定义的 key **完全一致**（大小写、连字符、缩写都算）。

**典型错误**：
```
# 用户输入
/model --provider openrouter inclusionai/ling-2.6-1t:free

# 但配置里 provider 名是 OR，不是 openrouter
providers:
  OR:          # ← 实际名称
    base_url: https://openrouter.ai/api/v1
```

**错误信息**：
```
Error: Could not resolve credentials for provider 'OpenRouter': ...
```

**排查步骤**：
1. 查看远程机器上的配置：`cat ~/.hermes/config.yaml | grep -A 5 "^providers:"`
2. 找到 provider 的实际 key 名称
3. 用精确名称切换：`/model --provider OR inclusionai/ling-2.6-1t:free`

## kangle 机器特殊配置

kangle (100.125.109.54) 的 provider 名称与 wooking 不同：
- OpenRouter → provider key 是 `OR`（不是 `openrouter`）
- MiniMax → provider key 是 `minimax-cn`（不是 `minimax`）

**查看远程配置**：
```bash
ssh kangle@100.125.109.54 "grep -A 3 '^providers:' ~/.hermes/config.yaml"
```

## 快速诊断命令

```bash
# 查看当前运行的 provider/model
ssh kangle@100.125.109.54 "cat ~/.hermes/config.yaml | grep -E 'provider:|default:'"

# 查看 gateway 进程
ssh kangle@100.125.109.54 "ps aux | grep hermes | grep -v grep"

# 查看 .env 中的 API key
ssh kangle@100.125.109.54 "grep -i 'OPENROUTER\|MINIMAX' ~/.hermes/.env"
```
