---
name: clawmem-wsl-path-fixes
description: ClawMem 路径修复经验 — kangle (WSL) 和 wooking (Windows) 双机器硬编码 ddddog/kangle 路径重构，含 patch 误匹配、import 路径、TS 编译陷阱
---

# ClawMem 路径修复经验（2026-05-06 初记，2026-05-11 补充）

记录 ClawMem 项目源码中用户名硬编码路径的修复过程，覆盖 **kangle (WSL)** 和 **wooking (Windows)** 两台机器。

## 问题背景

项目最初是个人工具，在路径检测代码中直接写了 `dddog`/`kangle` 双路径。支持多机器后只做 patch，未彻底重构。

**wooking (Windows) 2026-05-11 发现的残留**：
- `src/cli/index.ts`：`NUTSTORE_ROOT` 常量硬编码 `C:/Users/ddddog/...`
- `src/cli/index.ts`：`detectNutstorePath()` 含 `C:/Users/ddddog` 和 `C:/Users/kangle` 两条
- `dist/` 编译产物对应处有残留（wooking 机器本身能用，但不通用）

## Phase 2: wooking `src/cli/index.ts` 重构（2026-05-11）

### 修复内容

**删 `NUTSTORE_ROOT` 硬编码常量**（原 L25-27）：
```typescript
// 修复前 ❌
const NUTSTORE_ROOT = isWSL()
  ? '/mnt/c/Users/ddddog/Nutstore/1/myNutstore'
  : 'C:/Users/ddddog/Nutstore/1/myNutstore';

// 修复后 ✅
import { resolvePath } from '../config/machine-config.js';
export const DEFAULT_MEMORY_DIR = resolvePath('hermesSyncWiki', 'memory');
```

**删 `detectNutstorePath()` 硬编码行**：
```typescript
// 修复前 ❌
const possiblePaths = [
  `${home}/Nutstore/1/myNutstore/clawmem`,
  `${home}/Nutstore/1/myNutstore (1)/clawmem`,
  `${home}/坚果云/clawmem`,
  `C:/Users/ddddog/Nutstore/1/myNutstore/clawmem`,   // ← 删除
  `C:/Users/kangle/Nutstore/1/myNutstore (1)/clawmem`, // ← 删除
];

// 修复后 ✅
const possiblePaths = [
  `${home}/Nutstore/1/myNutstore/clawmem`,
  `${home}/Nutstore/1/myNutstore (1)/clawmem`,
  `${home}/坚果云/clawmem`,
];
```

### 验证

```bash
cd ~/clawmem
npm run build
grep "dddog" dist/cli/index.js     # 应返回空
node dist/cli/index.js ls -l 3      # 应正常列出记忆
```

### 遇到的坑

1. **patch 误匹配**：目标字符串在文件多处出现时，`patch(old_string=...)` 匹配到 imports 区域。解决：加长唯一上下文，或直接还原后重做。
2. **import 相对路径**：`src/cli/index.ts` 在 `src/cli/` 子目录，引用上级 `config/` 用 `../config/machine-config.js`（不是 `./config/` 也不是 `config/`）。
3. **TS 类型错误不断build**：`tsc` 报 TS 类型错误仍生成 .js，CLI 能正常运行。dist 产物以运行时验证为准。

---

## kangle (WSL) 修复（2026-05-06）

[保持原有内容不变]

## 问题背景

kangle 机器（WSL）运行 clawmem 时：
- `clawmem list` → "No memories found"（实际有 104 条）
- `clawmem search` → 搜不到任何结果
- 直接用 Node.js API 传正确路径 `/mnt/c/Users/kangle/Nutstore/...` 可以正常读 104 条

根因：**两处代码都硬编码了 `dddog` 用户路径**

## 修复清单

### 1. export-wiki.ts 路径动态化

| 变量 | 原值（硬编码） | 修复后 |
|------|--------------|--------|
| `nutstoreRoot` | `/mnt/c/Users/ddddog/Nutstore/...` | `getNutstoreRoot()` 自动检测 |
| `WIKI_BASE` | 依赖硬编码 nutstoreRoot | `getWikiBase()` |
| `codebuddyIdeBase` | `/mnt/c/Users/ddddog/AppData/Local` | `getCodebuddyIdeBase()` |
| `codebuddy_cli_win` | `/mnt/c/Users/ddddog/.codebuddy` | `getCodebuddyCliWinBase()` |
| `outputSubdir` | `dddog-hermes` | `${getHostname()}-hermes` |

### 2. clawmem CLI detectNutstorePath() WSL 分支

原代码 WSL 分支用 `C:/Users/ddddog/...`（Windows 路径格式），WSL 下不存在。

修复：WSL 分支改用 `/mnt/c/Users/<username>/Nutstore/...` 格式，并覆盖 ddddog 和 kangle 两个用户的可能路径。

### 3. Git diverged + 被污染 commit 处理（2026-05-06）

**症状**：本地 master 和 origin/master diverged，无法普通 push。

```
本地 master:  eb6e57b → e5b090f (kangle-wsl-fix)
origin/master: b1c35fb（含 12 个冲突标记，是坏 commit）
```

**检测坏 commit**：
```bash
git show <commit>:src/cli/index.ts 2>/dev/null | grep -c "<<<<<<" || echo "0"
git show <commit>:src/export-wiki.ts 2>/dev/null | grep -c "<<<<<<" || echo "0"
```
`b1c35fb` 得分为 12——含大量未解决冲突标记，无法 merge/cherry-pick。

**处理流程**：
1. `git checkout origin/master -b merge-wsl-fix` — 基于坏 commit 新建分支
2. `git cherry-pick e5b090f --no-commit` — 尝试 cherry-pick 干净修复
3. 冲突时用 `git checkout --ours <file>` 保留任一方干净版本
4. `git push origin merge-wsl-fix` — 新分支 push
5. 通过 留言板 异步沟通，等对方在 gitee 上 merge 或 force push

**wooking/kangle 协作约定**：
- 重大 Git 操作（force push、删除分支）需对方确认
- 通过坚果云 `留言板.md` 异步沟通
- force push 被阻止时选方案 B（普通 push + merge）

### 4. 留言板协作格式

路径：`/mnt/c/Users/kangle/Nutstore/1/myNutstore (1)/hermes-sync/留言板.md`

```markdown
# 留言板

> **规则**：新留言置顶 · 旧留言保留（渐进披露标题） · 更新进展写在对应条目下

---

## 2026-MM-DD 标题

### 问题描述
...

### 根因
...

### 修复/处理
...

### 待确认事项
1. ...
```

**规则**：
- 新留言放最上，旧留言往下保留
- 不要删除旧内容，可在下写更新进展
- 先读标题，渐进披露细节

## 关键文件

- `/mnt/c/Users/kangle/clawmem/src/export-wiki.ts`
- `/mnt/c/Users/kangle/clawmem/src/cli/index.ts`

## 验证命令

```bash
# export-wiki.ts dry-run（指定日期加速）
cd /mnt/c/Users/kangle/clawmem && npx tsx src/export-wiki.ts --dry-run --date 2026-05-09

# 检查编译产物无 dddog 残留
grep -r 'dddog' dist/export-wiki.js; echo "exit: $?"

# clawmem list
node dist/cli/index.js list -l 5

# clawmem search
node dist/cli/index.js search "关键词"
```

## 2026-05-09 补充：export-wiki.ts 修复模式

已在 `export-wiki.ts` 上验证的完整模式：

1. **`getWindowsUser()`** — WSL 下用 `process.env.USER`，Windows 下用 `process.env.USERNAME`
2. **`os.hostname()`** — 用于 `outputSubdir`（自动区分 kangle/wooking）
3. **坚果云路径** — kangle 机器用 `myNutstore (1)`（带空格和序号）
4. **所有路径常量** — 从硬编码 `dddog` 改为动态拼接 `${winUser}`

修复后 `grep -n 'dddog' src/export-wiki.ts` 应返回 0 匹配。
