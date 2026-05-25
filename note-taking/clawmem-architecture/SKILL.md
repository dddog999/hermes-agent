---
name: clawmem-architecture
description: ClawMem 存储架构与数据流 - 两套存储分离、四个数据来源、核心 bug 修复记录
---

# ClawMem 架构与存储分离 (2026-05-03)

## 两套存储，两个命令

| 命令 | 存储层 | 路径 | 用途 |
|------|--------|------|------|
| `add` | JSON Store | `~/.clawmem/memories/*.json` | CLI 直接写入 |
| `search` | Phase5Index | `wiki/raw/memory/*.md` | 向量+BM25混合搜索 |
| `list` | JSON Store | `~/.clawmem/memories/*.json` | 遍历 JSON 文件 |
| `run-pipeline` | L1 markdown | `wiki/raw/memory/*.md` | 批量生成 L1 摘要 |

**结论**：`add` 的内容 `search` 搜不到，需要 pipeline 同步。

## 四个数据来源

TypeScript 迁移后 `export-wiki.ts` 统一处理：

| source key | 数据来源 | 存储目录 |
|------------|---------|---------|
| `hermes` | `~/.hermes/sessions/*.jsonl` | `dddog-hermes/` |
| `codebuddy_ide` | Windows CodeBuddy IDE database | `dddog-codebuddy-ide/` |
| `codebuddy_cli_wsl` | `~/.codebuddy/projects/*.jsonl` | `dddog-codebuddy-cli-wsl/` |
| `codebuddy_cli_win` | `/mnt/c/Users/dddog/.codebuddy/*.jsonl` | `dddog-codebuddy-cli-win/` |

## 核心 Bug 修复 (export-wiki.ts)

1. **Bug 1** (`c68c320`)：assistant content 为字符串时 AI 回复丢失  
   修复：`typeof content === 'string'` fallback in `buildTurnsFromMessages()`

2. **Bug 2** (`e76bef0`)：CLI Caveat HTML 消息创建垃圾 Turn  
   修复：过滤 `<system-reminder>` HTML-only 用户内容

## 验收结果 (68 个文件)

- Hermes: 19 ✅ | CodeBuddy IDE: 29 ✅ | CLI WSL: 4 ✅ | CLI Win: 16 ✅
- "问题文件"全部是数据本身限制，非导出 bug

## 规划文件规范

### 三个核心文件（项目根目录）

| 文件 | 用途 |
|------|------|
| `task_plan.md` | 任务计划 + **验收条件（必须明确）** + 当前状态 |
| `progress.md` | 排查过程详细记录 |
| `findings.md` | 决策、关键发现 |

### task_plan.md 必须包含

```markdown
## Goal
[具体目标]

## Acceptance Criteria
✅ [验收条件，可执行验证的命令]
例：npx tsc --noEmit exit 0

## Status
[当前状态]
```

**重要**：用户要求"有验收条件就执行直到满足"。规划文档中的验收条件必须：
1. 是可执行的命令
2. 在每次修复后立即验证
3. 满足后标记 ✅

### 不要删除文件，用 trash

```bash
# 不要 rm，Windows 权限问题
trash path/to/file
```

---

## dist/ 编译验证

```bash
npm run build  # exit 0
clawmem add "test" --tags "test"  # Memory added ✅
clawmem search "test"  # No memories found（存储分离） ✅
```

## 验证命令

```bash
# 验证 add 写入 JSON
clawmem list

# 审核导出格式（44/67 良好）
clawmem audit:export

# 审核并修复
clawmem audit:export --fix

# 全量重导
npm run export-wiki -- --force
```
