# Clawmem Dev Pitfalls
> Absorbed from archived skill `clawmem-dev-pitfalls` during consolidation pass (2026-05-22).

---


# ClawMem 开发陷阱和经验

## GSD 工作流（强制）

ClawMem 项目使用 GSD (Get Shit Done) 工作流。**不得 ad-hoc 开发。**

规则（已写入 AGENTS.md，每次 session 自动加载）：
1. 回复前必须读 `STATE.md`（项目根目录，不是 `.planning/`）
2. 回复开头标注 `【GSD Phase X | Plan: Y | Milestone: Z】`
3. 执行代码前确认任务在当前 PLAN.md 的 TODO 列表中
4. 做完后必须更新 STATE.md
5. 3轮对话后强制重读 STATE.md + ROADMAP.md
6. 偏离计划时立即停止并告知用户

STATE.md 和 ROADMAP.md 在项目根目录：`/mnt/c/Users/dddog/clawmem/`

## CodeBuddy ACP 模式 Pitfall（2026-05-04 初记，2026-05-11 补充）

**不要派 CodeBuddy 做需要精确 scope 控制的小任务。**

CodeBuddy ACP 模式（`codebuddy --acp`）会自主决定操作范围，可能删除或修改任务范围外的文件。

**2026-05-04 实测**：派 CodeBuddy 修改 `phase5-index.ts` 中的 `extractMemoryFields` 函数时，它删除了 `.architecture/` 目录下的多个文档和 `.planning/task_plan.md`、`ROADMAP.md`、`STATE.md`。

**2026-05-11 实测（委派 clawmem 硬编码修复）**：
1. **进错工作区**：CodeBuddy 进入了 `hermes-windows` 而非 `clawmem` 项目目录，导致所有文件找不到
2. **patch 格式错误**：patch 内容作为 string 参数传入 tool call，格式被破坏，未实际修改文件

适合 CodeBuddy 的任务：
- 明确的文件创建/修改（指定**绝对路径**）
- 独立的新功能开发（不影响现有文件）

不适合 CodeBuddy 的任务：
- 修改特定函数（需要精确理解现有代码结构）
- 涉及多个文件的协调修改
- 任何需要严格控制 scope 的操作
- **跨目录的多文件修改任务**（高概率进错工作区）

**委派成功的前提**：
- 明确告知 `cd /c/Users/ddddog/clawmem` 作为第一条命令
- 指定文件时用**绝对路径**
- 避免用 patch/Replace 格式，改用明确的 Write/Edit

**替代方案**：直接在本 session 中执行小任务。

## Frontmatter 解析

`src/summarize/phase5-index.ts` 中的 `extractMemoryFields` 函数支持两种 frontmatter 格式：
- 单引号格式：`'id': 'xxx'`（原始格式）
- 标准 YAML 格式：`id: 'xxx'` 或 `id: xxx`

对于完全没有 `id` 字段的文件，会自动用文件名（不含 `.md`）生成 id。

## Jina API 配置

当前配置（工作正常）：
- API Base: `https://ai.gitee.com/v1/embeddings`
- Model: `jina-embeddings-v4`
- API Key: 存在 `~/.clawmem/config.json` 的 `embedding.jinaApiKey`

## 向量索引

- 索引数据库：`~/.clawmem/phase5_index.db`
- 重建索引：`npx clawmem sync-index`
- 搜索：`npx clawmem search "<query>" --embedding jina`
- 当前状态：49/49 文件已索引（100%，2026-05-05）
- 支持旧格式文件（`tags:`/`source:` 而非 `keywords:`/`l2_sources:`，无 `id`/`type`）—— `parseMemoryFile` 有完整 fallback

## MCP Server 目录配置陷阱（2026-05-05）

**MCP server 的 `memory_dir` 扫描路径必须与 CLI/OV 实际存储路径一致。**

- 实际记忆路径：`/mnt/c/Users/dddog/Nutstore/1/myNutstore/hermes-sync/wiki/raw/memory/`（47 条）
- MCP 错误扫描：`/mnt/c/Users/dddog/Nutstore/1/myNutstore/hermes-sync/wiki/raw/memory/dddog-hermes/`（只有 1 条）
- 根因：MCP server 配置的 `memoryDir` 加了 `dddog-hermes` 子目录，而 CLI add 写入的是上级目录
- 验证方法：`clawmem_list` 总数 vs `ls <dir> | wc -l`
- 修复：统一 MCP server 和 CLI 的 `DEFAULT_STORAGE_DIR`

## ClawMem vs OV 搜索质量差距（2026-05-05）

**ClawMem 搜索是 L0 keyword 匹配，OV 是语义搜索。中文查询差距显著。**

| 查询 | ClawMem | OV |
|------|---------|-----|
| `hermes 多设备 记忆同步` | 0 条 | 10 条 |
| `hermes` | 5 条 | 10 条 |
| `记忆` | 5 条 | 10 条 |

**结论**：ClawMem 搜索适合英文/技术标签，对中文自然语言查询召回率低。替代 OV 前需解决此差距。

## Shell Hook Allowlist 陷阱（2026-05-04/05）

**`hooks_auto_accept: true` 对 shell hook 无效。**

- 错误现象：hook 脚本每次调用都 `WARNING ... not allowlisted — skipped`
- 原因：`hooks_auto_accept` 只控制 TTY prompt，不控制 shell hook allowlist
- 需要：`command_allowlist` 中注册完整路径，或 gateway 启动时加 `--accept-hooks`
- 日志位置：`~/.hermes/logs/errors.log`（搜索 "not allowlisted"）

## export-history.mjs

- 位置：`scripts/export-history.mjs`
- 新增 `--no-truncate` 参数：不截断工具参数和结果
- 工具调用摘要显示频次统计（如 `read_file ×3, terminal ×2`）

## ESM 模块中 require() 陷阱（2026-05-08）

**ClawMem 是 ESM 项目（`"type": "module"`），禁止使用 `require()`。**

症状：`dist/cli/index.js` 运行时 `ReferenceError: require is not defined in ES module scope`

根因：`src/cli/index.ts` 中 `isWSL()` 函数用了 `require('os').release()`，TypeScript 编译后直接变成 `require()` 调用

修复：
```typescript
// 错误
function isWSL(): boolean {
  return process.platform === 'linux' &&
    (!!process.env.WSL_DISTRO_NAME ||
      require('os').release().toLowerCase().includes('wsl'));
}

// 正确
import { release } from 'os';
function isWSL(): boolean {
  return process.platform === 'linux' &&
    (!!process.env.WSL_DISTRO_NAME ||
      release().toLowerCase().includes('wsl'));
}
```

## Windows 原生 ClawMem 配置陷阱（2026-05-10）

**ClawMem 从 WSL 迁移到原生 Windows 时，config.yaml 和 .env 的路径必须全部更新。**

### 需要改的路径

| 配置位置 | WSL 旧路径 | Windows 新路径 |
|---------|-----------|--------------|
| `config.yaml mcp_servers.clawmem.args` | `/mnt/c/Users/dddog/clawmem/dist/mcp-server.js` | `C:\Users\dddog\clawmem\dist\mcp-server.js` |
| `config.yaml hooks.*.command` | `node /mnt/c/Users/dddog/clawmem/src/hooks/*.mjs` | `node C:\Users\dddog\clawmem\src\hooks\*.mjs` |
| `.env CLAWMEM_MEMORY_DIR` | `/mnt/c/Users/.../wiki/raw/memory` | `C:\Users\...\wiki\raw\memory` |

注意 `.env` 文件受 Hermes 保护，不能用 `patch` 工具直接改，需通过终端执行 Node.js 脚本：
`node -e "var f=require('fs');var c=f.readFileSync('.../.env','utf8');c=c.replace(/CLAWMEM_MEMORY_DIR=.*/,'CLAWMEM_MEMORY_DIR=...');f.writeFileSync('.../.env',c);"`
用 `replace(/regex/,...)` 而非 `replace('string',...)` 避免 Node.js 对 `\1`、`\r` 等字符的转义。

### MCP 服务需 CLAWMEM_MEMORY_DIR 环境变量

MCP server 需要 `CLAWMEM_MEMORY_DIR` 环境变量才能找到记忆文件。如果 `.env` 文件配置正确，gateway 启动时会自动加载。但 MCP 子进程可能继承不到 `.env` 中的变量（Hermes 会过滤环境变量）。

**解决方案**：在 `config.yaml` 的 `mcp_servers.clawmem.env` 中添加：
```yaml
mcp_servers:
  clawmem:
    command: node
    args:
    - C:\Users\dddog\clawmem\dist\mcp-server.js
    env:
      CLAWMEM_MEMORY_DIR: C:\Users\dddog\Nutstore\1\myNutstore\hermes-sync\wiki\raw\memory
```

### export-wiki Hermes session 模式不匹配（2026-05-10）

**`dist/export-wiki.js` 中 Hermes session 读取器匹配 `/.jsonl$/` 但本机 Hermes 存的是 `.json` 文件。**

```javascript
// dist/export-wiki.js 中：
hermes: {
    name: 'Hermes',
    dir: path.join(os.homedir(), '.hermes', 'sessions'),
    pattern: /\.jsonl$/,          // ❌ 不匹配 .json 文件
    outputSubdir: 'dddog-hermes',
}
```

症状：`export-wiki.js --dry-run` 显示 "Hermes: 0 个会话"，即使 `~/.hermes/sessions/` 目录下有很多 `session_*.json` 文件。

修复：将 pattern 改为 `/\.json$/` 或 `/\.jsonl?$/`。

同时需确认 Hermes state.db 中 session 表的 schema 与 export-wiki 中 SQLite 查询是否一致（Windows 版可能 schema 不同）。

### CLI search 命令解析失败（2026-05-10）

**`dist/cli/index.js` 中 `search` 命令的 fallback 代码（文件扫描）解析 frontmatter 的 regex 与实际记忆文件格式不匹配，永远返回 0 条。**

```javascript
// ❌ 失败：匹配 'l0' 和 YAML 多行格式
const l0KeyMatch = frontmatter.match(/^'l0':\s*\n\s+'key':\s*'(.+)'$/m);
const descMatch = frontmatter.match(/description:\s*"(.+?)"/m);

// 但实际记忆文件格式是：
// ---
// id: xxx
// type: event
// keywords: [kw1, kw2]
// l2_sources: [manual:add]
// access_count: 3
// ---
```

**关键**：MCP 服务（`dist/mcp-server.js`）使用的 `searchMemories` 来自 `dist/summarize/storage.js`，它直接读取 markdown 文件并用 `includes()` 匹配，**工作正常**。只有 CLI 的 `search` 命令有问题。

使用 MCP 工具 `clawmem_search` 替代 CLI 的 `search` 命令。

## Hermes Hooks 文件不存在（2026-05-08）

**当前 ClawMem commit 5312708 中，`src/hooks/` 目录下没有 `hermes-stop.mjs`、`hermes-session-start.mjs`、`hermes-session-end.mjs` 文件。**

实际存在的 hooks 文件：`stop.mjs`、`session-start.mjs`、`session-end.mjs`、`pre-compact.mjs`、`user-prompt.mjs`、`utils.mjs`（均为 CodeBuddy 格式）

**不要基于旧的 `clawmem-hooks-architecture` skill 注册 Hermes hooks**——该 skill 描述的文件路径已过时。

如需 Hermes hooks 集成，需新建适配文件或从 CodeBuddy 格式转换。

## 留言板优先原则（2026-05-08）

**处理 ClawMem 相关问题时，先读留言板再行动。**

用户明确要求：遇到 ClawMem/Hermes 相关问题 → 先查看留言板获取最新上下文 → 再决定是否/如何修改代码

留言板路径：`/mnt/c/Users/kangle/Nutstore/1/myNutstore (1)/hermes-sync/留言板.md`

## .clawmem 目录位置（2026-05-11）

**`config.json` 在 home 目录下的 `.clawmem/`，不在 Nutstore 同步目录里。**

| 目录 | 作用 | git 管理 |
|------|------|---------|
| `~/.clawmem/` = `C:\Users\dddog\.clawmem\` | config.json、向量库、状态文件 | ❌ 不归 git |
| `Nutstore\...\hermes-sync\` | 记忆/历史同步到 wiki | ❌ 不归 git |
| `C:\Users\dddog\clawmem\` | 源码仓库 | ✅ git 管理 |

**错误表述**："`.clawmem/` = Nutstore 同步目录" —— `.clawmem/` 是 home 下的隐藏目录，Nutstore 那条线完全不碰它。

## 硬编码路径重构架构（2026-05-11）

**项目源码中所有 dddog/kangle 用户名硬编码已被移除，改用 `~/.clawmem/config.json` 配置。**

### 核心模块

- **`src/config/machine-config.ts`** — TypeScript 源码，编译到 `dist/config/machine-config.js`
- **`src/config/machine-config.mjs`** — 独立 ESM 运行时模块，供 hooks 直接 import，build 时拷贝到 `dist/config/`

### 路径解析 API

```typescript
import { getMachineProfile, resolvePath, getMachineId } from './config/machine-config.js';

// 获取完整 profile
const profile = getMachineProfile();
// → { machineId, nutstoreBase, clawmemRoot, hermesSyncWiki, codebuddyIdeHistory, codebuddyCliHistory, ... }

// 路径拼接
resolvePath('hermesSyncWiki', 'memory')  // → C:/Users/dddog/Nutstore/.../wiki/raw/memory
resolvePath('clawmemRoot')              // → C:/Users/dddog/clawmem

// 当前 machineId（前缀，用于 memory 子目录）
getMachineId()  // → 'wooking'
```

### hooks 中的导入方式

```javascript
// src/hooks/utils.mjs
import { resolvePath, getMachineProfile, isWSL as cfgIsWSL } from '../../dist/config/machine-config.mjs';
export { cfgIsWSL as isWSL };
export { resolvePath, getMachineProfile, getMachineId };
```

### 新增机器配置

在 `~/.clawmem/config.json` 中添加 machines section：

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
      "codebuddyIdeHistory": "C:/Users/dddog/AppData/Local/CodeBuddyExtension/Data/.../history",
      "codebuddyCliHistory": "C:/Users/dddog/.codebuddy"
    }
  }
}
```

## ESM/TypeScript 模块边界陷阱（2026-05-11 初记，2026-05-11 补充）

**ESM hooks (`.mjs`) 不能直接 import TypeScript 编译输出的 `.js`，必须有独立的 `.mjs` 源文件。**

问题：hooks 是独立部署的 `.mjs`，但 TypeScript 编译 `machine-config.ts` → `machine-config.js` 后，hooks 无法 import ESM 编译输出。

解决方案：创建 `src/config/machine-config.mjs`（原始 ESM 源码），build 脚本额外拷贝到 `dist/config/`：

```json
// package.json build 脚本追加
"build": "tsc -p config/tsconfig.json && node -e \"...; for(const f of ['machine-config.mjs']) copyFileSync('src/config/'+f,'dist/config/'+f);\""
```

hooks import 时用相对路径：`../../dist/config/machine-config.mjs`（从 `src/hooks/` 出发）。

### 相对导入路径规则（2026-05-11 补充）

`src/cli/index.ts` 新增对 `machine-config` 的 import 时，路径级别：

| 源文件位置 | 目标文件 | 正确写法 |
|-----------|---------|---------|
| `src/cli/index.ts` | `src/config/machine-config.js`（编译输出） | `../config/machine-config.js` |
| `src/hooks/*.mjs` | `dist/config/machine-config.mjs` | `../../dist/config/machine-config.mjs` |

注意：`cli/index.ts` 在 `src/cli/` 子目录，向上两级到 `src/` 再进 `config/`。

### TypeScript 编译 ≠ 构建失败（2026-05-11）

**TS 类型错误不阻断编译。** `tsc` 报大量 `error TS...` 仍会生成 `.js` 输出文件，CLI 能正常运行。dist 编译产物以运行时验证为准，不以 TS lint 输出判断。

### patch 工具误匹配陷阱（2026-05-11 补充）

`patch(old_string=...)` 的匹配是**全文扫描**，若目标字符串在文件多处出现，会匹配到第一个。当目标行附近有其他相似内容时，可能意外修改无关代码。

症状：删除两行硬编码时，`patch` 工具匹配到了 imports 区域（因 `from 'config/machine-config.js'` 字符串出现在文件开头附近），导致大量 import 语句被误删。

解决：
1. 用**更长的唯一上下文**包裹 old_string（前后各多取几行）
2. patch 后立即 `git diff` 验证 diff 是否符合预期
3. 若误匹配，立即 `git checkout -- <file>` 还原再重做

验证命令：
```bash
git diff src/cli/index.ts | head -40   # 验证修改范围
git checkout -- src/cli/index.ts        # 误匹配时还原
```
