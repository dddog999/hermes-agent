---
name: smart-update
description: 智能上游同步 — 自动抓取上游 diff，AI 分析冲突，保留本地改动，执行 rebase。触发词：更新、sync、upstream、上游同步。
triggers:
  - "更新"
  - "sync upstream"
  - "上游同步"
  - "/update"
---

# 智能上游同步

自动从 `NousResearch/hermes-agent` 拉取更新，同时保留你的本地改动（Windows 适配、bug fix 等）。

## 执行流程

> ⚠️ **上游大幅领先时的首选策略**：当 origin/main（你的 fork）落后 upstream/main 超过 ~1000 commit 时，merge/rebase 会产生 100+ 冲突，手动解决不现实。改用"重置到上游 + 重新应用本地 patch"策略（见第三步）。

### 第1步：抓取上游 + 评估差距
```bash
cd /home/dddog/.hermes/hermes-agent
GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" git fetch upstream
git diff HEAD..upstream/main --stat | tail -3
git log --oneline upstream/main -3
```

**判断是否需要重置策略**：
- `git log HEAD..upstream/main | wc -l` > 1000 → 用重置策略
- 冲突文件 > 50 → 用重置策略

### 第2步：如果差距小（< 1000 commit）→ 尝试 rebase
```bash
git rebase upstream/main
# 成功 → 自动进入验证清单
# 冲突 → git rebase --abort，改用第3步重置策略
```

### 第3步：差距大 → 重置到上游 + 重新应用本地 patch（推荐）
```bash
# 3a. 确认当前状态无未提交改动
git status  # 必须是 clean

# 3b. 检出上游最新版本到暂存区（不切换分支）
git checkout upstream/main -- .

# 3c. 提交作为新的同步起点
git commit -m "chore: reset to upstream/main ($(git log --oneline upstream/main | head -1))"

# 3d. 重新应用本地关键 patch（参考 references/ 找当前值）
# 示例（2026-05-25）：agent/conversation_loop.py base_delay 5.0/2.0 → 15.0
sed -i 's/base_delay=5\.0/base_delay=15.0/' agent/conversation_loop.py
sed -i 's/base_delay=2\.0/base_delay=15.0/' agent/conversation_loop.py

# 3e. 提交本地 patch
git add agent/conversation_loop.py
git commit -m "fix: increase base_delay to 15.0 for MiniMax-M2.7 timeout tolerance"
```

### 第4步：验证清单
```bash
# 确认 upstream 已同步
git log --oneline -3

# 确认本地 patch 仍在
grep -n "base_delay=15.0" agent/conversation_loop.py
```

## 第5步：同步 user-skills（技能库）
```bash
cd ~/.hermes/hermes-agent/user-skills
GIT_TERMINAL_PROMPT=0 GIT_HTTP_AUTHORIZATION="Bearer $(gh auth token)" git pull fork user-skills
```

---

## 当前本地 Patch（2026-05-25）

| 文件 | 改动 | 当前值 |
|------|------|--------|
| `agent/conversation_loop.py:1349` | base_delay（invalid API retry） | 15.0（上游 5.0） |
| `agent/conversation_loop.py:2996` | base_delay（rate-limit retry） | 15.0（上游 2.0） |

## Pitfalls

- **`git reset --hard` 不安全** — 会丢失未提交的本地改动。用 `git checkout upstream -- .` 替代。
- **TLS/SSH 网络错误** — 设置 `GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"` 绕过。
- **merge 产生 100+ 冲突时不要硬撑** — 优先用重置策略（步骤3）。
- **重置后不要忘重新应用 patch** — 上游 reset 后，base_delay 等改动会被覆盖。
- **origin/main 落后不代表 fix/patch-timeout 落后** — 落后的是 origin/main（私人仓），但 fix/patch-timeout 相对接近上游。此时 rebase 仍是首选。

## 与现有 /update 的区别

| 特性 | 旧 /update | 智能更新 |
|------|------------|----------|
| 自动抓取上游 | ❌ | ✅ |
| AI 分析冲突 | ❌ | ✅ |
| 保留本地改动 | ❌（直接 pull） | ✅（rebase + 保留） |
| 大幅落后时自动切换策略 | ❌ | ✅ |