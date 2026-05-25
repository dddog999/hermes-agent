# Clawmem Wiki Export
> Absorbed from archived skill `clawmem-wiki-export` during consolidation pass (2026-05-22).

---


# ClawMem Wiki 导出管道

将 Hermes session JSONL 和 CodeBuddyMemory L0/L1 文件导出为 LLM Wiki 格式。

## 输出结构

```
~/wiki/
├── index.md              # 自动生成的总索引
├── raw/clawmem/          # Tier 1: L2 逐日归档 (YYYY-MM-DD.md)
└── memory/               # Tier 2: L0/L1 话题聚类 (<topic>.md)
```

## 脚本

| 脚本 | 作用 | API 依赖 |
|------|------|----------|
| `scripts/export-to-wiki.mjs` | L2 JSONL → 逐日 raw/ | 无 |
| `scripts/export-to-wiki-topic.mjs` | L0/L1 → 向量聚类 → memory/ | Jina API |
| `scripts/daily-export-wiki.sh` | 串联 Tier 1+2 | Jina API |

### 用法

```bash
cd /mnt/c/Users/dddog/AppData/Roaming/npm/node_modules/clawmem

# Tier 1 单独运行
node scripts/export-to-wiki.mjs [--force] [--dry-run] [--date 2026-04-27]

# Tier 2 单独运行
node scripts/export-to-wiki-topic.mjs [--threshold 0.75] [--dry-run]

# 自动化 wrapper
bash scripts/daily-export-wiki.sh
```

### Tier 1 策略

| JSONL行数 | 处理 |
|-----------|------|
| <50 | 关键词亲和聚类后合并入当天文件 |
| 50-200 | 独立分节 |
| >200 | 完整保留 + 关键词标签 |

增量模式：基于 mtime+size 的状态追踪 (`.export-to-wiki-state.json`)

### Tier 2 流程

1. 扫描 CodeBuddyMemory/*.md → 解析单引号 frontmatter
2. Jina v4 embedding (2048维) → 余弦相似度贪心聚类
3. 生成 topic page + 自动刷新 index.md

## 自动化

- **系统 crontab**: `0 2 * * * daily-export-wiki.sh`
- **Hermes cronjob**: `67f011f2d479` (双保险)
- **日志**: `~/wiki/export.log`

## 关键陷阱

### Jina API 端点
- ❌ Gitee AI (`ai.gitee.com/v1/embeddings`) — 401/400
- ✅ Jina 官方 (`api.jina.ai/v1/embeddings`) — 可用
- Key 格式: `jina_1...` 来自 ~/.hermes/.env

### WSL 路径
- Windows 路径 `C:\Users\...` 在 WSL 下需译为 `/mnt/c/Users/...`
- 脚本已有 `os.platform()` 自动检测

### Frontmatter 格式
- CodeBuddyMemory 使用单引号格式: `'key': 'value'`
- 不能用标准 YAML 解析器，需自定义解析

### 空 L1 Heading → untitled
- 部分 memory 文件 L1 heading 为空，聚类后会生成 untitled.md
- 修复：fallback 用第一条 L0 description 截断 60 字符做标题
- 已在 `export-to-wiki-topic.mjs` 的 `clusterBySimilarity()` 中处理

### Git Push 认证
- Gitee remote 用 HTTPS，需 token 认证
- WSL 下 credential.helper 可能不生效，需手动设置
- Token 位置: `/mnt/c/Users/dddog/.gitee_token`

## 相关文件

- 项目根: `/mnt/c/Users/dddog/AppData/Roaming/npm/node_modules/clawmem/`
- 输入: `~/.hermes/sessions/*.jsonl`, `MemVault/CodeBuddyMemory/*.md`
- 输出: `~/wiki/`
