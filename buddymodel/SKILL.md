---
name: codebuddy-model-config
description: 用于在 CodeBuddy 中添加自定义模型配置，包括 models.json 配置、API 密钥设置、常用平台示例（OpenRouter、DeepSeek、Ollama 等）
---

# CodeBuddy 自定义模型配置技能

## 触发条件

当用户提到以下内容时使用此技能：
- "添加模型"
- "配置模型"
- "models.json"
- "自定义模型"
- "添加 API 密钥"
- "配置 OpenRouter"
- "配置 Ollama"
- "列出 Zen 免费模型"
- "免费模型"
- "Zen 模型"
- "配置好<模型名>"
- "自动配置模型"

## 配置位置

### 用户级配置
- 路径: `~/.codebuddy/models.json`
- 作用域: 全局，所有项目共享

### 项目级配置
- 路径: `<项目根目录>/.codebuddy/models.json`
- 作用域: 仅当前项目

### 优先级
项目级 > 用户级 > 内置默认

## 配置结构

```json
{
  "models": [
    {
      "id": "model-id",
      "name": "Model Display Name",
      "vendor": "vendor-name",
      "apiKey": "sk-actual-api-key-value",
      "maxInputTokens": 200000,
      "maxOutputTokens": 8192,
      "url": "https://api.example.com/v1/chat/completions",
      "temperature": 0.7,
      "supportsToolCall": true,
      "supportsImages": true,
      "supportsReasoning": false
    }
  ],
  "availableModels": ["model-id-1", "model-id-2"]
}
```

## 配置字段说明

| 字段 | 必填 | 说明 |
|------|------|------|
| id | ✓ | 模型唯一标识符 |
| name | - | 模型显示名称 |
| vendor | - | 供应商（如 OpenAI, DeepSeek, Ollama） |
| apiKey | - | API 密钥 |
| maxInputTokens | - | 最大输入 token 数 |
| maxOutputTokens | - | 最大输出 token 数 |
| url | - | API 端点（必须以 /chat/completions 结尾） |
| temperature | - | 采样温度 (0-2) |
| supportsToolCall | - | 是否支持工具调用 |
| supportsImages | - | 是否支持图片输入 |
| supportsReasoning | - | 是否支持推理模式 |

## 常用平台配置示例

### OpenRouter

```json
{
  "models": [
    {
      "id": "openrouter/hunter-alpha",
      "name": "Hunter Alpha",
      "vendor": "OpenAI",
      "apiKey": "sk-or-v1-your-openrouter-api-key",
      "maxInputTokens": 1048576,
      "maxOutputTokens": 8192,
      "url": "https://openrouter.ai/api/v1/chat/completions",
      "supportsToolCall": true,
      "supportsReasoning": false
    }
  ]
}
```

### DeepSeek

```json
{
  "models": [
    {
      "id": "deepseek-chat",
      "name": "DeepSeek Chat",
      "vendor": "DeepSeek",
      "apiKey": "sk-your-deepseek-api-key",
      "maxInputTokens": 32000,
      "maxOutputTokens": 4096,
      "url": "https://api.deepseek.com/v1/chat/completions",
      "supportsToolCall": true
    }
  ]
}
```

### Ollama (本地)

```json
{
  "models": [
    {
      "id": "my-local-llm",
      "name": "My Local LLM",
      "vendor": "Ollama",
      "url": "http://localhost:11434/v1/chat/completions",
      "apiKey": "ollama",
      "maxInputTokens": 8192,
      "maxOutputTokens": 2048,
      "supportsToolCall": true
    }
  ]
}
```

### ModelScope

```json
{
  "models": [
    {
      "id": "Qwen/Qwen3.5-397B-A17B",
      "name": "Qwen 3.5 397B",
      "vendor": "ModelScope",
      "apiKey": "ms-8bc07a5e-d5a4-46a5-9c51-14d6b70cbf6f",
      "maxInputTokens": 128000,
      "maxOutputTokens": 8192,
      "url": "https://api-inference.modelscope.cn/v1/chat/completions",
      "supportsToolCall": true,
      "supportsReasoning": true,
      "supportsImages": true,
      "temperature": 0.7,
      "top_p": 0.95
    }
  ]
}
```

### Zen (OpenCode AI)

```json
{
  "models": [
    {
      "id": "opencode/mimo-v2-pro-free",
      "name": "MIMO V2 Pro (Free)",
      "vendor": "Zen",
      "apiKey": "YOUR_ZEN_API_KEY",
      "maxInputTokens": 128000,
      "maxOutputTokens": 8192,
      "url": "https://opencode.ai/zen/v1/chat/completions",
      "supportsToolCall": true,
      "supportsReasoning": true,
      "temperature": 1.0,
      "top_p": 0.95
    }
  ]
}
```

**Zen 免费模型推荐配置参数：**

| 参数 | 推荐值 | 说明 |
|------|--------|------|
| `maxInputTokens` | 128000 | 最大输入 token 数 |
| `maxOutputTokens` | 8192 | 最大输出 token 数 |
| `supportsToolCall` | true | 支持工具调用 |
| `supportsReasoning` | true | 支持推理模式 |
| `temperature` | 1.0 | 采样温度 |
| `top_p` | 0.95 | Top-p 采样 |

## 操作步骤

### 1. 添加新模型

1. 读取当前 models.json（如不存在则创建）
2. 在 models 数组中添加新模型配置
3. 保存文件（支持热重载）

### 2. 修改现有模型

1. 读取 models.json
2. 找到对应模型 ID 的配置
3. 修改需要更新的字段
4. 保存文件

### 3. 删除模型

1. 读取 models.json
2. 从 models 数组中移除对应配置
3. 保存文件

## 注意事项

1. **API 密钥安全**:
   - **不要将密钥提交到代码仓库**
   - API Key 应存储在 `~/.codebuddy/.env` 文件中
   - 在 `models.json` 中 `apiKey` 字段可以留空，CodeBuddy 会自动从 `.env` 读取对应的环境变量
   - 或在 `.env` 中设置 `ZEN_API_KEY=your-key` 等平台对应的环境变量

2. **URL 格式**: 必须以 `/chat/completions` 结尾

3. **availableModels**: 如不配置则显示所有模型

4. **热重载**: 配置文件变更后约 1 秒自动生效

5. **保持用户原始格式**: 当用户提供配置示例时，必须逐字逐句复制所有字段和值，包括：
   - 模型 ID 的原始格式（如 `Qwen/Qwen3.5-397B-A17B` 包含斜杠和大小写）
   - 所有可选字段（如 `supportsReasoning`, `top_p`）
   - 不要擅自"规范化"或"优化"用户的配置
   - 如果配置缺少必填字段，应该询问用户确认，而不是自行推断

6. **配置位置**: 所有模型配置都在 `~/.codebuddy/models.json`（用户级全局配置），不推荐使用项目级配置

## Zen 免费模型查询

### 功能说明
从 Zen API (`https://opencode.ai/zen/v1/models`) 获取可用模型列表，筛选出包含 "free" 后缀的免费模型并展示给用户。

### 工作流程
1. 获取 Zen API 的模型列表
2. 筛选出 `id` 包含 "free" 的模型（通常以 `-free` 结尾）
3. 展示模型的详细信息，包括：模型 ID、名称、输入/输出 token 限制等
4. 提供模型配置建议

## 自动配置模型

### 功能说明
根据用户指定的模型名称，自动从 Zen API 或其他源获取模型配置，并添加到 CodeBuddy 的 models.json 中。

### 工作流程
1. 识别用户指定的模型名称（模糊匹配或精确 ID）
2. 查询模型配置信息（优先从本地缓存或 API 获取）
3. 构建符合 CodeBuddy 格式的模型配置对象
4. 确定配置位置（用户级或项目级）
5. 读取现有 models.json（如不存在则创建）
6. 检查是否已存在相同 ID 的配置
7. 添加模型配置并保存
8. 通知用户配置完成，提供模型使用说明

### 触发示例
- "配置好 Qwen/Qwen3.5-397B-A17B"
- "添加模型 deepseek-chat"
- "帮我配置 free 模型"

## API Key 获取地址

| 平台 | 地址 |
|------|------|
| OpenAI | https://platform.openai.com/api-keys |
| OpenRouter | https://openrouter.ai/keys |
| DeepSeek | https://platform.deepseek.com/ |
| ModelScope | https://modelscope.cn/ |
| Zen | https://opencode.ai/ |
| Google AI | https://aistudio.google.com/app/apikey |
| Groq | https://console.groq.com/keys |

## 常见问题

### 配置未生效
1. 检查 JSON 格式是否正确
2. 确认文件路径正确
3. 验证 API 密钥已填写

### 模型未显示
1. 检查模型 ID 是否在 availableModels 中
2. 确认必填字段已提供

## 参考文档

本技能依赖以下参考文件：

- `@codebuddy-model-config/reference/opencodeZen.md` - Zen API 模型配置指南
- `@codebuddy-model-config/reference/codebuddy-models-json-config.md` - CodeBuddy models.json 完整配置指南
- `@codebuddy-model-config/reference/.env` - 环境变量配置示例（包含 API Key 安全配置）

## 常见错误案例

### 错误：擅自修改模型 ID 格式

❌ 用户提供：`"id": "Qwen/Qwen3.5-397B-A17B"`
❌ 错误配置：`"id": "modelscope/qwen3.5-397b-a17b"` （擅自转换为小写）
✅ 正确配置：`"id": "Qwen/Qwen3.5-397B-A17B"` （保持原样）

**原因**：不同平台的模型 ID 有严格格式要求（区分大小写、包含斜杠等），必须完全按照示例或文档使用。

### 错误：遗漏用户提供的字段

❌ 用户提供包含：`"supportsReasoning": true`, `"top_p": 0.95`
❌ 错误配置：省略这些字段
✅ 正确配置：完整保留所有用户提供的字段

**原因**：用户提供的配置通常是完整可用的，应该尊重原始输入。
