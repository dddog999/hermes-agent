---
name: hermes-internal-debugging
description: "Debugging Hermes Agent internals — tools, gateway, run_agent, and the agent loop. Covers safe techniques when the thing being debugged can hang or crash the agent itself."
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [debugging, hermes-agent, internals, tools, python, patch, hang]
    related_skills: [systematic-debugging, python-debugpy, debugging-hermes-tui-commands]
---

# Debugging Hermes Internals

## Overview

When debugging Hermes Agent itself (tools, gateway, run_agent, agent loop), you face a unique hazard: the tool or code path you're investigating may be the cause of the hang or crash. Investigating a hanging tool via the same hanging tool creates a death loop.

## When to Use

- A Hermes tool hangs for minutes or indefinitely
- Session becomes unresponsive mid-analysis
- Force-killing Hermes is required to recover
- A tool worked in Feishu but hangs in CLI (or vice versa)
- Investigating `file_operations.py`, `patch`, `fuzzy_match`, `model_tools`, `run_agent`, `gateway`

## Critical Rule

**Test the suspect function in a standalone Python script BEFORE reading its source with Hermes tools.**

If the suspect code can hang, reading its source with Hermes will hang Hermes. Use the agent's own Python to call the function directly:

```bash
cd /home/dddog/.hermes/hermes-agent && python3 -c "
import sys; sys.path.insert(0, '.')
from tools.fuzzy_match import fuzzy_find_and_replace
# test here
"
```

This validates behavior without going through Hermes's tool-calling layer.

## The Hang Investigation Pattern

When a tool hangs on a large file (e.g., 90KB TypeScript file):

1. **Reproduce in isolation** — call the suspect function with synthetic/small data
2. **Time each component** — measure which step is slow
3. **Add a timeout guard** — `timeout 10 python3 -c "..."` for CLI tests
4. **Identify the O(n²) algorithm** — e.g., nested SequenceMatcher loops
5. **Preserve state** — commit git, save planning files, sync to OV before you risk a crash
6. **Fix and test in isolation** — verify fix works in standalone script, not Hermes

## Preserving Session State Before Risky Investigation

Before investigating anything that might hang/crash:

1. Commit all git changes: `git add -A && git commit -m "WIP: investigating X"`
2. Update planning files: `task_plan.md`, `findings.md`, `progress.md`
3. Sync key context to OV: `viking_remember` with findings
4. Note: Hermes restart loses session context from SQLite, but files persist

## Case Study: patch Tool Hang on Large Files

**Symptoms:** `patch` tool hangs for 4+ minutes on 90KB TypeScript files. CLI hangs, Feishu may work. Session lost on force-kill.

**Root cause:** `tools/fuzzy_match.py` — `fuzzy_find_and_replace` tries 9 strategies in order. Strategies 8 (`block_anchor`) and 9 (`context_aware`) use `difflib.SequenceMatcher.ratio()` in nested loops — O(n²). No timeout protection on these strategies.

**The 30-second timeout on `_check_lint` (npx tsc) did NOT protect against the fuzzy matching phase** — it only applied to the linting step that runs after the file is already patched.

**Fix:** Add time-based timeout checking after each slow strategy. If exceeded, fall back to `re.sub`:

```python
# In fuzzy_find_and_replace, for strategy_name in _SLOW_STRATEGY_NAMES:
_strategy_start = time.monotonic()
matches = strategy_fn(content, old_string)
elapsed = time.monotonic() - _strategy_start
if elapsed > timeout:
    return _replacement_fallback(content, old_string, new_string, replace_all)
```

**Key locations:**
- `tools/fuzzy_match.py` — `fuzzy_find_and_replace()`, `_SLOW_STRATEGY_NAMES`
- `tools/file_operations.py:832` — `patch_replace()` calls with `timeout=5`

## CLI vs Feishu Tool Behavior Difference

When a tool works in one platform but hangs in another:
- Both use the same Python tool code (`ShellFileOperations`, etc.)
- The difference is usually in `old_string` content (triggers different code paths)
- OR the async gateway dispatch handles timeouts differently
- The root cause is the same code, just different inputs/execution paths

## Safe Recovery After a Hang

If Hermes hangs and must be force-killed:
1. The session context in SQLite (`~/.hermes/state.db`) may be lost
2. File changes on disk are preserved
3. Restart by: `hermes --resume <session_id>` — if session is gone, start fresh with context from planning files + OV
4. The fix should be applied BEFORE restarting the investigation

## Tools That Can Hang (Known Cases)

| Tool | Cause | Fix Applied |
|------|-------|-------------|
| `patch` (fuzzy mode) | strategies 8-9 O(n²) SequenceMatcher | timeout=5s + fallback |

Check `tools/fuzzy_match.py` for `_SLOW_STRATEGY_NAMES` for current list.
