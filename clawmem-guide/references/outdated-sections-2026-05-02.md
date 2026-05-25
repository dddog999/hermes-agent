# ClawMem Guide - 需要更新的过时内容 (2026-05-02)

以下 sections 在 SKILL.md 中存在但已过时，需要 agent 在下次编辑 skill 时手动修复。

## 1. 向量搜索功能 section（完全过时）

**位置**: SKILL.md "向量搜索功能" 章节
**问题**: 仍写 Ollama，实际上 embedding 已迁移到 Gitee AI
**正确内容**:
```markdown
### Embedding 引擎（Gitee AI）

默认使用 Gitee AI 线上 API，无需本地 Ollama：

```bash
# 使用 Gitee AI jina-v4 embedding（默认）
# API: https://ai.gitee.com/v1/embeddings
# 模型: jina-embeddings-v4（2048维）
# 注意：需购买"全模型资源包"才可调用（免费额度也需资源包）
```

**Ollama 仅作备选**（已停用主力地位）：
```bash
clawmem --ollama-url http://localhost:11434 --ollama-model qwen3-embedding:0.6b add "记忆内容"
```
```

## 2. Phase 5 碎片晋升章节（完全过时）

**位置**: SKILL.md "Phase 5: 碎片晋升与去重机制" 章节
**问题**: 整章写 Ollama numpy embedding 方案，当前代码已用 Gitee AI + SQLite
**正确方案**: 见 clawmem/.planning/ROADMAP.md Phase 5 架构决策

关键变更：
- embedding 引擎：Gitee AI jina-v4（不再是 Ollama numpy）
- 存储：`src/summarize/storage.ts` 中 `DEFAULT_STORAGE_DIR`
- 向量索引：`~/.clawmem/phase5_index.db`（SQLite）

## 3. 输出路径 section（过时）

**位置**: SKILL.md "Wiki 输出目录" 和 "开发参考" 章节
**问题**: 路径写旧值，当前正确值：
- **根目录**: `hermes-sync/wiki/raw/`（坚果云）
- **Phase 4**: `history/{用户名-客户端}/`（原始对话）
- **Phase 5**: `memory/{用户名-客户端}/`（记忆提取）
- **源码**: `C:\Users\dddog\clawmem`（不再是 npm 全局安装路径）

## 4. Stop Hook 已停用

**问题**: SKILL.md 没有说明 Stop Hook 已停用
**当前方案**: `scripts/daily-summarize.sh` 每日定时执行（cron 未配置）

## 5. JSONL 提取架构 section（Jina endpoint 说明过时）

**位置**: SKILL.md "关键陷阱：Jina API Endpoint" 表格
**问题**: 说 "Gitee token 400"，但当前用的是 Gitee AI jina-v4，不是 jina 官方 key
**实际**: Gitee AI 作为 jina-v4 的代理 API，key 格式和官方不同

## 验证文档正确性的方法

始终交叉验证 SKILL.md 中的路径/配置：
```bash
# 验证 embedding 配置
grep -n "gitee\|DEFAULT_STORAGE" /mnt/c/Users/dddog/clawmem/src/summarize/storage.ts

# 验证输出路径
grep -n "output\|history\|memory" /mnt/c/Users/dddog/clawmem/scripts/export-history.mjs | head -5

# 验证 README 最新内容
grep -A2 "输出路径\|Embedding\|Phase 4\|Phase 5" /mnt/c/Users/dddog/clawmem/README.md
```
