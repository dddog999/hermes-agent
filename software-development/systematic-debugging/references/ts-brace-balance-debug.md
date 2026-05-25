# TypeScript/JavaScript Brace Balance Debugging

## The Problem

TypeScript compiler error `TS1005: '}' expected` at a late line (e.g., line 1764 of 1763) often means **unbalanced braces or parentheses earlier in the file**, not at the reported line. The compiler doesn't know where the block opened, so it reports where it gave up parsing.

**Key signal**: Error line number equals or exceeds total line count → root cause is upstream.

## The Python Debugging Script

```python
#!/usr/bin/env python3
"""Track brace/parens balance in TS/JS files, skipping string literals and template literals."""

import sys

def check_balance(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    lines = content.split('\n')
    
    in_string = False       # double-quoted strings
    in_template = False     # backtick template literals
    escape_next = False
    balance = 0
    changes = []
    
    for line_num, line in enumerate(lines, 1):
        orig_balance = balance
        for c in line:
            if escape_next:
                escape_next = False
                continue
            if c == '\\':
                escape_next = True
                continue
            if c == '`' and not in_string:
                in_template = not in_template
                continue
            if c == '"' and not in_template:
                in_string = not in_string
                continue
            if not in_template and not in_string:
                if c == '{':
                    balance += 1
                    changes.append((line_num, '+1', line.strip()[:60]))
                elif c == '}':
                    balance -= 1
                    changes.append((line_num, '-1', line.strip()[:60]))
    
    print(f"File: {filepath}")
    print(f"Total lines: {len(lines)}")
    print(f"Final balance: {balance} (should be 0)")
    print(f"\nAll balance changes:")
    for ln, delta, snippet in changes:
        print(f"  Line {ln:4d} [{delta}]: {snippet[:55]}")
    
    if balance != 0:
        print(f"\n⚠️  UNBALANCED — {balance} unclosed block(s)")
        return 1
    return 0

if __name__ == '__main__':
    sys.exit(check_balance(sys.argv[1]))
```

## When to Use

1. `npx tsc --noEmit` fails with `TS1005` at end of file
2. Simple `grep -c '{' file.ts` vs `grep -c '}' file.ts` shows imbalance
3. File has mixed CRLF/LF line endings (can throw off simple char counts)
4. Large files where the unclosed block could be anywhere

## Usage

```bash
python3 ts-brace-debug.py src/cli/index.ts
```

## Common Causes of False Negatives in Simple Brace Counting

| Cause | Simple Count | This Script |
|-------|-------------|-------------|
| Strings containing `{` or `}` | Counted as braces | Skipped |
| Template literals with `${}` | Counted as braces | Skipped |
| Escaped characters `\{` | Counted as braces | Skipped |
| Single-quoted strings | Usually OK | Skipped |
| Comments `// { }` | Usually OK | Skipped (line comments) |

**Note**: This script does NOT skip single-quoted strings or `//` comments — extend if needed.

## Real Case

- **File**: `src/cli/index.ts` (1763 lines)
- **Error**: `TS1005: '}' expected at line 1764`
- **Simple count**: 553 opens, 551 closes → diff of 2 (misleading, strings contain braces)
- **Script result**: Balance of 1, unclosed at line 186
- **Root cause**: `.action(async (contentParts: string[], options: { ... })` — the `.action(` call was never closed with `)`
