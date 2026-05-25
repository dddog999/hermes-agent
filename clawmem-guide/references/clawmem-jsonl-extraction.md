# Clawmem Jsonl Extraction
> Absorbed from archived skill `clawmem-jsonl-extraction` during consolidation pass (2026-05-22).

---


# ClawMem JSONL 直读提取架构

## 背景

ClawMem 现有流程（Phase 4/5）：
```
Stop Hook → JSONL → 转文本 → L2 markdown → 免费模型提取 L0/L1
```

问题：多了一步不必要的格式转换。JSONL 本身对 LLM 来说是天然结构化数据。

## 核心发现

1. **LLM 完全能理解 JSONL 格式**——已验证，MiniMax-M2.7 成功提取了 JSONL 格式的对话记忆
2. **Hermes 会话也是 JSONL**（`~/.hermes/sessions/*.jsonl`），格式与 CodeBuddy 相似
3. **时间顺序天然保序**——JSONL 按行排列即为时间顺序，LLM 无需额外处理

## 三种输入格式

| 格式 | Stop Hook 输出 | Extractor 输入 | 检测方式 |
|------|---------------|----------------|---------|
| CodeBuddy JSONL | 需改写直接存 JSONL | JSONL array | `role` + `content` 数组 |
| Hermes JSONL | 新增 Hermes stop hook | JSONL array | `role` + `content` + `session_meta` 行 |
| Markdown (Phase4) | 已有 | `## Turn N — 用户` 分块 | 文件扩展名 `.md` |

### JSONL 格式对比

**CodeBuddy:**
```json
{"role": "user", "content": [{"text": "..."}], "providerData": {...}}
```

**Hermes:**
```json
{"role": "user", "content": "直接是字符串", "timestamp": "...", "reasoning": "..."}
{"role": "assistant", "content": "直接是字符串", "finish_reason": "stop", ...}
{"role": "session_meta", "tools": [...], "model": "...", ...}
```

关键区别：
- `content`: CodeBuddy 是 `[{text: "..."}]` 数组，Hermes 直接是 string
- `session_meta`: Hermes 有，CodeBuddy 没有（第一条是 `session_meta`）

## 实际实现（2026-04-25）

### 1. JSONL 双层分块问题（已发现，规划 v2.0 修复）

`extractFromFiles()` 的 JSONL 路径存在双重分块：

```
JSONL → splitMessagesIntoChunks(50条/组) → formatMessagesAsText → extractMemories → splitContent(1500字符)
```

- 188条消息 → 先按50条分成4组
- 每组格式化后 24-76KB 文本
- 再各自按1500字符二次分块
- 实际产生 64+ 次 LLM 调用

同样内容的 Markdown 文件只产生 5 次调用。

根源：`splitContent()` 只能识别 Markdown 里的 `## Turn N — 用户` 标记，JSONL 格式化后找不到断点，大 JSONL 反而分块不足。

### 2. Topic-Based 提取流程（v2.0 方向，未实现）

流程：
1. JSONL → 格式化文本
2. LLM 话题分割（一次调用）：输出 topic 列表 + 每个 topic 的 L0/L1 提取
3. 每个 topic：向量搜索已有 L0/L1 → 命中则 merge，未命中则新建
4. 跨文件同一话题通过向量相似度识别合并

关键优势：
- 不按消息数量硬切，按语义话题分
- 跨文件同一话题自动去重（利用已有向量库）
- 不需要 topic.md 索引

新 prompt：`src/summarize/prompts/topic-extraction.yaml`（规划中，文件未写入成功）

### 3. 新增 jsonl-adapter.ts

文件：`src/summarize/jsonl-adapter.ts`

```typescript
// 核心函数
parseJsonlFile(filePath)           // 读文件，检测格式（Hermes vs CodeBuddy）
parseJsonlContent(raw)             // 解析原始文本
detectJsonlFormat(line)            // 自动识别 Hermes 或 CodeBuddy
formatMessagesAsText(messages)     // 转成"用户：..." / "AI：..."文本
splitMessagesIntoChunks(messages, 50)  // 按消息条数分块（50条/块）
```

格式检测逻辑：
```typescript
// Hermes: content 是 string
if (typeof obj.content === 'string') return 'hermes';
// CodeBuddy: content 是 [{text: "..."}] 数组
if (Array.isArray(obj.content)) return 'codebuddy';
```

### 4. 修改 extractor.mjs

改动：
- 导入 `jsonl-adapter.ts`
- `extractFromFiles()` 加了 JSONL 分支：`.jsonl` → `parseJsonlFile()` → `splitMessagesIntoChunks()` → `formatMessagesAsText()` → `extractMemories()`
- 新增 `openrouter` apiType 分支（默认模型 `inclusionai/ling-2.6-1t:free`）
- 新增 fallback model 机制：主模型重试3次失败后自动切换 `nvidia/nemotron-3-super-120b-a12b:free`
- 默认模型从 `nvidia/nemotron-3-nano-30b-a3b` 改为 `inclusionai/ling-2.6-1t:free`

OpenRouter 分支：
```javascript
} else if (apiType === 'openrouter') {
  const effectiveKey = apiKey || process.env.CLAWMEM_OPENROUTER_API_KEY || '';
  const r = await fetch('https://openrouter.ai/api/v1/chat/completions', {
    headers: {
      'Authorization': `Bearer ${effectiveKey}`,
      'HTTP-Referer': 'https://clawmem.local',
      'X-Title': 'ClawMem'
    },
    body: JSON.stringify({
      model: model || 'inclusionai/ling-2.6-1t:free',
      messages: [{ role: 'user', content: segmentPrompt }],
      temperature: 0.3,
      max_tokens: 8192
    })
  });
}
```

Fallback 机制（withRetry 改造）：
```javascript
// 主模型重试 3 次（8s → 16s → 32s）
httpRes = await withRetry(async (retryModel) => {
  // model: (retryModel || model) ← 支持动态切换
}, 3);

// 主模型 3 次全失败 → 切换 fallback
} catch (primaryErr) {
  if (fallbackModel) {
    console.warn(`  ⚡ Primary failed, switching to fallback: ${fallbackModel}`);
    httpRes = await withRetry(async (retryModel) => { ... }, 3, 15000, fallbackModel);
  } else {
    throw primaryErr;
  }
}
```

### 5. 修改 CLI summarize 命令

- `<path>` 改为 `<paths...>`（支持多路径）
- `--api-type` 默认值 `nvidia` → `openrouter`
- `--model` 默认值 `nemotron-3-nano-30b-a3b` → `inclusionai/ling-2.6-1t:free`
- 目录扫描：同时收集 `.md`（Phase4）和 `.jsonl` 文件
- `extractFromFiles()` 现在同时处理 MD 和 JSONL

### 6. 新增 cron 脚本

`scripts/daily-summarize.sh`：
- 每天 0 点运行
- 处理 Hermes sessions（`~/.hermes/sessions`）和 CodeBuddyHistory 两个路径
- 使用 OpenRouter 免费模型
- 日志输出到 `logs/cron-summarize.log`

## LLM 验证结果

**测试条件：** MiniMax-M2.7，6 条对话 JSONL 格式
**结果：** 成功提取 2 条记忆，分类准确，理解了时间顺序

```
Prompt tokens: 571
Completion tokens: 657
总 tokens: 1228
```

## 架构优势

1. **省 token**：`role`/`content` 字段比 markdown 标签更紧凑
2. **省步骤**：Stop Hook 直接写 JSONL，不用转文本
3. **统一处理**：三套格式最终都转成 MemoryResult[]
4. **保留 metadata**：timestamp 可用于时序分析

## 注意事项

1. **过滤 `session_meta` 行**：Hermes 的 tools schema 太大，每 session 只取第一条
2. **content 字段处理**：CodeBuddy 是数组要 `.text` 取，Hermes 直接 string
3. **增量处理**：Hermes session 文件会不断追加，应按 mtime 增量读取新行
4. **Topic-Based 提取**（v2.0）：`extractTopicBased()` 函数已实现，替代旧的分块逻辑
   - `extractFromFiles()` 支持 `useTopicBased: true` 选项启用
   - 话题数 = LLM 调用数，避免双重分块

## 环境变量

```bash
CLAWMEM_OPENROUTER_API_KEY=sk-or-v1-xxxxx  # OpenRouter API key
```

## Cron 设置

```bash
crontab -e
# 加一行：
0 0 * * * /mnt/c/Users/dddog/clawmem/scripts/daily-summarize.sh >> /mnt/c/Users/dddog/clawmem/logs/cron-summarize.log 2>&1
```
