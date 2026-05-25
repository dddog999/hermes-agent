# Clawmem Topic Based Extraction
> Absorbed from archived skill `clawmem-topic-based-extraction` during consolidation pass (2026-05-22).

---


# ClawMem 话题驱动提取流程

## 背景

ClawMem L2 → L0/L1 提取流程的重大演进：从事先分块提取改为**话题分割→向量搜索→合并**。

### 旧流程（已废弃）

```
L2文件 → splitMessagesIntoChunks(50条) → formatMessagesAsText → splitContent(1500字符)
→ 每个chunk独立LLM提取 → 合并结果
```

问题：
- 188条消息的JSONL被切成64+个chunk（因为`splitContent`依赖Markdown的`## Turn`标记，JSONL格式化后没有→整块送入→二次分块）
- 消息大小差异大（3字节~21KB/条），按条数分块完全不考虑内容量
- 同一话题跨chunk导致重复提取或遗漏
- 跨文件同一话题无法识别

### 新流程（话题驱动）

```
L2(jsonl/md)
  → 格式化文本（formatMessagesAsText 或 formatMessagesAsJson）
  → LLM话题分割（一次调用，输出: [{topic_name, message_indices:[...]}])
  → 每个topic：
       向量搜索已有L0/L1（minimax-01d/M3的embedding）
       → 命中？LLM merge（识别术语差异）: 直接提取新L0/L1
  → 存入/更新向量库
```

优势：
- 话题=语义单元，可能是5条消息也可能是80条
- 跨文件话题天然通过向量相似度识别（如"ClawMem提取逻辑"在2月、3月都有）
- 相似语义不同术语→向量召回+LLM merge处理
- LLM调用次数 = topic数，而不是chunk数

## 话题分割 LLM 输出格式

```json
{
  "topics": [
    {
      "name": "技术/互联网",
      "key": "technical/internet-basics",
      "message_indices": [0, 1, 2, 5, 8],
      "summary": "用户询问了TCP/IP协议和DNS解析的基本原理"
    },
    {
      "name": "AI模型",
      "key": "technical/ai-models", 
      "message_indices": [3, 4, 6, 7, 9],
      "summary": "讨论了GPT和Claude模型的区别"
    }
  ]
}
```

## 话题命名规范

LLM 生成 topic key，格式：`{category}/{slug}`
- category: `project` | `preference` | `technical` | `workflow`
- slug: 语义化的英文/拼音混合slug

## 已有向量库的作用

ClawMem 已有 L0/L1 的向量库（minimax-01d/M3 embedding），直接复用：
- 不需要额外的 topic.md 索引层
- 向量相似度召回相似话题，召回阈值内的由 LLM 处理术语差异
- 命中 = merge，未命中 = 新建

## 相关文件

- `src/summarize/extractor.mjs` - 提取逻辑（需重构）
- `src/summarize/jsonl-adapter.ts` - JSONL解析和格式化（已有 `formatMessagesAsJson` 未使用）
- `src/summarize/storage.ts` - L0/L1存储和向量库接口
- `src/summarize/merger.mjs` - merge逻辑
