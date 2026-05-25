---
name: clawmem-guide
description: ClawMem 个人记忆管理工具——基于 Markdown + frontmatter 的分层记忆系统，支持 MCP 工具和 Hermes hooks 集成
user-invocable: true
allowed-tools: "terminal, file, read_file, mcp_clawmem_*, viking_*"
---

# ClawMem 使用指南

## 现状（2026-05-04）

ClawMem 是 dddog 的个人记忆系统，基于 Markdown 文件 + frontmatter，存储在坚果云同步目录，通过 MCP 工具和 Hermes hooks 与 Agent 深度集成。

**核心数据**：85+ 条记忆（持续增长），位于 `wiki/raw/memory/*.md`

---

## 架构

### 存储

- **记忆位置**：`wiki/raw/memory/*.md`（扁平结构，无子目录）
- **格式**：Markdown + YAML frontmatter（L0 keywords、L1 摘要、L2 完整内容）
- **记忆来源**：Hermes hooks（stop/session-end）自动写入 + 手动 `clawmem add`

### MCP 工具（Hermes 内置）

| 工具 | 功能 |
|------|------|
| `clawmem_list` | 分页列出记忆（keyword 搜索） |
| `clawmem_search` | keyword + body 全文搜索 |
| `clawmem_get` | 读取单条记忆 L0/L1 |
| `clawmem_add` | 添加记忆 |
| `clawmem_forget` | 归档旧记忆（dry-run） |
| `clawmem_restore` | 恢复归档 |
| `clawmem_dedup` | 向量相似度去重合并 |

### Hooks（自动触发）— **需在 config.yaml 注册才生效**

| Hook 脚本 | Hermes 事件 | 行为 | 注册配置 |
|-----------|------------|------|---------|
| `session-start.mjs` | `on_session_start` | 注入相关记忆到上下文 | 见下方 |
| `session-end.mjs` | `on_session_end` | 导出对话摘要到 memory | 见下方 |
| `stop.mjs` | `on_session_finalize` | 生成 L0/L1 记忆并存储 | 见下方 |

> ⚠️ **事件名不兼容 CodeBuddy**：ClawMem hooks 早期基于 CodeBuddy ACP 设计，检查 `Stop` 等事件名。**Hermes 使用完全不同的事件名**（`on_session_start`/`on_session_end`/`on_session_finalize`），需要适配。详情见 `clawmem-dev-pitfalls`。

**config.yaml 注册模板**（添加 `hooks:` 块）—— Windows/WSL 路径二选一：

```yaml
# WSL 路径
hooks:
  on_session_start:
    - command: "node /mnt/c/Users/dddog/clawmem/dist/hooks/session-start.mjs"
      timeout: 60
  on_session_end:
    - command: "node /mnt/c/Users/dddog/clawmem/dist/hooks/session-end.mjs"
      timeout: 60
  on_session_finalize:
    - command: "node /mnt/c/Users/dddog/clawmem/dist/hooks/stop.mjs"
      timeout: 120
```

```yaml
# Windows 原生路径（正斜杠）
hooks:
  on_session_start:
    - command: "node C:/Users/dddog/clawmem/src/hooks/hermes-session-start.mjs"
      timeout: 30
  on_session_end:
    - command: "node C:/Users/dddog/clawmem/src/hooks/hermes-session-end.mjs"
      timeout: 60
  on_session_finalize:
    - command: "node C:/Users/dddog/clawmem/src/hooks/hermes-stop.mjs"
      timeout: 120
```

> 注意：Windows 原生下 hooks 路径使用 `src/hooks/`（源码），WSL 下用 `dist/hooks/`（编译后）。参见「Windows 原生设置」和 `clawmem-dev-pitfalls`。

---

## 环境变量

```bash
# ClawMem 从 config.json 读取路径，不再依赖环境变量驱动
# 以下环境变量仅作向后兼容（优先级高于 config.json）

# 记忆目录（覆盖 config）
CLAWMEM_MEMORY_DIR=C:/Users/dddog/Nutstore/1/myNutstore/hermes-sync/wiki/raw/memory

# 历史目录（session 导出）
CLAWMEM_HISTORY_DIR=C:/Users/dddog/Nutstore/1/myNutstore/hermes-sync/wiki/raw/history

# 向量 embedding（Jina API，用于去重）
JINA_API_KEY=P0YCD8QAR9UPUWS57IA9BYFAU5RQAL6O2GVSO51W
```

**配置位置**：`~/.hermes/.env`（Gateway 启动时加载）
**config.json 位置**：`~/.clawmem/config.json`（**不是** Nutstore 同步目录）

---

## 路径检测逻辑（machine-config 系统，2026-05-11）

所有硬编码路径已被移除，改用 `~/.clawmem/config.json` + `machine-config.ts` 统一管理。

### 核心模块

- **`src/config/machine-config.ts`** — TypeScript 源码，CLI/MCP 使用
- **`src/config/machine-config.mjs`** — ESM 运行时版本，hooks 使用

### config.json 结构（v2）

```json
{
  "_version": 2,
  "currentMachine": "wooking",
  "machines": {
    "wooking": {
      "hostname": "wooking",
      "platform": "windows",
      "isWSL": false,
      "home": "C:/Users/dddog",
      "nutstoreBase": "C:/Users/dddog/Nutstore/1/myNutstore",
      "clawmemRoot": "C:/Users/dddog/clawmem",
      "hermesSyncWiki": "C:/Users/dddog/Nutstore/1/myNutstore/hermes-sync/wiki/raw",
      "codebuddyIdeHistory": "C:/Users/dddog/AppData/Local/CodeBuddyExtension/Data/daa60d57-c0a9-49a9-ab84-a7fd0d1a4fb4/CodeBuddyIDE/daa60d57-c0a9-49a9-ab84-a7fd0d1a4fb4/history",
      "codebuddyCliHistory": "C:/Users/dddog/.codebuddy"
    }
  }
}
```

### 路径优先级

1. `CLAWMEM_ROOT` / `CLAWMEM_DIR` 环境变量（向后兼容，最高优先级）
2. `~/.clawmem/config.json` 中对应 machineId 的配置
3. 内置 wooking 默认值

### 解析 API

```typescript
import { getMachineProfile, resolvePath, getMachineId } from './config/machine-config.js';

resolvePath('hermesSyncWiki', 'memory')
// → C:/Users/dddog/Nutstore/1/myNutstore/hermes-sync/wiki/raw/memory

resolvePath('clawmemRoot')
// → C:/Users/dddog/clawmem

getMachineId() + '-hermes'
// → wooking-hermes（memory 子目录前缀）
```

### 各机器实际路径

| 用户 | 机器 | config.json machines key | nutstoreBase |
|------|------|------------------------|--------------|
| dddog | wooking (Windows) | `wooking` | `C:/Users/dddog/Nutstore/1/myNutstore` |

> **kangle 路径**：在 kangle 自己的 `~/.clawmem/config.json` 里配置，不在此仓库预置。

---

## 导出路径配置

路径统一由 `machine-config.ts` 的 `resolvePath()` 管理，不再有硬编码。

```typescript
resolvePath('hermesSyncWiki', 'memory')
// → C:/Users/dddog/Nutstore/1/myNutstore/hermes-sync/wiki/raw/memory

resolvePath('hermesSyncWiki', 'history')
// → C:/Users/dddog/Nutstore/1/myNutstore/hermes-sync/wiki/raw/history
```

L2 来源溯源（frontmatter）:
```
l2_sources: C:/Users/dddog/Nutstore/1/myNutstore/hermes-sync/wiki/raw/...
```

---

## CLI 命令

```bash
cd /mnt/c/Users/dddog/clawmem
npm run build  # 编译 TS

# 列出记忆
CLAWMEM_MEMORY_DIR="/mnt/c/Users/dddog/Nutstore/1/myNutstore/hermes-sync/wiki/raw/memory" \
  node dist/cli/index.js list

# 搜索
CLAWMEM_MEMORY_DIR="..." node dist/cli/index.js search "关键词"

# 获取单条
CLAWMEM_MEMORY_DIR="..." node dist/cli/index.js get <id>

# 添加
CLAWMEM_MEMORY_DIR="..." node dist/cli/index.js add "记忆内容" --keywords "kw1,kw2"
```

---

## 记忆格式

```markdown
---
id: xxxx-xxxx-xxxx
type: event
salience: 0.85
l2_sources:
  - manual:add
keywords:
  - clawmem
  - hook
created_at: 2026-05-04T12:00:00.000Z
access_count: 3
---

## L1 标题

L1 正文摘要（≤500字符）

## L0 Index
- `kw1`: description
- `kw2`: description
```

### type 类型

`event` | `fact` | `preference` | `skill` | `context`

---

## 常见问题

### Q: search 返回空但 list 有记忆

可能原因一：`CLAWMEM_MEMORY_DIR` 环境变量指向的目录不对。用 `clawmem_list` 确认读取的是哪个目录。

可能原因二：使用 `clawmem search`（CLI 命令）而非 MCP 工具。CLI 的 `search` 命令有 frontmatter 解析 bug（regex 不匹配实际 YAML 格式），永远返回 0 条。**使用 `clawmem_search`（MCP 工具）替代**，它通过 `storage.js` 的 `searchMemories()` 工作正常。

### Q: MCP 工具报错 `ClosedResourceError`
MCP server 未正常运行。重启 Gateway：
```bash
kill $(ps aux | grep "gateway run" | grep -v grep | awk '{print $2}')
cd ~/.hermes/hermes-agent && source venv/bin/activate && hermes gateway run --replace &
```

### Q: 新增记忆没有出现
Gateway 重启后 MCP server 会继承新 env。如仍不见，检查记忆文件是否写入正确目录。

---

## 开发

- **源码**：`/mnt/c/Users/dddog/clawmem/`
- **CLI**：`src/cli/index.ts` → `dist/cli/index.js`
- **MCP Server**：`src/mcp-server.ts` → `dist/mcp-server.js`
- **Hooks**：`src/hooks/*.mjs`（保持 .mjs，Hermes 只支持 node 调用 .mjs）
- **Storage**：`src/summarize/storage.ts`

### 编译
```bash
cd /mnt/c/Users/dddog/clawmem
npm run build  # TS → dist/
```

### 重启 MCP（开发时）
```bash
kill <mcp-server-pid>
cd /mnt/c/Users/dddog/clawmem
CLAWMEM_MEMORY_DIR="..." node dist/mcp-server.js &
```

---

## 调试方法论

**核心问题**：MCP 工具和 CLI `list` 命令走**不同存储**：
- `core.getAll()` → JsonStore → `dataDir/memories/*.json`
- `listMemories()` → `wiki/raw/memory/*.md`

**调试链路**：
```
Hermes Gateway
  └── MCP Server (dist/mcp-server.js)
        └── execCli() → spawn('node', ['dist/cli/index.js', ...])
              └── getCore() → ClawMemCore → JsonStore.getAll()
                    └── 读 JSON: dataDir/memories/*.json
```

**关键调试命令**：
```bash
# MCP server 重启（gateway 子进程，必须重启 gateway）：
kill $(ps aux | grep 'gateway run' | grep -v grep | awk '{print $2}')
cd ~/.hermes/hermes-agent && source venv/bin/activate && hermes gateway run --replace &

# 绕过 CLI，直接测 storage.js：
cd /mnt/c/Users/dddog/clawmem
CLAWMEM_MEMORY_DIR="..." node -e "
const { listMemories } = require('./dist/summarize/storage.js');
listMemories().then(m => console.log('count:', m.length));
"
```

**常见坑**：
| 症状 | 原因 |
|------|------|
| `list` 返回 0 但文件存在 | 读 JSON store 而非 markdown |
| MCP `ClosedResourceError` | MCP server 挂了，重启 gateway |
| search 空但 list 有 | `CLAWMEM_MEMORY_DIR` 路径不一致 |
| CLI `search` 永远返回 0 | CLI fallback regex 不匹配 YAML frontmatter；改用 MCP 工具 `clawmem_search` |

---

## 相关 Skills

### 存档参考 (archived siblings → reference files)

文件全部位于 `references/` 目录：

| 文件 | 主题 |
|------|------|
| `references/clawmem-l2-pipeline.md` | L2 Pipeline：增量状态、session DB、TS 调试 |
| `references/clawmem-storage-architecture-2026-05-09.md` | L0/L1/L2 三层层分布与 frontmatter 设计 |
| `references/clawmem-hooks-architecture.md` | Hooks 双平台架构 (Hermes/CodeBuddy) |
| `references/clawmem-hermes-hooks-status.md` | Hermes Hooks 状态快照 |
| `references/clawmem-search-fix.md` | cli/list 修复：frontmatter parsing bug |
| `references/clawmem-esm-cli-fix-2026-05-08.md` | ESM require() 修复 |
| `references/clawmem-ts-debugging.md` | TypeScript 5.9 调试方法论 |
| `references/outdated-sections-2026-05-02.md` | 过时章节清单 |
| `references/clawmem-jsonl-extraction.md` | JSONL 直读提取架构 |
| `references/clawmem-topic-based-extraction.md` | 话题驱动 L2→L0/L1 提取流程 |
| `references/clawmem-usage-ref.md` | ClawMem 使用操作指南 |
| `references/clawmem-wiki-export.md` | Wiki 导出管道（L2 归档 → ~/wiki/） |
| `references/clawmem-to-skill-ref.md`
| `references/clawmem-ts-migration.md` | ClawMem TS Migration | TS 5.9 → 5.x migration, CodeBuddy CLI history.jsonl bug fix, Gitee push auth | | ClawMem 经验提取 → Skill 同步 |
| `references/clawmem-dev-pitfalls-ref.md` | ClawMem 开发陷阱 |

---
---

## Development: GSD Workflow, ESM Pitfalls & Debugging

### GSD Workflow (Mandatory for ClawMem)

ClawMem uses a planning-with-files workflow:
- Read `task_plan.md` before any reply — current phase
- Update `progress.md` after every 2 action/view/search turns
- Update `findings.md` when decisions are made
- Mark phases complete only after CLI verification (`--dry-run`, `--help`)
- After 3 conversation turns, force re-read `task_plan.md` + `findings.md`
- `machine-config.ts` drives all paths — never hardcode usernames or machine directories

**Anti-pattern: false-complete** — Phase can appear done (code committed) but CLI fails.

### CodeBuddy ACP Pitfalls

- **Do not delegate** narrow scope-control tasks to CodeBuddy / any ACP agent
- CodeBuddy ACP autonomous scope may delete files outside the task (`--acp` is a boundary-free mode — confirmed destructive 2026-05-04)
- Use for: new file creation, independent new-feature dev
- Avoid for: modifying specific functions in existing files, multi-file coordination
- Always `cd <absolute_path>` explicitly before starting

### Phase5Index / Storage Debugging Methodology

1. **Isolate HEAD first** — `git stash && npx tsc --noEmit 2>&1 | grep src/` before blaming local changes
2. **WSL CRLF→LF trap** — `git show HEAD:src/cli/index.ts | wc -l` vs `wc -l src/cli/index.ts`; HUGE diff = content rewrite, not edit
3. **Restore HEAD**: `git checkout HEAD -- <file>`; then validate
4. **TS 5.9 strict** compatibility patterns (see `references/clawmem-ts-debugging.md`)

### ESM Module Boundary Pitfalls (ClawMem is ESM)

`package.json` declares `"type": "module"`. Common failure:
```typescript
// ❌  don't do
require('os').release()          // CRASHES – require undefined in ESM

// ✅  do
import { release } from 'os';
release().toLowerCase()          // works fine
```

- For references see `references/clawmem-esm-cli-fix-2026-05-08.md` — full `isWSL()` fix
- Relative import layer rules: `src/cli/index.ts` is 2 levels deep from `src/config/` (`../config/machine-config.js`), hooks use `../../dist/config/machine-config.mjs`
- `export-wiki.ts` Hermes session pattern: `/.jsonl$/` on machine storing `.json` → change to `/.json?$/`

### Patch Tool Mis-match Trap

`patch(old_string=...)` scans whole file — pick the longest unique context. Verify immediately:
```bash
git diff <file> | head -40   # check scope
git checkout -- <file>       # undo if wrong match
```

### ClawMem Search Quality vs OV

ClawMem L0 = English/keyword matching; OV = semantic search. For Chinese NL queries, ClawMem recall is much lower. Use OV for Chinese query scenarios.

### MCP + CLI Storage Split

- `clawmem_list` (MCP) → `~/.clawmem/memories/*.md` (JSON store)
- `clawmem_search` (MCP) → `wiki/raw/memory/*.md` (markdown store, vector+BM25)
- `cli/search` → broken (frontmatter regex mismatch); always use `clawmem_search` MCP tool

---

## Windows 原生设置

ClawMem 从 WSL 迁移到 Windows 原生时，需注意：

### 1. 路径修改

全部使用 Windows 正斜杠路径（Node.js 和 YAML 均接受）：
- `C:/Users/dddog/clawmem/dist/mcp-server.js`
- `C:/Users/dddog/clawmem/src/hooks/hermes-stop.mjs`
- `C:/Users/dddog/Nutstore/1/myNutstore/hermes-sync/wiki/raw/memory`

### 2. MCP 服务环境变量

在 `config.yaml` 中为 MCP 服务显式指定 CLAWMEM_MEMORY_DIR：
```yaml
mcp_servers:
  clawmem:
    command: node
    args:
    - C:/Users/dddog/clawmem/dist/mcp-server.js
    env:
      CLAWMEM_MEMORY_DIR: C:/Users/dddog/Nutstore/1/myNutstore/hermes-sync/wiki/raw/memory
```

### 3. 调试方法

MCP 服务可使用 CLI 直接测试：
```bash
cd /c/Users/dddog/clawmem
echo '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' | \
  CLAWMEM_MEMORY_DIR="C:/Users/dddog/Nutstore/1/myNutstore/hermes-sync/wiki/raw/memory" \
  node dist/mcp-server.js
```

### 终端 shell 环境陷阱

终端工具运行在 **WSL bash**（`HOME=/home/dddog`），不是 Git Bash 或原生 Windows cmd。这意味着：
- `node dist/mcp-server.js` 走的是 WSL 的 Node.js，不是 Windows 的
- `~/.hermes/` 解析到 `/home/dddog/.hermes/`（WSL 路径），不是 `C:\Users\dddog\.hermes\`
- 要调用 Windows 原生程序需用 `/mnt/c/...` 全路径
- `which node` 返回 WSL 路径；`/mnt/c/Program Files/nodejs/node.exe` 才是 Windows 原生

### 5. export-wiki 模式修复

Windows 原生 Hermes 存的是 `.json` 非 `.jsonl`，见 `clawmem-dev-pitfalls`。
