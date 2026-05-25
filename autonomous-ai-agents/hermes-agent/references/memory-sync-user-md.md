# Hermes Memory Sync — USER.md → SQLite

## Problem
Hermes `memory` tool is session-scoped; there is no built-in `hermes load-memory-from-file` command.

## Solution: Direct SQLite Write

Script: `~/.hermes/scripts/load-user-memory.py`

This script:
1. Reads `USER.md` from Nutstore sync directory
2. Parses it by `§` section delimiters
3. Writes each section as a `memory_entries` row (target='user')
4. Next run updates existing entries by key (no duplicates)

```python
# Key snippet: write to memory_entries table
conn.execute("""
    INSERT INTO memory_entries (key, content, target, created_at, updated_at)
    VALUES (?, ?, 'user', ?, ?)
""", (key, content, now, now))
# On duplicate key: UPDATE instead (upsert pattern)
```

**Cron job** (ID: `d81c0d559662`): every 30 minutes, via `hermes cron create --no-agent --script load-user-memory.py --schedule "*/30 * * * *"`

## Gateway Startup Sync
To sync on gateway boot, add to `gateway-service/Hermes_Gateway.cmd` BEFORE the `gateway run` line:
```batch
C:\Users\kangle\AppData\Local\hermes\hermes-agent\venv\Scripts\python.exe C:\Users\kangle\.hermes\scripts\load-user-memory.py
```

## Files
- Script: `C:\Users\kangle\.hermes\scripts\load-user-memory.py`
- Source USER.md: `C:\Users\kangle\Nutstore\1\myNutstore (1)\hermes-sync\memories\USER.md`
- Sessions DB: `C:\Users\kangle\AppData\Local\hermes\sessions\history.db`
