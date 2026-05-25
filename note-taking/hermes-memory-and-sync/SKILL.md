---
name: hermes-memory-and-sync
description: Hermes Agent 记忆系统架构、文件同步与多设备工作流 — 涵盖原生记忆、ClawMem、Wiki 知识库、Git 同步
triggers:
  - "记忆文件在哪"
  - "user.md 和 memory.md"
  - "hermes 记忆同步到 Windows"
  - "clawmem 存储路径"
  - "wiki 同步"
  - "rebase vs merge"
  - "fork 上游同步"
---

# Hermes 记忆系统与多设备同步

## 1. 原生记忆文件 (Hermes Core)

Hermes Agent 有**内核原生**的持久记忆机制，与 OpenViking/ClawMem 无关。

| 文件 | 路径 | 容量 | 用途 |
|------|------|------|------|
| MEMORY.md | `~/.hermes/memories/MEMORY.md` | 2,200 chars (~800 tokens) | Agent 个人笔记：环境事实、约定、学习内容 |
| USER.md | `~/.hermes/memories/USER.md` | 1,375 chars (~500 tokens) | 用户画像：偏好、沟通风格、期望 |

- 会话启动时从磁盘加载，以**冻结快照**注入系统提示词
- 会话期间不改变（保持 LLM 前缀缓存性能）
- Agent 通过内置 `memory` 工具管理（add/replace/remove）
- 变更立即持久化到磁盘，下个会话才生效

官方文档: https://hermes-agent.nousresearch.com/docs/user-guide/features/memory

## 2. ClawMem 记忆系统 (当前使用)

| 路径 | 作用 | 同步 |
|------|------|------|
| `~/.clawmem/memories/*.md` | L0/L1 提取记忆 | ✅ 坚果云同步 |
| `~/.clawmem/l2-history/` | L2 原始历史（按设备分: hermes/cli/ide） | ✅ 坚果云同步 |
| `~/.clawmem/clawmem_embeddings.db` | 向量索引 (Jina v4) | ❌ 本地独立 |
| `~/.clawmem/dedup_index.db` | 去重索引 | ❌ 本地 |
| `~/.clawmem/phase5_index.db` | Phase5 索引 | ❌ 本地 |
| `~/.clawmem/config.json` | ClawMem 配置 | ✅ 坚果云同步 |

- 通过 MCP hooks 自动管理（SessionStart 注入、SessionStop 存储）
- 嵌入方案：Jina Embeddings v4（不用 Ollama）
- 支持 `--sync-dir` + `--embedding-dir` 分离存储

## 3. Wiki 知识库 (坚果云同步 ✅)

| 目录 | 内容 |
|------|------|
| `wiki/raw/memory/` | L2 原始记忆 (50+ 条) |
| `wiki/memory/` | 导出的 L2 记忆 |
| `wiki/entities/` | 知识实体页面 |
| `wiki/concepts/` | 概念文档 |
| `wiki/raw/articles/` | 原始文章来源 |

## 4. 同步到 Windows 策略

| 文件 | 同步方式 |
|------|---------|
| `wiki/` 全目录 | 坚果云自动同步 ✅ |
| `.clawmem/memories/` + `config.json` | 放入坚果云同步目录 |
| `.clawmem/embeddings.db` | **不同步**，每台设备独立计算 |
| `~/.hermes/memories/` | 需单独同步（重要但易遗漏） |
| `~/.hermes/config.yaml` + `.env` | 手工或脚本同步 |

## 5. Git Fork 同步工作流

### 推荐策略: merge（非 rebase）

对**已推送**的协作分支，`git merge --no-edit` 比 rebase 更安全，不改写历史。

### 2026-05-09 实际操作记录

```bash
# 1. 基于 upstream/main 创建临时分支
git checkout -b temp-push-1778180495 upstream/main

# 2. merge 你的改动到临时分支（验证保留）
git merge feat/windows-native

# 3. 回到 feat 分支，merge 临时分支
git checkout feat/windows-native
git merge temp-push-1778180495 --no-edit

# 4. 冲突解决（run_agent.py:13283）
#    HEAD: base_delay=10.0, max_delay=60.0 ✅
#    upstream: base_delay=15.0, max_delay=90.0
#    决策: 保留本地值（经过实际验证）

# 5. 推送
git branch -D temp-push-1778180495
git push origin feat/windows-native
```

### 教训
- 已推送分支不用 rebase（改写历史导致协作问题）
- 冲突时优先保留经过实测验证的数值
- Push 被拒先检查 remote URL（fork vs 上游）

## 6. 记忆备份到云盘

### 用途

将 `~/.hermes/memories/MEMORY.md` 和 `USER.md` 定期备份到坚果云（或其它云盘），实现：
- 跨设备恢复记忆（新设备开荒时直接 copy 备份）
- 历史追溯（按日期命名的增量备份）
- 与其他 AI 助手共享记忆快照

### 备份脚本 (`~/.hermes/scripts/backup-memory.cjs`)

```javascript
const fs = require('fs');
const path = require('path');
const today = new Date().toISOString().slice(0, 10).replace(/-/g, '');
const hostTag = 'wooking-win';  // 改为主机标识

const hermesMemDir = path.join(process.env.USERPROFILE, '.hermes', 'memories');
const nutstoreBackupDir = path.join(process.env.USERPROFILE,
  'Nutstore', '1', 'myNutstore', 'hermes-sync', 'hermes-backups');

fs.mkdirSync(nutstoreBackupDir, { recursive: true });

['MEMORY.md', 'USER.md'].forEach(f => {
  const src = path.join(hermesMemDir, f);
  if (fs.existsSync(src)) {
    const type = f.replace('.md', '');
    const dst = path.join(nutstoreBackupDir, `${hostTag}_${type}_${today}.md`);
    fs.copyFileSync(src, dst);
  }
});

// 清理 90 天前的旧备份
const maxAge = 90 * 24 * 60 * 60 * 1000;
fs.readdirSync(nutstoreBackupDir).forEach(f => {
  if (f.startsWith(hostTag) && f.endsWith('.md')) {
    if (Date.now() - fs.statSync(path.join(nutstoreBackupDir, f)).mtimeMs > maxAge)
      fs.unlinkSync(path.join(nutstoreBackupDir, f));
  }
});
```

### 定时任务

在 Hermes 中创建 cron job：
- 调度：每日 9:00
- 脚本：`backup-memory.cjs`（相对于 `~/.hermes/scripts/`）
- 命名：`wooking-win_MEMORY_20260509.md` / `wooking-win_USER_20260509.md`

### 命名约定

多设备共存时用**主机前缀**区分，互不串扰：

| 前缀 | 环境 | 示例 |
|------|------|------|
| `wooking_` | WSL (旧) | `wooking_MEMORY_20260510.md` |
| `wooking-win_` | Windows 原生 (当前) | `wooking-win_MEMORY_20260510.md` |
| `desktop-4jfhq88_` | 另一台机器 | `desktop-4jfhq88_MEMORY_20260510.md` |

## 7. SQLite 数据库不能共享到文件同步服务

SQLite WAL 模式的 `.db` + `.db-wal` + `.db-shm` 三件套**绝对不能**放在坚果云/Dropbox 等文件同步服务中。

详见 `references/sqlite-sync-risks.md`。

## 8. USER.md 跨机器共享（符号链接方案）

HERMES 的内置记忆分两个文件：USER.md 和 MEMORY.md。**MEMORY.md 不建议跨机共享**（含主机专属配置），但 **USER.md 可以**——用户偏好跨机器通用。

### 方案

将本机 `~/.hermes/memories/USER.md` 以符号链接指向坚果云中的共享副本：

```cmd
:: 1. 先合并内容（确保坚果云副本包含所有机器的偏好）
:: 2. 删除 stale 的 .lock 文件
rm <cloud-dir>/memories/USER.md.lock

:: 3. 备份本机原文件
move %USERPROFILE%\\.hermes\\memories\\USER.md %USERPROFILE%\\.hermes\\memories\\USER.md.bak

:: 4. 建立文件级符号链接（mklink 不加 /D，因为这是文件不是目录）
mklink %USERPROFILE%\\.hermes\\memories\\USER.md <cloud-dir>\\memories\\USER.md
```

### 效果

- `memory(action="add", target="user")` 写入的就是坚果云中的共享文件
- 多台机器的 Hermes 共享同一份用户偏好
- 一台机器上更新了偏好，所有机器下个会话生效

### 注意事项

| 事项 | 说明 |
|------|------|
| **写冲突** | 两台机器同时写 USER.md，后写的覆盖先写的（不是三路合并） |

### 备选方案：直接写 SQLite（脚本自动化）

符号链接方案依赖文件系统行为。另一种方案是用 `scripts/load-user-memory.py` 直接读写 SQLite：

```bash
# 手动同步
python ~/.hermes/scripts/load-user-memory.py

# Cron 自动同步（每30分钟）
# 已创建 cron job: sync-USER-md-to-memory (id: d81c0d559662)

# Gateway 启动时自动同步
# 在 Hermes_Gateway.cmd 中加入 python 调用
```

脚本会：读取 USER.md → 解析 § 分段 → 写入 `memory_entries` 表（key 相同则覆盖）。Nexus 坚果云备份目录需包含 `memories/USER.md`。

**scripts/load-user-memory.py** 在 `skills/note-taking/hermes-memory-and-sync/scripts/load-user-memory.py`
| **MEMORY.md 不能共享** | 含主机专属路径、凭证、项目上下文等 |
| **.lock 文件** | 各机器的 Hermes 会在同目录创建 `.lock`，需定期清理 stale lock |
| **mklink vs mklink /D** | 文件用 `mklink`，目录用 `mklink /D` |

## 8. 常见误区

- "MEMORY.md/USER.md 是 OpenViking 的" -> 是 Hermes 原生功能
- "ClawMem 取代原生记忆" -> ClawMem 是额外的记忆增强，原生记忆仍工作
- "所有 .clawmem 数据都要同步" -> 向量库（embeddings.db）应本地独立
- "记忆会话中改了就行" -> 下个会话才生效，当前会话读到的是快照
- "Windows 和 WSL 备份用同样前缀就行" -> 同一主机名时要加 `-win` 后缀区分