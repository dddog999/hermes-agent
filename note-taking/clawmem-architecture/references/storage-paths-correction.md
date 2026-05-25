# 存储路径修正 (2026-05-03)

## 原始错误说法
"wiki/raw/memory/ 是 OV 的记忆存储"

## 正确理解

clawmem 和 OV 使用**不同的存储路径**，用途不同：

| 路径 | 格式 | 来源 | 用途 |
|------|------|------|------|
| `wiki/raw/history/memories/` | `.json` | clawmem `add` 命令 | 记忆原始数据（经 JsonStore） |
| `wiki/raw/memory/dddog-hermes/` | `.md` | OV 独立管理 / clawmem export-wiki | 向量搜索入口 |
| `~/.clawmem/memories/` | `.md` | **已废弃** | 当前 CLI 不使用 |

## clawmem add 数据流
```
clawmem add "内容"
  → core.addMemory()
  → JsonStore (dataDir = syncDir)
  → writeFile(syncDir/memories/{uuid}.json)
```
syncDir 来自 `~/.clawmem/config.json` 的 `syncDir` 字段。

## export-wiki 数据流
```
clawmem export-wiki
  → export-wiki.ts
  → writeFile(DEFAULT_MEMORY_DIR/...)
  → DEFAULT_MEMORY_DIR = wiki/raw/memory/
```
