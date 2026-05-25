# Hermes Subagent Delegation Architecture

## How delegate_task Works

```
delegate_task(goal="...", context="...")
```

- `goal` → shown to user, used as spinner label, visible in subagent registry
- `context` → becomes the subagent's **system prompt** (prepended with "YOUR TASK:\n{goal}\n\nCONTEXT:\n{context}")

The subagent gets:
- Fresh conversation (no parent history)
- Own `task_id` (own terminal session, file ops cache)
- Restricted toolset (configurable, `delegate_task` itself is always blocked)
- Blocked tools: `delegate_task`, `clarify`, `memory`, `send_message`, `execute_code`

## Spawning Pattern

```python
# Step 1: Read the agent file
agent_file = read_file("references/agents/gsd-executor.md")

# Step 2: Inject into context
delegate_task(
  goal=f"Execute PLAN.md at {plan_path}. Commit each task. Create SUMMARY.md.",
  context=f"""{agent_file}

Project paths:
- PLAN.md: {plan_path}
- Phase dir: {phase_dir}
- STATE.md: .planning/STATE.md
- ./CLAUDE.md (if exists — follow project conventions)
"""
)
```

## Hermes Usage Block Format

Each agent file should have this at the top (after YAML frontmatter):

```markdown
## Hermes Usage (for delegate_task)

**How to spawn this agent:**
```
agent_file = read_file("references/agents/{name}.md")
delegate_task(
  goal="[specific task goal]",
  context=f"{agent_file}\n\nProject paths:\n- ..."
)
```

**Available tools:** Read, Write, Bash, Grep, Glob

**Expected output:**
- [concrete deliverables]
```

The `## Hermes Usage` block is a **documentation section** — it tells the AI how to call `delegate_task`, but the subagent itself runs on the full file content (both the Hermes block and the `<role>` block below).

## Claude Code vs Hermes Compatibility

| Feature | Claude Code | Hermes |
|---------|-----------|--------|
| Subagent API | `Task(subagent_type="...")` | `delegate_task(goal, context)` |
| Agent definition | `<role>` block + `<project_context>` | Full file content as context |
| Tool restriction | `tools:` in frontmatter | Via `role` toolset config |
| Hooks | `# hooks:` in frontmatter | Not supported (blocked tools instead) |

**Dual-compatibility strategy**: Keep the `<role>` block for Claude Code. Add `## Hermes Usage` for Hermes. The subagent receives the full file regardless of runtime.

## Which Agents to Delegate

**Delegate** (complex, multi-step, parallelizable):
- `gsd-executor` — plan execution with atomic commits
- `gsd-verifier` — goal-backward phase verification
- `gsd-planner` — plan creation with dependency analysis
- `gsd-debugger` — structured root cause analysis
- `gsd-phase-researcher` — technical research for a phase
- `gsd-codebase-mapper` — project structure analysis

**Do inline** (simple, 1-2 file, <5 min):
- One-file bug fixes
- Questions about state (answer from STATE.md directly)
- Quick discussions
- Simple refactors

## Key Files

- **Tool implementation**: `~/.hermes/hermes-agent/tools/delegate_tool.py` (2531 lines)
- **Agent files**: `references/agents/*.md` (16 files, all have `## Hermes Usage`)
- **Orchestrator commands**: `references/commands/execute-phase.md`, `plan-phase.md`
