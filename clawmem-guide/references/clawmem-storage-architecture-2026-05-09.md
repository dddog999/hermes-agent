# ClawMem 存储架构（L0/L1/L2 分布）— 2026-05-09 更新

## 两套存储体系

ClawMem 有**两套并行**的存储，理解它们的关系是关键：

### A. 本地存储：`~/.clawmem/`

| 目录/文件 | 作用 | 类型 | 是否需坚果云同步 |
|-----------|------|------|----------------|
| `l2-history/` | L2 原始历史，按设备分区：`hermes/`, `cli/`, `ide/` | 纯文本 | ✅ 关键 |
| `memories/` | 从 l2-history 提取的 L0/L1 记忆（JSON 格式） | 文本 | ✅ 关键 |
| `CodeBuddyMemory/` | VS Code / JetBrains 插件产生的 CodeBuddy 记忆 | 文本 | ❌ IDE 端各自独立 |
| `clawmem_embeddings.db` | 向量索引（Jina Embeddings v4） | 二进制 | ⚠️ 可重建但耗时 |
| `dedup_index.db` | 去重索引 | 二进制 | ⚠️ 可重建 |
| `phase5_index.db` | Phase 5 索引 | 二进制 | ⚠️ 可重建 |
| `config.json` | ClawMem 运行时配置 | JSON | ✅ |

### B. Wiki 存储：坚果云同步目录

| 路径 | 作用 |
|------|------|
| `wiki/raw/memory/*.md` | **核心记忆**：L2 格式 Markdown 扁平文件，50+ 条，带 frontmatter |
| `wiki/memory/*.md` | 导出的记忆（部分页面） |
| `wiki/entities/` | 实体页面（人/产品/项目） |
| `wiki/concepts/` | 概念页面 |
| `wiki/index.md` | 索引页 |

### 两者的关系

```
对话发生 → Hermes stop hook → 写入 l2-history/（本地）
                                      ↓
                              export-wiki.ts 提取
                                      ↓
                              写入 wiki/raw/memory/*.md（坚果云同步）
```

- **写入路径**：对话 → `l2-history` → `wiki/raw/memory/`
- **读取路径**：MCP tools 读 `wiki/raw/memory/*.md`（list/search/get）
- `memories/` 目录（JSON）是 `l2-history` 的提取中间产物
- `CodeBuddyMemory/` 是 CodeBuddy ACP 协议的独立产物，与 wiki 体系不互通

## 遗留文件（OpenViking，已弃用）

- `~/.hermes/memories.backup/USER.md` — 用户画像（已被 `dddog-profile` skill 取代）
- `~/.hermes/memories.backup/MEMORY.md` — 环境信息（已被 `hermes-windows-dev-workflow` skill 取代）
- 这些是 OpenViking 时代的备份，当前 `config.yaml` 中 `memory.provider` 已设为空

## 同步策略

- **wiki/** → 坚果云自动同步（WSL ↔ Windows）
- **~/.clawmem/** → 需要手动同步或添加到坚果云监控
  - 关键同步：`l2-history/`, `memories/`, `config.json`
  - 可重建：`*.db` 文件丢失后可从 wiki 重建
  - 无需同步：`CodeBuddyMemory/`（IDE 端独立）