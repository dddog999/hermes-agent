# ClawMem TS Migration

> Absorbed from archived `clawmem-ts-migration` during consolidationpass.

---


# ClawMem TypeScript Migration — 2026-05-02

## 迁移结果

**结论**：所有 `src/` 下的 `.mjs` 文件已迁移为 `.ts`，编译到 `dist/`。clawmem 项目本身 TS 迁移完成。

| 源文件 | 编译产物 |
|--------|---------|
| `src/summarize/extractor.ts` | `dist/summarize/extractor.js` |
| `src/export-wiki.ts` | `dist/export-wiki.js` |
| `src/audit-memories.ts` | `dist/audit-memories.js` |
| `src/cli/index.ts` | `dist/cli/index.js` |
| `src/core/storage.ts` | `dist/core/storage.js` |

**删除的旧文件**：`scripts/export-to-wiki.mjs`、`scripts/audit-memories.mjs`（已迁至 `src/`）。

**仍为 .mjs**：`src/hooks/` 下 7 个 hermes-sync 运行时 hook（不在 clawmem tsc 编译链中，需单独迁移 hermes-sync 配置）。

## npm scripts（当前正确值）

```json
{
  "build": "tsc -p config/tsconfig.json && node -e '...' (复制 prompts/ + 清理旧 .mjs)",
  "export-wiki": "node --env-file=/home/dddog/.hermes/.env dist/export-wiki.js",
  "audit": "node dist/audit-memories.js",
  "summarize": "node --env-file=/home/dddog/.hermes/.env dist/cli/index.js summarize",
  "dev": "tsc -p config/tsconfig.json --watch",
  "rebuild": "npm run clean && npm run build"
}
```

## Gitee push 认证（无 credential helper 时）

```bash
GIT_TOKEN=$(cat /mnt/c/Users/dddog/.gitee_token)
git remote set-url origin "https://dddog535459:$GIT_TOKEN@gitee.com/dddog535459/clawmem.git"
git push
git remote set-url origin "https://gitee.com/dddog535459/clawmem.git"
```

## 验证 pipeline 可用

```bash
# summarize dry-run
npm run summarize -- --dry-run ~/.clawmem/l2-history-flat/2025-09-16.md

# summarize 实际提取（✅ 成功：3 条记忆写入 memories/）
npm run summarize -- ~/.clawmem/l2-history-flat/2025-09-16.md

# export-wiki 扫描（118 sessions）
npm run export-wiki -- --dry-run

# audit 格式审核
npm run audit
```

## CodeBuddy CLI history.jsonl bug（已修复 in export-wiki.ts）

- **问题**：`scanSessions()` 把整个 `history.jsonl` 当单个 session，只导出第一条日期
- **修复**：实现 `scanCodebuddyCli()`，按日期拆分一个 .jsonl 为多个 session
- **验证**：`history.jsonl` 含 2026-04-12/04-25/05-01 → 正确导出 3 个 session
