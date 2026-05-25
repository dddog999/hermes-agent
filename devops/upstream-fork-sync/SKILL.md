---
name: upstream-fork-sync
description: 维护 Git fork 与上游（upstream）同步的工作流 — 保留本地改动、自动同步、冲突处理。适用于在 fork 上做长期开发（如 bug fix、功能增强）并持续跟进源仓库的场景。
triggers:
  - "fork 上游同步"
  - "保留我的改动同时从源仓库更新"
  - "automatically sync fork with upstream"
  - "maintain fork while keeping local patches"
  - "更新"
  - "同步上游"
  - "/update"
  - "GenericAgent"
---

# Fork 上游同步工作流

在 fork 上持续开发时，需要从源仓库（upstream）拉取更新，同时保留自己的改动。

## 初始配置

```bash
# 添加上游 remote（只需一次）
git remote add upstream https://github.com/NousResearch/hermes-agent.git
git remote -v
```

## 同步策略：Rebase（AI 辅助，保留本地改动）

**为什么用 rebase 而非 merge：**
- Rebase 让你的提交"看起来"是基于最新上游代码写的
- 保持提交历史线性，容易回溯
- 你的改动（如 Windows 适配）保持在最上面
- **AI 辅助分析 diff，自动给出合并建议**

```bash
# AI 辅助 rebase 流程（4步）
# 由 Hermes Agent 自动执行：

# 第1步：抓取上游 diff
git fetch upstream
git diff HEAD..upstream/main --stat  # 看看哪些文件被改了

# 第2步：AI 对比你改过的文件列表
# 你改过的文件（示例）：
# - run_agent.py (retry 退避时间)
# - agent/auxiliary_client.py (provider fallback)
# - agent/context_compressor.py (LLM fallback)
# - gateway/run.py (session title fallback)
# - gateway/platforms/feishu.py (@mention 修复)
# - hermes_cli/pty_bridge.py (PTY 适配)

# 第3步：AI 逐文件分析，给出合并建议
# 示例输出：
# ⚠️ 冲突预警：
#   run_agent.py：
#     你的改动：第 123 行 retry 退避时间
#     上游改动：同区域新增了 retry 次数限制
#     建议：保留你的退避时间，同时合并上游的次数限制

# 第4步：用户确认后，执行 rebase + 解决冲突
git rebase upstream/main
# 如果有冲突，AI 辅助解决：
#   - 读取冲突文件
#   - 保留你的改动逻辑
#   - 合并上游新功能
#   - git add <file> && git rebase --continue
```

## 自动同步（Cronjob 模式）

通过 Hermes cronjob 实现每天自动同步：

```json
{
  "name": "上游同步",
  "schedule": "0 3 * * *",
  "workdir": "/path/to/repo",
  "enabled_toolsets": ["terminal"],
  "prompt": "你是上游同步助手。步骤：1. cd /path/to/repo 2. git fetch upstream 3. 检查新 commit 数量 4. 如果无新 commit 则结束 5. 如果有新 commit：git rebase upstream/main，如果成功则 git push fork BRANCH，如果失败则 git rebase --abort + 发送通知"
}
```

### 自动同步完整流程（Merge 策略版 — 适用于保留长期分支）

对于在 fork 分支上做长期开发（如 `fix/patch-timeout`），推荐使用 merge 而非 rebase，以避免反复重写历史：

```bash
# 第1步：检查当前分支和工作区
git branch --show-current          # 确认在目标分支
git status                         # 检查是否有未提交改动
git stash --include-untracked      # 如果有，stash 包括未跟踪文件

# 第2步：获取上游更新
git fetch upstream

# 第3步：检查是否有新 commit
git log --oneline HEAD..upstream/main | wc -l  # 数量>0 则有新内容
git log --oneline HEAD..upstream/main | head -10

# 第4步：查看改动统计 + 关注的关键文件
git diff --stat HEAD..upstream/main | tail -1
git diff HEAD..upstream/main -- agent/auxiliary_client.py agent/context_compressor.py

# 第5步：合并上游
git merge upstream/main
# 成功：继续
# 冲突：git merge --abort + git stash pop + 通知人工

# 第6步：恢复 stash（如果之前 stash 了）
git stash pop

# 第7步：推送
git push fork BRANCH_NAME  # ⚠️ 注意：要推送到 fork，不是 origin！
```

关键逻辑：
- 先 `git fetch` 检查是否有更新
- 无冲突自动 merge + push
- 有冲突中止 merge + Telegram 通知（附冲突文件列表）
- Merge 策略不会改写历史，适合多人协作的分支

## 冲突处理

```bash
# 查看冲突文件
git diff --name-only HEAD..upstream/main

# 中止问题 rebase
git rebase --abort

# 手动合并策略：
# 1. 先 rebase --no-commit，查看冲突
git rebase --no-commit upstream/main

# 2. 对每个冲突文件，决定保留哪边：
git checkout --theirs path/to/file    # 保留上游版本
git checkout --ours path/to/file      # 保留你的版本

# 3. 完成合并
git add -A
git rebase --continue
```

## 本地改动清单（示例）

如果你的 fork 上有这些类型的改动，合并时需注意：

| 改动类型 | 冲突风险 | 处理建议 |
|---------|---------|---------|
| Bug fix（数值调整） | 低 | 自动合并，验证即可 |
| 新增函数/方法 | 中 | 检查上游是否改了同一区域 |
| 大范围重构（如 feishu.py） | 高 | 准备手动解决冲突 |
| Debug 日志 | 低 | 自动合并 |

## 验证清单

合并后运行：
```bash
# 1. 确认你的改动还在
git diff HEAD~1 -- your_modified_file.py

# 2. 运行测试（如果项目有）
scripts/run_tests.sh

# 3. 手动验证功能
```

## Pitfalls

- **不要直接在 main 分支改** — 始终在自己的分支（如 `fix/xxx` 或 `feat/xxx`）上工作
- **Stash 后记得 pop** — 忘了恢复 stash 会导致改动丢失
- **Cronjob 的 max_iterations** — AI agent 做同步时可能受限于迭代次数，复杂合并可能需要手动介入
- **Force push 要小心** — `git push --force-with-lease` 比 `--force` 安全，但仍需确认
- **Rebase 前备份** — `git checkout -b backup/pre-rebase-$(date +%Y%m%d)` 先备份再 rebase
- **AI 分析 diff 时注意** — 上游可能删除了你的改动（如 auxiliary_client.py fallback），需要手动恢复
- **Remote 推送目标** — `origin` remote 的 push URL 可能指向 upstream，必须用 `fork` remote 推送：`git push fork BRANCH`
- **WSL+Tailscale DNS 劫持** — Tailscale DNS (100.100.100.100) 劫持 github.com 到 198.18.x.x（CIPA内网段），导致 HTTPS TLS 握手失败 + SSH 连接被重置。解法：`git remote set-url --push origin https://github.com/owner/repo.git`（HTTPS走token认证，不走SSH）；fetch 仍需 `GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" git fetch upstream`
- **Large repo reset timeout** — `git reset --hard upstream/main` on repos with 1000+ files times out and gets BLOCKED by terminal. Use `git checkout <commit> -- .` to stage all files, then `git commit` to create an equivalent snapshot. This avoids the massive file write that reset triggers.
- **Merge 冲突过多时换策略** — 当 origin/main 落后 upstream/main 数以千计的 commit 时，`git merge` 会产生 100+ 冲突。优先用 `checkout + commit` 策略（先重置到干净上游，再手动恢复 2-3 个关键改动），而非花时间解决 100+ 冲突
- **Origin/main 落后判断** — 用 `git merge-base HEAD upstream/main` 对比 HEAD 与 upstream 的共同祖先。如果 merge-base 是更早的 commit（而非 HEAD 或 upstream），说明两边各自有独立推进，需谨慎选择 merge 策略
- **PAT 缺少 workflow scope** — 如果 push 被 `.github/workflows/` 文件拒绝，参考 `references/push-workflow-scope-pitfall.md` 恢复
- **Stash 未跟踪文件** — 切换分支时如果未跟踪文件冲突，用 `git stash --include-untracked` 而非普通 `git stash`
- **合并冲突保留两者** — 当上游和本地各自新增不同方法时，手动编辑冲突文件保留两个方法
- **上游新增重叠功能（Wrapper Pattern 冲突）** — 当你的 fork 用独立文件包装上游文件（如 `cli.py` 包装 `agentmain.py`），上游更新后可能在同一文件里加入了你的同类功能。此时需要把上游文件回退到重叠之前的版本。用 `git show <commit>:<filepath>` 提取历史文件：`git show <commit>:<filepath> > filepath`。例如：源头 `agentmain.py` 新增了 CLI 代码，但本 fork 想保持 `cli.py` 独立 → 找最后一个无 CLI 的 commit（如 `6091bf0`），`git show 6091bf0:agentmain.py > agentmain.py` 回退。注意：用 `git checkout <commit>:<filepath>` 会报 `fatal: reference is not a tree`，必须用 `git show` 重定向。

## 智能更新触发词

在 Hermes 对话中输入以下任一词，触发 AI 辅助同步：
- **"更新"**
- **"同步上游"**  
- **"/update"**
- **"upstream sync"**

Hermes 会自动执行：
1. `git fetch upstream` 抓取最新代码
2. AI 分析 diff，标注冲突文件
3. 给出逐文件合并建议（保留你的改动）
4. 执行 rebase（经你确认）

---
