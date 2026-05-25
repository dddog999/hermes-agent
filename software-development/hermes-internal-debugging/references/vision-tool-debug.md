# Hermes Vision Tool 调试笔记

## 工具架构

```
browser_vision(question) → browser_tool.py
  ├─ 初始化/连接agent-browser（LightPanda CDP）
  ├─ 截取当前页面 → /home/dddog/.hermes/cache/screenshots/*.png
  └─ 返回截图路径

vision_analyze(image_url, question) → vision_tools.py
  ├─ 下载图片（如果是URL）
  ├─ 调用auxiliary.vision配置的后端
  └─ 返回分析结果
```

## 诊断步骤

### 1. 检查browser_vision截图质量

```bash
# 检查最新截图文件
ls -la ~/.hermes/cache/screenshots/ | tail -5

# 验证截图是否有效
file ~/.hermes/cache/screenshots/browser_screenshot_*.png
# 有效截图: PNG image data, 应该是 500KB+
# 异常截图: 3742 bytes 等极小值 → browser_vision内部问题

# 截图尺寸
identify ~/.hermes/cache/screenshots/browser_screenshot_*.png 2>/dev/null || \
file ~/.hermes/cache/screenshots/browser_screenshot_*.png
```

### 2. 检查auxiliary.vision配置

```bash
# 查看当前vision配置
grep -A 10 "auxiliary:" ~/.hermes/config.yaml | grep -A 8 "vision:"

# 常用免费vision模型（按可用性排序）
auxiliary:
  vision:
    provider: openrouter
    model: anthropic/claude-3-haiku  # 免费，但可能有地区限制
```

### 3. 测试OpenRouter API连通性

```bash
# 检查API key
grep OPENROUTER_API_KEY ~/.hermes/.env

# 测试API（文本请求）
curl -s -H "Authorization: Bearer $KEY" \
  "https://openrouter.ai/api/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{"model":"anthropic/claude-3-haiku","messages":[{"role":"user","content":"hi"}],"max_tokens":10}'
```

## 常见故障

### 故障1: "抱歉，我目前没有看到任何图片"

**症状**: vision_analyze返回"抱歉，我目前没有看到任何图片"  
**原因**: MiniMax不支持vision  
**解决**: 修改`~/.hermes/config.yaml` auxiliary.vision.provider为openrouter

### 故障2: "Connection error"

**症状**: vision_analyze返回"Connection error"  
**原因**: OpenRouter API地区限制或超时  
**诊断**:
```python
# Python测试
import requests
resp = requests.post("https://openrouter.ai/api/v1/chat/completions", 
  headers={"Authorization": f"Bearer {api_key}"},
  json={"model": "anthropic/claude-3-haiku", 
        "messages": [{"role": "user", "content": "hi"}], 
        "max_tokens": 10},
  timeout=30)
print(resp.status_code, resp.text[:200])
```
**常见错误码**:
- 403: "This model is not available in your region" → 换模型
- 429: Rate limit → 等待后重试
- 空响应: Connection aborted → 超时或网络问题

### 故障3: 截图文件极小(3742 bytes)

**症状**: `file screenshot.png` 显示异常小的字节数  
**原因**: browser_vision内部CDP调用问题  
**诊断**: 重试browser_vision，确保浏览器已初始化

## 本次会话发现(2026-05-07)

- OpenRouter免费vision模型普遍有地区限制
- anthropic/claude-3-haiku → 403
- google/gemini-2.0-flash-exp → 403或Connection aborted
- openai/gpt-4o-mini → 403
- nvidia/nemotron-3-nano-omni → 可用文本，但不支持vision（返回content:null）
- MiniMax-M2.7 → 不支持vision

**建议**: 优先使用 `anthropic/claude-3-haiku`，如遇403则需手动从截图复制文字
