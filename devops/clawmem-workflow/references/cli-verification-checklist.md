# ClawMem CLI Verification Checklist

## False Complete Prevention (2026-05-04)

Phase 3-4 were marked `complete` in task_plan.md based on code review, but CLI crashed on `require('os')` in ES module. Code existing ≠ feature works.

## Verification Sequence

Before marking ANY CLI phase complete, run ALL of:

```bash
# 1. Build
npm run build

# 2. CLI smoke test
node dist/cli/index.js --help

# 3. Command --help for each new command
node dist/cli/index.js <command> --help

# 4. Dry-run smoke test
node dist/cli/index.js <command> --dry-run
```

## Phase 3-6 Verified Commands

| Phase | Command | Verification | Status |
|-------|---------|-------------|--------|
| Phase 3 | dedup | `--dry-run` → "No duplicates found" | ✅ |
| Phase 4 | forget | `--dry-run --json` → shows forgettable memories | ✅ |
| Phase 5 | search-l0 | `search-l0 "test"` → file scan works | ✅ |
| Phase 6 | run-pipeline | `--help` → shows options | ✅ |

## Common ClawMem Bug Pattern

**`require('os')` in ES module** — ClawMem is `"type": "module"`, so `require()` is unavailable. Symptom: CLI crashes immediately with module error. Fix: convert to `import { ... } from 'os'`.
