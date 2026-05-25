---
name: workflow-orchestration
description: "Workflow orchestration for task planning, execution, and delegation. Covers 4 sub-skills: (1) writing implementation plans (planning-with-files), (2) batch-executing plans (executing-plans), (3) kanban task decomposition and routing (kanban-orchestrator), and (4) kanban worker lifecycle and pitfalls (kanban-worker). Activate when: the user mentions project planning, task queues, kanban boards, multi-step workstreams, or you need to delegate bounded work to profiles."
---

# Workflow Orchestration

> Umbrella for planning, executing, and delegating multi-step work. Each sub-skill is a standalone surface-tool — read `references/<name>.md` for the full playbook before using it.

## When to Use This Umbrella

| Trigger | Sub-Skill to Load |
|---------|------------------|
| Write a plan / break down a task | `planning-with-files` |
| Execute a written plan in batches | `executing-plans` |
| Decompose into kanban tasks + fan-out | `kanban-orchestrator` |
| Debug a kanban worker / handle edge cases | `kanban-worker` |

---

## Sub-Skill 1 — planning-with-files (persistent task state)

**Use for:** Multi-step projects, research tasks, or any work requiring >5 tool calls.

- Create `task_plan.md`, `progress.md`, `findings.md`
- Auto-injected Claude Code hooks (PreToolUse / PostToolUse / Stop)
- Session recovery after `/clear`: check planning files, read git diff
- Full playbook: `references/planning-with-files.md`

## Sub-Skill 2 — executing-plans (batch plan execution)

**Use for:** You have a written plan and need to implement it in a separate session with review checkpoints.

- Load and review plan critically first; raise concerns before starting
- Execute tasks in batches (default: first 3), report for review between batches
- Skeleton: review → execute batch → report → continue → complete
- **REQUIRED SUB-SKILL:** superpowers:finishing-a-development-branch (for completion)
- Full playbook: `references/executing-plans.md`

## Sub-Skill 3 — kanban-orchestrator (decomposition + routing)

**Use for:** Multiple specialists needed; work should survive crash; fan-out for speed.

- **Step 0:** discover configured profiles (run `hermes profile list` first)
- Sketch task graph before creating any cards
- Use `parents=[...]` to gate children; do NOT create all cards then link later
- Anti-temptation rules: route, don't execute — always create a card, never do the work yourself
- Common patterns: fan-out+fan-in, parallel+validate, pipeline with gates, same-profile queue, human-in-the-loop
- Stuck worker recovery: `reclaim`, `reassign`, `change profile model`
- Full playbook: `references/kanban-orchestrator.md`

## Sub-Skill 4 — kanban-worker (worker pitfalls + edge cases)

**Use for:** You are the kanban worker and need deeper guidance on specific scenarios.

- `KANBAN_GUIDANCE` is auto-injected into every worker system prompt
- This skill covers: when to block, when to spawn, false-complete detection, reassignment vs. new task
- Full playbook: `references/kanban-worker.md`

---

## Reference Files

| 文件 | 来源 Sub-Skill | 主题 |
|------|---------------|------|
| `references/planning-with-files.md` | planning-with-files | persistent task state + session recovery |
| `references/executing-plans.md` | executing-plans | batch plan execution + review checkpoints |
| `references/kanban-orchestrator.md` | kanban-orchestrator | decomposition + routing + recovery |
| `references/kanban-worker.md` | kanban-worker | worker lifecycle + pitfalls |
