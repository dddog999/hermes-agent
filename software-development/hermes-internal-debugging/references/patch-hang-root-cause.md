# patch Tool Hang — Root Cause Reference

## The Bug

`tools/fuzzy_match.py::fuzzy_find_and_replace()` — 9 strategies tried in order.
Strategies 8 (`_strategy_block_anchor`) and 9 (`_strategy_context_aware`) call
`difflib.SequenceMatcher.ratio()` inside nested loops over all content lines.

For a 90KB / 2342-line file: O(n²) = ~5.5 million comparisons per strategy.
On `/mnt/c/` (Windows filesystem via WSL) this is especially slow.

## Why the 30s Timeout Didn't Help

`_check_lint()` has `timeout=30` — but it runs AFTER `fuzzy_find_and_replace()`.
The hang happens during fuzzy matching, which has NO timeout.

## The Fix (committed: 7cc389fd8)

`tools/fuzzy_match.py`:
- New `_SLOW_STRATEGY_NAMES = frozenset({"block_anchor", "context_aware"})`
- New `_replacement_fallback()` — simple `str.replace` + `re.findall`
- `fuzzy_find_and_replace(timeout=5.0)` — time.monotonic() check after each slow strategy
- If elapsed > timeout: return `_replacement_fallback()`

`tools/file_operations.py:832`:
```python
new_content, match_count, _strategy, error = fuzzy_find_and_replace(
    content, old_string, new_string, replace_all, timeout=5
)
```

## Signal to Detect This Pattern

Status bar: `preparing patch…` for 2+ minutes → immediate Ctrl+C, the patch
is hanging in fuzzy matching (not in lint).

## Other Callers of fuzzy_find_and_replace

- `tools/file_operations.py::patch_replace()` ← primary, now has timeout=5
- `tools/skill_manager_tool.py:515` ← uses default timeout=5
- `tools/patch_parser.py:289, 522, 538` ← uses default timeout=5

All benefit from the default timeout.
