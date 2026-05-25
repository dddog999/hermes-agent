#!/usr/bin/env python3
"""
从坚果云 USER.md 加载用户偏好到 Hermes 记忆系统（直接写 SQLite）
用法: python load-user-memory.py

每次运行会：
1. 读取 USER.md（按 § 分段）
2. 写入/更新 ~/.hermes/sessions/history.db 的 memory_entries 表
3. 重复运行会更新已有条目（key 相同时覆盖内容）

Cron 调度: */30 * * * * （每30分钟）
Gateway 启动钩子: 在 Hermes_Gateway.cmd 中启动 python 脚本
"""
import os, re, sqlite3
from datetime import datetime

# 路径配置（Windows 路径）
USER_MD = r"C:\Users\kangle\Nutstore\1\myNutstore (1)\hermes-sync\memories\USER.md"
SESSIONS_DB = r"C:\Users\kangle\AppData\Local\hermes\sessions\history.db"

def parse_user_md(path: str) -> list[dict]:
    """解析 USER.md，按 § 分段"""
    if not os.path.exists(path):
        print(f"USER.md not found: {path}")
        return []
    with open(path, encoding="utf-8") as f:
        content = f.read()
    sections = []
    for part in content.split("§"):
        part = part.strip()
        if not part:
            continue
        first_line = part.split("\n")[0].strip()
        first_line = re.sub(r"^[-*]\s+", "", first_line)
        sections.append({"key": first_line[:100], "content": part})
    return sections

def get_existing_keys(conn: sqlite3.Connection) -> set:
    try:
        cursor = conn.execute(
            "SELECT key FROM memory_entries WHERE target='user'"
        )
        return set(row[0] for row in cursor.fetchall())
    except Exception:
        return set()

def write_memory(conn: sqlite3.Connection, sections: list) -> int:
    existing = get_existing_keys(conn)
    count = 0
    for sec in sections:
        key, content, now = sec["key"], sec["content"], datetime.now().isoformat()
        if key in existing:
            conn.execute(
                "UPDATE memory_entries SET content=?, updated_at=? WHERE key=? AND target='user'",
                (content, now, key)
            )
        else:
            conn.execute(
                "INSERT INTO memory_entries (key, content, target, created_at, updated_at) VALUES (?, ?, 'user', ?, ?)",
                (key, content, now, now)
            )
        count += 1
    conn.commit()
    return count

def main():
    sections = parse_user_md(USER_MD)
    if not sections:
        return
    conn = sqlite3.connect(SESSIONS_DB)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS memory_entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            key TEXT UNIQUE NOT NULL,
            content TEXT NOT NULL,
            target TEXT NOT NULL DEFAULT 'user',
            created_at TEXT,
            updated_at TEXT
        )
    """)
    count = write_memory(conn, sections)
    conn.close()
    print(f"Synced {count} entries from USER.md")

if __name__ == "__main__":
    main()
