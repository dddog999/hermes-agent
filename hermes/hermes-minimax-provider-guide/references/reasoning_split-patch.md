# reasoning_split run_agent.py Patch

## 补丁位置

文件： `/home/kangle/.hermes/hermes-agent/run_agent.py`

## 补丁内容

### 1. 添加 `_is_minimax` 标志（~line 8507）

在 `_is_nvidia` 行后添加：

```python
_is_nvidia = "integrate.api.nvidia.com" in self._base_url_lower
_is_minimax = "api.minimaxi.com" in self._base_url_lower  # ← 添加此行
_is_kimi = (
```

### 2. 注入 `extra_body_additions`（~line 8549）

在 `_ant_max` 处理块后、Qwen metadata 前添加：

```python
# MiniMax: enable reasoning_split for thinking separation
_extra_body_additions: dict | None = None
if _is_minimax:
    _extra_body_additions = {"reasoning_split": True}
```

### 3. 传递到 build_kwargs（~line 8644）

在 legacy flag path 的 build_kwargs 调用中添加参数：

```python
extra_body_additions=_extra_body_additions,
```

## 生效原理

1. `_build_api_kwargs` 中检测 `_is_minimax`
2. 设置 `_extra_body_additions = {"reasoning_split": True}`
3. 通过 `build_kwargs` 的 `extra_body_additions` 参数传到 `chat_completions` transport
4. transport 在 `line 364-366` 合并到 extra_body 字典
5. OpenAI SDK 序列化时将 `reasoning_split: true` 放入 HTTP 请求体

## 验证方法

```python
# 语法检查
python3 -c "import py_compile; py_compile.compile('run_agent.py', doraise=True); print('OK')"

# 实际调用测试
MM_KEY=$(grep '^MM_API_KEY=' ~/.hermes/.env | cut -d'=' -f2-)
curl -s https://api.minimaxi.com/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $MM_KEY" \
  -d '{
    "model": "MiniMax-M2.7",
    "max_tokens": 100,
    "reasoning_split": true,
    "messages": [{"role": "user", "content": "hi"}]
  }' | python3 -c "import sys,json; d=json.load(sys.stdin); c=d['choices'][0]['message']; print('reasoning_details' in c)"
```
