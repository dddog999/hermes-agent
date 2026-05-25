---
name: clawmem-search-fix
description: clawmem search 命令修复记录——Commander.js 选项陷阱、记忆路径不一致、frontmatter regex 格式
---

# clawmem search 命令修复（2026-05-03）

## 问题 1：Commander.js `--no-vector` 选项陷阱

**现象**：`clawmem search "关键词" --no-vector` 依然尝试连接 Ollama，向量搜索超时后才 fallback，每次搜索都卡 10+ 秒。

**根因**：Commander.js 的 `--no-vector` 设置 `options.vector = false`，不是 `options.noVector`。

**修复**：
```typescript
// ❌ 错误
if (options.noVector) { skip_vector_search(); }

// ✅ 正确
if (options.vector === false) { skip_vector_search(); }

// 同步修正 type definition
.action(async (options: { vector?: boolean }) => { ... });
```

## 问题 2：add 和 search 路径不一致

**历史**：
- `add` 命令曾写入 `~/.clawmem/memories/dddog-hermes/`（被 `CLAWMEM_MEMORY_DIR` 环境变量覆盖）
- `search` 默认也读 `~/.clawmem/memories/dddog-hermes/`
- 用户需求：`add` 和 `search` 都应该使用 `wiki/raw/memory/dddog-hermes/`

**修复**：
1. `DEFAULT_MEMORY_DIR` 硬编码 wiki 路径，移除 `CLAWMEM_MEMORY_DIR` 覆盖
2. `search` 的 `memDir = join(options.dir || DEFAULT_MEMORY_DIR, 'dddog-hermes')`
3. `add` 硬编码 wiki 绝对路径写入

## 问题 3：frontmatter regex 格式不匹配

**根因**：`summarize/storage.ts` 的 `saveMemory` 用 `yaml.stringify` 生成单引号格式 frontmatter：
```yaml
'l0':
  'key': 'workflow/multi-agent-coordination'
```

但 search 文件扫描的 regex 用的是双引号格式：
```typescript
/^l0:\s*\n\s*key:\s*(.+)$/m   // ❌ 不匹配单引号
/^'l0':\s*\n\s+'key':\s*'(.+)'$/m   // ✅ 匹配单引号
```

**修复**：所有 frontmatter regex 改为匹配单引号格式。

## 验证命令

```bash
npm run build
clawmem search "飞书消息推送" --no-vector   # 应立即返回，不连 Ollama
clawmem search "关键词" --no-vector --json  # 输出 JSON 格式
clawmem add "测试记忆" --keywords "test"    # 写入 wiki/raw/memory/dddog-hermes/
```
