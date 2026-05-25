---
name: gsd-master
description: GSD (Get Shit Done) master skill - unified entry point for all 50+ GSD commands. Use for project initialization, phase planning, code execution, debugging, verification, and spec-driven development workflows. Triggers on natural language like "start new project", "plan phase", "execute", "debug", "verify work", or command format like /gsd:new-project, gsd:plan-phase 1. Supports both casual and precise invocation modes.
allowed-tools: 
disable: false
---

# GSD Master

GSD (Get Shit Done) is a meta-prompting and spec-driven development system for structured project workflows.

## Purpose

GSD helps you manage software projects through:
- **Project initialization** - From idea to structured roadmap
- **Phase planning** - Detailed execution plans with verification criteria
- **Code execution** - Atomic commits with deviation handling
- **Debugging** - Systematic issue investigation
- **Verification** - UAT-style acceptance testing

## Intent Recognition

### Mode A: Command Format (Priority)

Match patterns: `/gsd:xxx` or `gsd:xxx`

```
/gsd:new-project      → new-project.md
/gsd:plan-phase 1     → plan-phase.md (phase=1)
/gsd:execute-phase     → execute-phase.md
/gsd:quick --no-tests → quick.md (opts=--no-tests)
```

### Mode B: Natural Language

| Intent | Keywords | Command |
|--------|----------|---------|
| Start project | "new project", "start", "create project", "init" | new-project.md |
| Analyze code | "map codebase", "analyze code", "understand project" | map-codebase.md |
| Plan phase | "plan", "create plan", "roadmap", "phase" | plan-phase.md |
| Execute | "execute", "run", "implement", "build" | execute-phase.md |
| Quick task | "quick", "fast", "simple task" | quick.md |
| Debug | "debug", "fix", "issue", "bug", "problem", "troubleshoot" | diagnose-issues.md |
| Verify | "verify", "test", "check", "uat", "acceptance" | verify-work.md |
| Progress | "progress", "status", "where am I", "现在进度" | progress.md |
| Help | "help", "commands", "list commands", "帮助" | help.md |
| Resume | "resume", "恢复", "继续", "回到上次" | resume-project.md |
| Pause | "pause", "暂停", "保存状态" | pause-work.md |

## Execution

1. **Parse user input** - Check for command format first
2. **Extract command and parameters** - Phase numbers, options
3. **Read command file** - `references/commands/{command}.md`
4. **Execute workflow** - Follow the process defined in command file

## Command Reference

All 50+ commands available in `references/commands/`:

| Category | Commands |
|----------|----------|
| **Project** | new-project, new-milestone, complete-milestone, map-codebase |
| **Planning** | discuss-phase, plan-phase, research-phase, add-phase, insert-phase, remove-phase, transition, discovery-phase |
| **Execution** | execute-phase, execute-plan, quick, do, fast |
| **Verification** | verify-work, verify-phase, validate-phase, ui-phase, ui-review, review |
| **Debug** | diagnose-issues, health, node-repair |
| **Navigation** | progress, stats, help, next, pause-work, resume-project |
| **Todos** | add-todo, check-todos, note, add-tests |
| **Workflow** | autonomous, cleanup, settings, update, profile-user, session-report, plant-seed, pr-branch, list-phase-assumptions, plan-milestone-gaps |
| **Research** | discuss-phase (research mode), research-phase |

For full command list and detailed usage, see `references/commands/help.md`.

## Templates

Document templates in `references/templates/`:

| Template | Purpose |
|----------|---------|
| `project.md` | PROJECT.md structure |
| `requirements.md` | REQUIREMENTS.md structure |
| `roadmap.md` | ROADMAP.md structure |
| `UAT.md` | User acceptance test format |
| `DEBUG.md` | Debug session format |
| `codebase/` | Codebase analysis templates |
| `research-project/` | Research document templates |

## CLI Tools

Scripts in `scripts/` provide deterministic operations:

```bash
# Initialize project context
node @../scripts/gsd-tools.cjs init new-project

# Phase operations
node @../scripts/gsd-tools.cjs roadmap analyze
node @../scripts/gsd-tools.cjs phase add "description"

# Git operations
node @../scripts/gsd-tools.cjs commit "message" --files path1 path2
```

**Note**: CLI tools require Node.js and are called automatically by command workflows.

## Project Structure

GSD expects this structure:

```
project/
├── .planning/
│   ├── PROJECT.md        # Project context
│   ├── REQUIREMENTS.md   # Requirements
│   ├── ROADMAP.md        # Phase roadmap
│   ├── STATE.md          # Current state
│   ├── config.json       # Configuration
│   └── phases/           # Phase files
└── ... (project code)
```

## Quick Reference

| User says | Action |
|-----------|--------|
| "开始一个新项目" | Read `references/commands/new-project.md` |
| "计划第一阶段" | Read `references/commands/plan-phase.md` (phase=1) |
| "执行计划" | Read `references/commands/execute-phase.md` |
| "调试这个问题" | Read `references/commands/diagnose-issues.md` |
| "/gsd:quick 添加TODO" | Read `references/commands/quick.md` + context |
| "恢复上次工作" | Read `references/commands/resume-project.md` |
| "暂停工作" | Read `references/commands/pause-work.md` |
