# models.json 配置指南

来源：[CodeBuddy 官方文档 - models.json 配置指南](https://www.codebuddy.ai/docs/zh/ide/Features/models)

---

## **models.json 配置指南**

### **概述**
`models.json` 是一个配置文件，用于自定义模型列表和控制模型下拉列表的显示。该配置支持两个级别：
- **用户级**: `~/.codebuddy/models.json` - 全局配置，适用于所有项目
- **项目级**: `<workspace>/.codebuddy/models.json` - 项目特定配置，优先级高于用户级

### **配置文件位置**
- **用户级配置**: `~/.codebuddy/models.json`
- **项目级配置**: `<project-root>/.codebuddy/models.json`

### **配置优先级**
配置合并优先级从高到低：
1. 项目级 models.json
2. 用户级 models.json
3. 内置默认配置

项目级配置会覆盖用户级配置中的相同模型定义（基于 `id` 字段匹配）。`availableModels` 字段：项目级完全覆盖用户级，不进行合并。

### **配置结构**
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
      "supportsImages": true
    }
  ]
}
```

### **配置字段说明**

#### **models**
- **类型**: `Array<LanguageModel>`
- **说明**: 定义自定义模型列表。可以添加新模型或覆盖内置模型配置。

##### **LanguageModel 字段**

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `id` | string | ✓ | 模型唯一标识符 |
| `name` | string | - | 模型显示名称 |
| `vendor` | string | - | 模型供应商（如 OpenAI, Google） |
| `apiKey` | string | - | API 密钥（实际密钥值，非环境变量名） |
| `maxInputTokens` | number | - | 最大输入 token 数 |
| `maxOutputTokens` | number | - | 最大输出 token 数 |
| `url` | string | - | API 端点 URL（必须是接口完整路径，一般以 `/chat/completions` 结尾） |
| `temperature` | number | - | 采样温度，范围 0-2，值越高输出越随机，值越低输出越确定 |
| `supportsToolCall` | boolean | - | 是否支持工具调用 |
| `supportsImages` | boolean | - | 是否支持图片输入 |
| `supportsReasoning` | boolean | - | 是否支持推理模式 |

**重要说明：**
- 目前仅支持 OpenAI 接口格式的 API
- `url` 字段必须是接口完整路径，一般以 `/chat/completions` 结尾
- 例如: `https://api.openai.com/v1/chat/completions` 或 `http://localhost:11434/v1/chat/completions`

#### **availableModels**
- **类型**: `Array<string>`
- **说明**: 控制模型下拉列表中显示哪些模型。只有在此数组中列出的模型 ID 才会在 UI 中显示。
  - 如果未配置或为空数组，则显示所有模型
  - 配置后，只显示列出的模型 ID
  - 可以同时包含内置模型和自定义模型的 ID

### **使用场景**

#### **1. 添加自定义模型**
在用户级或项目级添加新的模型配置：
```json
{
  "models": [
    {
      "id": "my-custom-model",
      "name": "My Custom Model",
      "vendor": "OpenAI",
      "apiKey": "sk-custom-key-here",
      "maxInputTokens": 128000,
      "maxOutputTokens": 4096,
      "url": "https://api.myservice.com/v1/chat/completions",
      "supportsToolCall": true
    }
  ]
}
```

#### **2. 覆盖内置模型配置**
修改内置模型的默认参数：
```json
{
  "models": [
    {
      "id": "gpt-4-turbo",
      "name": "GPT-4 Turbo (Custom Endpoint)",
      "vendor": "OpenAI",
      "url": "https://my-proxy.example.com/v1/chat/completions",
      "apiKey": "sk-your-key-here"
    }
  ]
}
```

#### **3. 限制可用模型列表**
只在下拉列表中显示特定模型：
```json
{
  "availableModels": [
    "gpt-4-turbo",
    "gpt-4o",
    "my-custom-model"
  ]
}
```

#### **4. 项目特定配置**
为特定项目使用不同的模型或 API 端点：
**项目 A** (`.codebuddy/models.json`):
```json
{
  "models": [
    {
      "id": "project-a-model",
      "name": "Project A Model",
      "vendor": "OpenAI",
      "url": "https://project-a-api.example.com/v1/chat/completions",
      "apiKey": "sk-project-a-key",
      "maxInputTokens": 100000,
      "maxOutputTokens": 4096
    }
  ],
  "availableModels": ["project-a-model", "gpt-4-turbo"]
}
```

### **热重载**
配置文件支持热重载：
- 文件变更会被自动检测
- 使用 1 秒防抖延迟避免频繁重载
- 配置更新后会自动同步到应用

监听的文件：
- `~/.codebuddy/models.json`（用户级）
- `<workspace>/.codebuddy/models.json`（项目级）

### **标签系统**
通过 `models.json` 添加的模型会自动标记 `custom` 标签，便于在 UI 中识别和过滤。

### **合并策略**
配置使用 `SmartMerge` 策略：
- 相同 ID 的模型配置会被覆盖
- 不同 ID 的模型会被追加
- 项目级配置优先于用户级配置
- `availableModels` 过滤在所有合并完成后执行

### **示例配置**

#### **API 端点 URL 格式说明**
**必须使用完整路径：** 所有自定义模型的 `url` 字段一般以 `/chat/completions` 结尾。

✅ **正确示例：**
```
https://api.openai.com/v1/chat/completions
https://api.myservice.com/v1/chat/completions
http://localhost:11434/v1/chat/completions
https://my-proxy.example.com/v1/chat/completions
```

❌ **错误示例：**
```
https://api.openai.com/v1
https://api.myservice.com
http://localhost:11434
```

#### **OpenRouter 平台配置示例**
使用 OpenRouter 访问多种模型：
```json
{
  "models": [
    {
      "id": "openai/gpt-4o",
      "name": "open-router-model",
      "url": "https://openrouter.ai/api/v1/chat/completions",
      "apiKey": "sk-or-v1-your-openrouter-api-key",
      "maxInputTokens": 128000,
      "maxOutputTokens": 4096,
      "supportsToolCall": true,
      "supportsImages": false
    }
  ]
}
```

#### **DeepSeek 平台配置示例**
使用 DeepSeek 模型：
```json
{
  "models": [
    {
      "id": "deepseek-chat",
      "name": "DeepSeek Chat",
      "vendor": "DeepSeek",
      "url": "https://api.deepseek.com/v1/chat/completions",
      "apiKey": "sk-your-deepseek-api-key",
      "maxInputTokens": 32000,
      "maxOutputTokens": 4096,
      "supportsToolCall": true,
      "supportsImages": false
    }
  ]
}
```

#### **完整示例**
```json
{
  "models": [
    {
      "id": "gpt-4o",
      "name": "GPT-4o",
      "vendor": "OpenAI",
      "apiKey": "sk-your-openai-key",
      "maxInputTokens": 128000,
      "maxOutputTokens": 16384,
      "supportsToolCall": true,
      "supportsImages": true
    },
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
  ],
  "availableModels": [
    "gpt-4o",
    "my-local-llm"
  ]
}
```

### **故障排查**

#### **配置未生效**
1. 检查 JSON 格式是否正确
2. 确认文件路径是否正确
3. 查看日志输出确认配置是否被加载
4. 确认环境变量中的 API 密钥是否已设置

#### **模型未在列表中显示**
1. 检查模型 ID 是否在 `availableModels` 中列出
2. 确认 `models` 配置是否正确
3. 验证必填字段（`id`, `name`, `provider`）是否都已提供

#### **热重载未触发**
- 配置文件变更有 1 秒防抖延迟
- 确保文件确实被保存到磁盘
- 检查文件监听是否正常启动（查看调试日志）
