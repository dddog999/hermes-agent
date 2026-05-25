# ClawMem L2 Pipeline

> Absorbed from `clawmem-l2-pipeline` during consolidation.

---


# ClawMem L2 Pipeline 指南

## 架构

```
Hermes/CodeBuddy 原生历史
         ↓
   export-wiki.ts
         ↓
wiki/raw/history/{source}/YYYY-MM-DD.md   ← L2 逐日归档（不可变源）
         ↓
   summarize (clawmem CLI)
         ↓
~/.clawmem/memories/*.md                  ← L0/L1 记忆输出
```

## 输出路径（必须严格遵循）

```
hermes-sync/wiki/                          ← export-wiki 输出根目录
├── raw/history/
│   ├── dddog-hermes/YYYY-MM-DD.md
│   ├── dddog-codebuddy-ide/YYYY-MM-DD.md
│   └── dddog-codebuddy-cli/YYYY-MM-DD.md
├── memory/<topic>.md
└── .export-wiki-state.json              ← export-wiki 增量状态（wiki/ 下）
```

## 增量状态文件

| 文件 | 位置 | 含义 |
|------|------|------|
| `historyState.json` | `wiki/` | export-wiki 增量去重（哪些源文件已导出） |
| `memoryState.json` | `~/.clawmem/` | summarize 增量跟踪（哪些 L2 文件已提取） |

## State 文件命名约定

| 旧名称（废弃） | 新名称 | 位置 |
|---|---|---|
| `.export-wiki-state.json` | `historyState.json` | wiki/ |
| `processedFiles.jsonl` | `memoryState.json` | ~/.clawmem/ |
| `ProcessedFilesLog` 类 | `MemoryStateLog` | src/ |
| `ProcessedFileRecord` 类型 | `MemoryStateRecord` | src/ |

## daily-summarize.sh 正确配置

```bash
WIKI_BASE="${CLAWMEM_WIKI_BASE:-/mnt/c/Users/dddog/Nutstore/1/myNutstore/hermes-sync/wiki}"
node dist/cli/index.js summarize \
  "$WIKI_BASE/raw/history/dddog-hermes" \
  "$WIKI_BASE/raw/history/dddog-codebuddy-ide" \
  "$WIKI_BASE/raw/history/dddog-codebuddy-cli" \
  --model inclusionai/ling-2.6-1t:free \
  --api-type openrouter
```

## 已知 Bug：Pattern 导致 0 文件处理

**症状**：`summarize --dry-run <wiki_dir>` → `Found 1 file(s)`（processedFiles.jsonl 被扫入），0 个 L2 文件被处理。

**根因**：`src/cli/index.ts` 中 PHASE4_PATTERN 多余的 `[-_]` 要求：
```typescript
// ❌ 错误：要求日期后必须有 - 或 _
// 实际 wiki 文件：2026-04-11.md（直接 .md，无分隔符）
const PHASE4_PATTERN = /^\d{4}-\d{2}-\d{2}[-_].*\.md$/;

// ✅ 修复：
const PHASE4_PATTERN = /^\d{4}-\d{2}-\d{2}.*\.md$/;
```

**调试**：
```bash
node -e "const p = /^\d{4}-\d{2}-\d{2}.*\.md\$/; console.log(p.test('2026-04-11.md'))"
```

## 不要创建中间数据目录

**错误示范**：`~/.clawmem/l2-history-flat/` —— 在 export-wiki 已经输出到 wiki/ 的情况下，又创建了新的中间目录，导致路径不统一。

如果数据已经存在于某个路径，应该修复工具让工具读那个路径，而不是创建新目录。

**检查清单**：创建新数据目录前，先确认"这个数据是否已存在于其他地方？"。

## ⚠️ CodeBuddy CLI 数据源：有两个不同的数据位置

CodeBuddy CLI 的历史数据分散在两个地方，**不要混淆**：

| 数据 | 路径 | 内容 | 格式 |
|------|------|------|------|
| 终端命令日志 | `~/.codebuddy/history.jsonl` | 纯终端命令（无 AI 对话） | `{display, timestamp}`，无 role |
| **真实 AI 对话** | `~/.codebuddy/projects/{project}/*.jsonl` | 完整问答，包含工具调用 | `{type:"message", role:"user\|assistant", content:[{type:"input_text\|output_text", text}], ...}` |

### 识别数据空洞问题

如果 `dddog-codebuddy-cli` 导出的文件只有 ~1KB，而 `~/.codebuddy/projects/` 下对应日期的 JSONL 文件很大（几十 KB），说明：
- `scanCodebuddyCli()` 读的是 `history.jsonl`（终端命令，文本少）
- **应该读** `projects/` 下的文件（有真实对话，内容丰富）

### export-wiki.ts 的解析依赖

`extractTextFromBlocks()` 必须识别 `input_text` 块类型：
```typescript
// ✅ 正确：识别 input_text + output_text + text
if ((b.type === 'text' || b.type === 'output_text' || b.type === 'input_text') && typeof b.text === 'string')

// ❌ 错误：缺少 input_text → 用户消息全变成 [无文本内容]
if ((b.type === 'text' || b.type === 'output_text') && typeof b.text === 'string')
```

### 验证命令

```bash
# 查看 projects 下有多少 JSONL 文件及其大小
find ~/.codebuddy/projects -name "*.jsonl" -exec ls -la {} \; | sort -k5 -n

# 对比导出结果大小（应接近源文件）
ls -la hermes-sync/wiki/raw/history/dddog-codebuddy-cli/
```

### 修复历史（2026-05-02）

- 新增 `scanCodebuddyCliProjects()` 扫描 `projects/` 目录
- `scanSessions('codebuddy_cli')` 合并两者结果
- 效果：CodeBuddy CLI session 数 3→13，导出大小 1KB→23KB（最大文件）

---

## ⚠️ TypeScript 编译错误调试方法（WSL CRLF 陷阱）

### 关键原则：先确认错误是预存的还是本地引入的

```bash
# 1. 先看 HEAD 是否有这个错误（用 stash 暂存本地修改）
git stash && npx tsc --noEmit 2>&1 | grep "src/cli"

# 2. 如果 HEAD 无错误 → 错误在本地修改版本中
git stash pop

# 3. 如果 HEAD 有错误 → 错误是预存的，勿动
```

### WSL CRLF→LF 陷阱（已导致错误排查误判）

WSL Git Bash 或某些 Git 配置会自动将 CRLF 转 LF。这个转换**会重写文件内容**，导致：
- `git diff` 显示数千行差异（实际上是内容重写，不是逐行编辑）
- 同一个文件 HEAD 和工作目录内容结构不同
- 误以为代码"有问题"需要修复

**诊断方法**：
```bash
# 检查 HEAD 行数 vs 工作目录行数
git show HEAD:src/cli/index.ts | wc -l
wc -l src/cli/index.ts

# 如果差异巨大（几百行），说明内容被重写而非简单编辑
# HEAD 1782 行，工作目录 1700+ 行 → 确认是重写

# 检查 CRLF
cat -A src/cli/index.ts | head -3
# ^M$ = CRLF，正常； $ 结尾 = LF，已被转换
```

**正确修复方式**：
```bash
# 恢复 HEAD 版本（干净内容）
git checkout HEAD -- src/cli/index.ts

# 验证恢复后无错误
npx tsc --noEmit 2>&1 | grep "src/cli"
# （无输出 = 成功）
```

### 隔离编译单个文件

```bash
# 只检查 src/cli/index.ts（不编译其他文件）
npx tsc --noEmit src/cli/index.ts
# 注意：需要 tsconfig.json 支撑，否则报 import.meta 等错误
```

### 快速判断是否需要修复

| 现象 | 含义 | 操作 |
|------|------|------|
| HEAD 无错误，本地版本有 | 本地修改引入 bug | 回退 `git checkout HEAD -- path` |
| HEAD 有错误，所有人都有 | 预存问题 | 单独开任务修复 |
| 测试文件有错误，src 无 | 测试与新 TS 5.9 不兼容 | 单独开任务修复 |
