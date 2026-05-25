# Cross-Runtime Skill Adaptation

When adapting a skill from another runtime (Claude Code, Copilot, Codex, etc.) to Hermes, three file types have different compatibility requirements.

---

## File Type Compatibility Matrix

| File type | Claude Code format | Hermes compatible? | What to do |
|-----------|-------------------|-------------------|------------|
| **Agent files** (`references/agents/*.md`) | YAML frontmatter + `<role>` + `<project_context>` | ✅ Yes, with addition | Add `## Hermes Usage` block |
| **Command files** (`references/commands/*.md`) | `<purpose>`, `<required_reading>`, `<step>`, `@filepath`, `Task()` calls | ⚠️ Partial | Read as reference; AI executes manually |
| **Workflow files** (`scripts/workflows/*.md`) | Orchestrator pattern with `@filepath` and conditional spawns | ❌ No | Read as reference docs only |
| **CLI scripts** (`scripts/*.cjs`, `scripts/lib/*.cjs`) | Node.js, hardcoded paths like `~/.agents/skills/` | ✅ Works via symlink | Symlink `~/.agents/skills/` → `~/.hermes/skills/` |

---

## Agent Files: Add `## Hermes Usage`

Agent files are the most reusable across runtimes. After the YAML frontmatter and before the `<role>` block, add:

```markdown
## Hermes Usage (for delegate_task)

**How to spawn this agent:**
```
agent_file = read_file("references/agents/{agent-name}.md")
delegate_task(
  goal="[specific task description]",
  context=f"{agent_file}\n\nProject paths:\n- [relevant file paths]"
)
```

**Available tools:** [list]

**Expected output:** [what the agent produces]

---

## Command Files: Reference + Manual Execution

Command files describe complex workflows. Hermes cannot execute the orchestrator pattern (`<step>`, `@filepath`, conditional `Task()` spawning), but AI can read them as structured guidance and execute the bash commands manually.

**Pattern in command files that won't auto-execute:**
```bash
# These work:
node "scripts/gsd-tools.cjs" init plan-phase "$PHASE"
git checkout -b "$BRANCH_NAME"

# These don't (Claude Code syntax):
Task(subagent_type="gsd-executor", prompt="...")
INIT=$(node "@../scripts/gsd-tools.cjs" init ...)
```

**Rule:** `@filepath` references don't resolve in Hermes. The AI must manually read referenced files with the `Read` tool.

**Correct pattern for Hermes:**
```
1. Read the command file for structured guidance
2. Read referenced files manually: read_file("references/...")
3. Execute bash commands directly (no @filepath)
4. Execute workflow logic manually (no Task() spawning)
```

---

## CLI Scripts: Hardcoded Path Workaround

Many CLI scripts hardcode paths like `~/.agents/skills/<skill-name>/`. In Hermes, skills live at `~/.hermes/skills/<skill-name>/`.

**Solution:** Create a symlink so the hardcoded path resolves correctly:

```bash
# Create symlink if it doesn't exist
mkdir -p ~/.agents/skills
ln -sfn ~/.hermes/skills/<skill-name> ~/.agents/skills/<skill-name>
```

After the symlink exists, scripts using `~/.agents/skills/<skill-name>/scripts/gsd-tools.cjs` will resolve to `~/.hermes/skills/<skill-name>/scripts/gsd-tools.cjs`.

**Verify:** `ls -la ~/.agents/skills/<skill-name>/scripts/` should show the actual script files (not a broken link).

---

## Workflow Files: Read as Documentation Only

Workflow files (e.g., `scripts/workflows/execute-plan.md`) use the Claude Code orchestrator pattern:

```markdown
<step name="step_name">
<objective>
...
</objective>

Task(
  subagent_type="gsd-executor",
  prompt="..."
)
</step>
```

**Hermes cannot execute this.** The `<step>` blocks and `Task()` calls are inert — Hermes AI reads the file but has no mechanism to parse and execute these constructs.

**What Hermes CAN do:**
- Read the workflow file as a human would
- Understand the intended sequence of operations
- Execute equivalent actions using its own tools

**What Hermes CANNOT do:**
- Automatically parse `<step>` blocks
- Spawn subagents via `Task(subagent_type="...")`
- Use `@filepath` references

**Best practice:** For complex workflows, create a **simplified command file** (plain markdown with numbered steps and bash commands) that Hermes AI can read and follow literally.

---

## Example: Adapting a Claude Code Skill to Hermes

**Before (Claude Code format — agent file):**
```markdown
---
name: gsd-executor
description: Executes GSD plans with atomic commits...
tools: Read, Write, Edit, Bash, Grep, Glob
---

<role>
You are a GSD plan executor...
Spawned by `/gsd:execute-phase` orchestrator.
Your job: Execute the plan completely...
```

**After (Hermes-compatible):**
```markdown
---
name: gsd-executor
description: Executes GSD plans with atomic commits...
tools: Read, Write, Edit, Bash, Grep, Glob
---

## Hermes Usage (for delegate_task)

**How to spawn this agent:**
```
agent_file = read_file("references/agents/gsd-executor.md")
delegate_task(
  goal=f"Execute PLAN.md at {plan_path}. Commit each task. Create SUMMARY.md.",
  context=f"{agent_file}\n\nProject paths:\n- PLAN.md: {plan_path}\n- STATE.md: {state_path}"
)
```

<role>
You are a GSD plan executor...
Spawned by `/gsd:execute-phase` orchestrator or via Hermes `delegate_task`.
...
```

The key addition: `## Hermes Usage` block with specific `delegate_task` calling pattern + updated role to mention Hermes.

---

## Quick Checklist

When adapting any external skill to Hermes:

- [ ] Agent files: Added `## Hermes Usage` block?
- [ ] CLI scripts: Verified symlink `~/.agents/skills/` → `~/.hermes/skills/`?
- [ ] Command files: Stripped `@filepath` and `Task()` syntax from AI expectations?
- [ ] Workflow files: Recognized as reference-only (not executable)?
- [ ] Tested: `node <skill>/scripts/gsd-tools.cjs <command>` runs without path errors?
