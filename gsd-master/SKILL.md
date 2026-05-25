---
name: gsd-master
description: GSD (Get Shit Done) structured project management — the ONE way to handle ANY software development work. Activate immediately when: the user mentions building/creating/modifying a project, writes code across multiple files, encounters a bug to fix, asks about project progress, says "plan", "execute", "roadmap", "phase", or any development workflow. Also activates on /gsd:xxx or /gsd-xxx commands. Even if the user doesn't use the word "project" — if they're doing software work, this skill is your default mode. Do NOT do ad-hoc coding without checking if a GSD project exists first.
allowed-tools:
disable: false
context_hook: |
  ## 【GSD CONTEXT HOOK — 每次回复前必须处理】
  
  1. 运行: `if [ -f ".planning/STATE.md" ]; then cat .planning/STATE.md; fi`
  2. 如果存在 STATE.md:
     - 提取 frontmatter: phase=X, current_plan=Y, milestone=Z
     - 在回复开头必须标注: 【GSD Phase X | Plan: Y | Milestone: Z】
     - 读取 ROADMAP.md 当前阶段行: `grep -A2 "in_progress" .planning/ROADMAP.md | head -5`
     - 如果有任何 blocker: 在回复中标注 【阻塞: ...】
  3. 如果 .planning 不存在:
     - 标注: 【GSD未激活】— 对任何多文件编程任务主动建议建立GSD项目
  4. 漂移检查: 你的上3条消息是否偏离了当前 phase/plan？
     - 如果是: 立即停止，标注【漂移警告】，回到当前plan
  5. 当前 turn 数是否 >= 3？
     - 如果是: 强制 re-anchor — 重新读 STATE.md 和当前 PLAN.md 的 task 列表
context_decay_threshold: 3
maintenance_trigger:
  after:
    - tool: terminal
      patterns: ["git commit", "git add", "npm install", "pip install"]
      action: "检查是否在当前phase的plan中，记录到STATE.md"
    - tool: read_file
      patterns: [".planning/STATE.md", ".planning/phases/*/PLAN.md"]
      action: "更新Active Project Memory，确保当前phase/plan在context中"
---

# GSD Master

GSD (Get Shit Done) is a spec-driven development system for structured, accountable software projects. It replaces ad-hoc coding with phase-based workflows, mandatory documentation, and state tracking.

---

## CRITICAL: Active Project Context (Always Check First)

Before responding to ANY software development request, execute this check:

```bash
if [ -d ".planning" ]; then
  if [ -f ".planning/STATE.md" ]; then
    echo "GSD_ACTIVE_PROJECT=true"
    head -5 .planning/STATE.md
    head -3 .planning/ROADMAP.md 2>/dev/null || echo "ROADMAP_MISSING"
  else
    echo "GSD_PARTIAL=.planning exists but no STATE.md"
  fi
else
  echo "GSD_NO_PROJECT=true"
fi
```

### Routing Based on Check

| Result | What to do |
|--------|-----------|
| `GSD_ACTIVE_PROJECT=true` | You ARE in an active GSD project. Load STATE.md + current phase context. ALL work must be routed through GSD commands. Do not write code outside of GSD phase/plans. |
| `GSD_PARTIAL` | Partial GSD structure found. Ask user: "A GSD project was started but not finished. Resume with `/gsd-progress` or abandon and start fresh?" |
| `GSD_NO_PROJECT` | No GSD project. For any non-trivial coding task, PROACTIVELY suggest using GSD. Say: "I see no GSD project structure. For structured development, I recommend `/gsd-new-project` — want me to set that up first?" |

---

## Core Principle: Never Work Ad-Hoc in an Active Project

Once `GSD_ACTIVE_PROJECT=true`, the following rules are ABSOLUTE:

1. **Every piece of work must map to a phase/plan.** If the user asks for something off-plan, say: "That's not in the current phase plan. Should I note it as a backlog item, or adjust the plan first?"
2. **After every significant action, update the active document.** Don't just do work — record what you did, what decisions you made, and what changed.
3. **If you realize you're drifting from the plan**, stop and either align with the plan or propose a plan adjustment explicitly.
4. **If unsure about project state, run `/gsd-progress` first.**

---

## Intent Recognition

### Mode A: Command Format (Highest Priority)

Match patterns: `/gsd:xxx`, `/gsd-xxx`, `gsd:xxx`, `gsd-xxx`

```
/gsd-new-project          → references/commands/new-project.md
/gsd-plan-phase 1         → references/commands/plan-phase.md (phase=1)
/gsd-execute-phase        → references/commands/execute-phase.md
/gsd-progress             → references/commands/progress.md
/gsd-verify-work          → references/commands/verify-work.md
/gsd-diagnose-issues      → references/commands/diagnose-issues.md
/gsd-discuss-phase 2      → references/commands/discuss-phase.md (phase=2)
/gsd-pause-work           → references/commands/pause-work.md
/gsd-resume-project       → references/commands/resume-project.md
/gsd-quick                → references/commands/quick.md
```

### Mode B: Natural Language → GSD Command Mapping

| User says (CN or EN) | Triggered command | When to use |
|---------------------|-------------------|-------------|
| "新项目", "start project", "create new" | new-project.md | No .planning/ exists |
| "计划", "plan phase", "roadmap", "phase" | plan-phase.md | Need to plan next phase |
| "执行", "execute", "implement", "build it" | execute-phase.md | Plans exist, time to code |
| "进度", "progress", "where are we", "现在进度" | progress.md | Check current state |
| "debug", "fix bug", "调试", "解决问题" | diagnose-issues.md | Something is broken |
| "verify", "test", "验收", "uat" | verify-work.md | Verify completed work |
| "暂停", "pause", "保存状态" | pause-work.md | Save and pause work |
| "恢复", "resume", "继续" | resume-project.md | Resume paused work |
| "quick", "fast", "simple task" | quick.md | Small off-plan task |

---

## Bug Reports: Lightweight Diagnosis (No Project Required)

When the user reports a bug/error WITHOUT an active GSD project, do NOT just give commands. Follow this lightweight diagnosis flow instead of ignoring the error or over-engineering:

**Step 1: Classify the error type**
```
- SyntaxError / TypeError / ImportError → likely code issue
- Cannot find module / ModuleNotFoundError → likely dependency issue
- Network error / ECONNREFUSED / timeout → environment/infra issue
- Build error (npm build / make / etc.) → build system issue
- Runtime crash / segmentation fault → logic/memory issue
- Permission denied / access control → permission/environment issue
```

**Step 2: Quick diagnosis questions** (ask only if ambiguous)
- "这个错误是第一次出现还是之前也有？"
- "最近改过什么相关代码？"
- "能贴一下完整的错误堆栈吗？"

**Step 3: Give targeted fix with explanation**
- DON'T just say `npm install xyz` or `pip install x`
- Explain WHY: "这个错误是因为缺少 @babel/preset-env，通常用 `npm install --save-dev @babel/preset-env` 解决"

**Step 4: Offer GSD if the bug needs deeper investigation**
- "如果这个bug需要系统化调试，可以用 `/gsd-new-project` 建立项目结构，然后用 `/gsd-diagnose-issues` 做完整分析。"

This lightweight flow handles 80% of bug reports without requiring full GSD project overhead.

---

## Execution Flow

1. **Run the context check** (the bash snippet above) — ALWAYS, before anything else
2. **Parse command** from user input or extract from natural language
3. **Read the command file** from `references/commands/{command}.md`
4. **Follow the workflow** in that command file exactly
5. **Run maintenance** — update STATE.md / create SUMMARY.md after completing the workflow
6. **Route next action** — present the appropriate next command to the user

---

## Subagent Delegation (When to Spawn)

GSD has 13 specialized subagent types in `references/agents/`. Use `delegate_task` to spawn them when:

| Situation | Spawn This Agent |
|-----------|-----------------|
| Writing code for a plan | `gsd-executor` — reads PLAN.md, commits atomically |
| Verifying phase completion | `gsd-verifier` — goal-backward verification |
| Debugging complex issues | `gsd-debugger` — structured root cause analysis |
| Planning a phase | `gsd-planner` — plan creation with dependency analysis |
| Understanding unfamiliar code | `gsd-codebase-mapper` — maps project structure |
| Checking integration across phases | `gsd-integration-checker` |
| UI implementation work | `gsd-ui-researcher` / `gsd-ui-checker` / `gsd-ui-auditor` |

**How to delegate** (read agent file, inject as context):

```
When spawning a GSD subagent, read the agent file first:
  Read: references/agents/{agent-name}.md
  Then call: delegate_task(goal="...", context="[full content of the agent file + project paths]")

Example:
  agent_file = read_file("references/agents/gsd-executor.md")
  delegate_task(
    goal=f"Execute PLAN.md at {plan_path}. Commit each task. Create SUMMARY.md.",
    context=f"You are a GSD executor.\n\n{agent_file}\n\nProject paths:\n- PLAN.md: {plan_path}\n- Phase dir: {phase_dir}\n- STATE.md: {state_path}"
  )
```

**CRITICAL: When NOT to delegate**
- Simple 1-2 file edits (do inline)
- Questions about project state (answer from STATE.md/ROADMAP.md directly)
- Bug reports that are clearly one-file issues
- Any task that takes <5 minutes

---

## Post-Action Maintenance (Mandatory After Every Workflow)

After completing ANY GSD workflow (plan, execute, verify, debug, etc.), run these maintenance steps before presenting the final response:

```bash
# Check if STATE.md needs updating
if [ -f ".planning/STATE.md" ]; then
  node "scripts/gsd-tools.cjs" state-snapshot 2>/dev/null | head -20
fi

# Check if current phase has uncommitted changes
ls .planning/phases/*/phase.md 2>/dev/null | head -3
```

**If a phase just completed** (all plans have summaries): Prompt the user:
```
Phase [N] is complete. Run `/gsd-verify-work [N]` for acceptance testing, or `/gsd-progress` to see what's next?
```

**If new decisions were made**: Record them in STATE.md under `decisions[]`:
```bash
node "scripts/gsd-tools.cjs" state-add-decision "described the decision made" 2>/dev/null || manual append to STATE.md
```

**If new blockers surfaced**: Record them in STATE.md under `blockers[]`.

---

## Active Project Memory (Persists Across Turns)

When `GSD_ACTIVE_PROJECT=true`, maintain this context across ALL responses in the conversation:

**Current Phase**: Read from ROADMAP.md — which phase number is "in_progress"?
**Current Plan**: Look for PLAN.md files without matching SUMMARY.md in the current phase directory.
**What We Did Last**: Read the most recent SUMMARY.md to know recent accomplishments.
**Key Decisions**: Keep a mental note of `decisions[]` from STATE.md.
**Blockers**: Note any `blockers[]` from STATE.md.

**Every time you respond**, briefly anchor to this context:
- "Continuing Phase 3, Plan B: [brief goal]"
- or "No active phase — we're at [milestone] milestone, Phase [N] not started yet"

This prevents the most common drift: forgetting which phase/plan you're in mid-conversation.

---

## Command Reference

All commands live in `references/commands/`. Read the specific command file before executing.

| Category | Commands |
|----------|---------|
| **Project** | new-project, new-milestone, complete-milestone, map-codebase |
| **Planning** | discuss-phase, plan-phase, research-phase, add-phase, insert-phase, remove-phase, transition, discovery-phase |
| **Execution** | execute-phase, execute-plan, quick, do, fast |
| **Verification** | verify-work, verify-phase, validate-phase, ui-phase, ui-review, review |
| **Debug** | diagnose-issues, health, node-repair |
| **Navigation** | progress, stats, help, next, pause-work, resume-project |
| **Todos** | add-todo, check-todos, note, add-tests |
| **Workflow** | autonomous, cleanup, settings, update, profile-user, session-report, plant-seed, pr-branch, list-phase-assumptions, plan-milestone-gaps |

For full list: `references/commands/help.md`

---

## Project Structure

```
project/
├── .planning/
│   ├── PROJECT.md        # Project context (goals, scope, constraints)
│   ├── REQUIREMENTS.md   # Requirements
│   ├── ROADMAP.md        # Phase roadmap
│   ├── STATE.md          # Current state (phase, decisions, blockers, todos)
│   ├── config.json       # Settings
│   └── phases/
│       ├── 1-context/    # Phase 1 context files
│       ├── 1-PLAN-*.md   # Phase 1 plans
│       ├── 1-SUMMARY-*.md # Phase 1 execution summaries
│       └── 1-UAT.md      # Phase 1 acceptance tests
└── ... (project code)
```

---

## Templates & Scripts

Templates: `references/templates/` (project.md, requirements.md, roadmap.md, UAT.md, DEBUG.md, codebase/, research-project/)
CLI tools: `scripts/gsd-tools.cjs` — init, roadmap analyze, state snapshot, commit, summary-extract, etc.
Agent types: `references/agents/` — gsd-executor, gsd-planner, gsd-verifier, gsd-debugger, gsd-codebase-mapper, etc.

---

## Quick Reference

| User says | Action |
|-----------|--------|
| "开始一个新项目" | Check .planning → if missing: read `references/commands/new-project.md` |
| "计划第一阶段" | Check .planning → read `references/commands/plan-phase.md` (phase=1) |
| "执行计划" | Check .planning → read `references/commands/execute-phase.md` |
| "调试这个问题" | Check .planning → read `references/commands/diagnose-issues.md` |
| "现在进度" | Check .planning → read `references/commands/progress.md` |
| "恢复上次工作" | Check .planning → read `references/commands/resume-project.md` |
| "暂停工作" | Check .planning → read `references/commands/pause-work.md` |

---

## Drift Prevention Checklist (ABSOLUTE — 零容忍)

**强制规则：在活跃项目中，每条回复必须：**
1. **开头标注** — 【GSD Phase X | Plan: Y | Milestone: Z】
2. **3轮对话后** — 必须重新读取 STATE.md + 当前PLAN.md
3. **执行代码前** — 确认当前任务在当前 plan 的 TODO 列表中
4. **用户提出新需求时** — 检查是否在当前 phase 范围内

**漂移检测（满足任何一条 = 漂移）：**

| 触发条件 | 含义 | 强制行动 |
|---------|------|----------|
| 回复没有【GSD Phase X】开头 | 忘记上下文 | 立即停止，重读 STATE.md |
| 3轮以上没有读 STATE.md | 上下文衰减 | 强制重读 STATE.md + ROADMAP.md |
| 写了不在 PLAN.md 中的代码 | 脱离计划 | 停止，告知用户："我偏离了计划" |
| 做了不在 requirements 中的架构决策 | 范围蔓延 | 停止，与用户确认 |
| 用户中途提出新需求 | 可能转向 | 检查是否应该在当前 phase |

**发现漂移后必须做的3件事：**
1. 立即停止当前工作
2. 告知用户："【漂移警告】我刚才在做 X，但这不在当前计划中"
3. 提供选项："应该我把它加入backlog，还是调整当前计划？"

**"Continuing Phase N" 不是可选项 — 是强制规则。如果写不出这句话，说明你迷失了，立即重读项目文件。**

---

## 项目上下文维护（跨轮对话持久化）

在活跃项目中，维护以下上下文（每次回复都回顾）：

**当前阶段**: 从 ROADMAP.md 读取 — 哪个 phase 是 "in_progress"？
**当前计划**: 在阶段目录中找没有 SUMMARY.md 的 PLAN.md
**最近做了什么**: 读最近的 SUMMARY.md 了解近期成果
**关键决策**: 记住 STATE.md 中的 `decisions[]`
**阻塞项**: 注意 STATE.md 中的 `blockers[]`

**每次回复时，简短锚定到此上下文：**
- "Continuing Phase 3, Plan B: [简要目标]"
- 或 "No active phase — 处于 [milestone] 里程碑，Phase [N] 尚未开始"

这能防止最常见的漂移：多轮对话后忘记自己在哪个 phase/plan。
