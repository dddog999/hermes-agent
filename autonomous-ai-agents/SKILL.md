---
name: autonomous-ai-agents
description: 多代理编程任务委派完全指南 — Qwen CLI、Claude Code、CodeBuddy、Codex、OpenCode 五种 CLI 代理的统一编排模式、优先级排序、ACP 协议和 PTY 限制。
category: autonomous-ai-agents
---

# Autonomous AI Coding Agents — Unified Delegation Guide

## 概述

本 skill 覆盖 5 种 AI 编程代理 CLI 的统一编排方式：
- **Qwen CLI** — 阿里通义千问编码代理（默认首选，免费配额）
- **Claude Code** — Anthropic Claude 编程代理
- **CodeBuddy** — 腾讯 CodeBuddy 代理
- **Codex** — OpenAI Codex CLI
- **OpenCode** — OpenCode CLI

所有代理均通过 `delegate_task(acp_command="...")` 方式调用，共享相同的编排模式。

## 统一委派接口

### ACP Subagent（推荐方式）

```python
delegate_task(
    goal="任务描述",
    context="相关文件路径、错误信息、约束条件",
    acp_command="<agent-name>",
    acp_args=["--acp", "--stdio", "--model", "<preferred-model>"]
)
```

### 参数说明

| 参数 | 说明 |
|------|------|
| `goal` | 任务目标，描述要完成什么 |
| `context` | 上下文信息（文件路径、错误信息等） |
| `acp_command` | 代理名称：`qwen`, `codebuddy`, `claude`, `codex`, `opencode` |
| `acp_args` | ACP 协议参数：always `--acp --stdio`，可选 `--model` |

## 代理优先级排序

**dddog 的偏好顺序：**
1. **Qwen CLI** — 默认首选，免费配额充足
2. **Claude Code** — 当 Qwen 不可用或用户指定时
3. **CodeBuddy** — Qwen 额度用完后自动切换，或用户指定
4. **Codex** — OpenAI Codex
5. **OpenCode** — 备选

### 优先级实现

```python
# 伪代码：自动选择可用代理
def delegate_to_best_agent(goal, context, preferred_model="minimax-m2.7"):
    agents = ["qwen", "claude", "codebuddy", "codex", "opencode"]
    for agent in agents:
        try:
            return delegate_task(
                goal=goal,
                context=context,
                acp_command=agent,
                acp_args=["--acp", "--stdio", "--model", preferred_model]
            )
        except Exception:
            continue
    raise Exception("All agents failed")
```

## 共享的 ACP 协议特性

所有代理都支持 ACP（Agent Client Protocol）：
- `--acp --stdio` — stdio 传输模式
- 支持会话管理
- 支持模型参数覆盖

### PTY 限制

所有代理的交互式 TUI（登录、某些交互）在 Hermes PTY 模拟中无法正常工作。解决：
- 交互式登录：用户在自己的终端运行一次完整登录
- 任务委派：使用 ACP stdio 模式，不依赖 TTY

## 代理特有配置

### Qwen CLI（默认首选）

- **安装路径**：`qwen` 命令在 PATH 中
- **认证**：OAuth 交互式登录（TUI）
- **推荐模型**：`minimax-m2.7` 或 `qwen2.5-coder`
- **免费配额**：充足，支持 ACP 模式

### Claude Code

- **安装路径**：`/home/dddog/.local/bin/claude-code`
- **认证**：环境变量或 `claude auth login`
- **推荐模型**：`claude-sonnet-4-7-6-2025`
- **特性**：PR 审查、代码重构、测试生成

### CodeBuddy（腾讯）

- **安装路径**：`/home/dddog/.local/bin/codebuddy`
- **认证**：Chinese Site 登录
- **版本**：2.85.0
- **推荐模型**：`minimax-m2.7`
- **PTU 模式限制**：Ink-based TUI 无法在 Hermes PTY 中转发方向键

### Codex（OpenAI）

- **认证**：OpenAI API Key
- **推荐模型**：GPT-4o
- **用途**：PR 审查、代码重构

### OpenCode

- **用途**：PR 审查、重构
- **特性**：与 Codex 类似，备用选择

## 常见问题

| 问题 | 原因 | 解决 |
|------|------|------|
| 代理 TTY 登录失败 | Hermes PTY 无法转发方向键 | 用户在真实终端完成 `/login` |
| ACP 模式失败 | 缺少 `--stdio` 参数 | 确保 `acp_args=["--acp", "--stdio"]` |
| 配额耗尽 | 免费额度用完 | 切换到下一个代理 |
| 模型不支持 | 指定了不可用模型 | 使用代理默认模型或 `minimax-m2.7` |

## 批量委派（并行）

```python
delegate_task(
    tasks=[
        {
            "goal": "任务1",
            "acp_command": "qwen",
            "acp_args": ["--acp", "--stdio", "--model", "minimax-m2.7"]
        },
        {
            "goal": "任务2",
            "acp_command": "claude",
            "acp_args": ["--acp", "--stdio", "--model", "claude-sonnet-4-7-6-2025"]
        },
    ]
)
```

## 各代理 SKILL.md

详细配置和使用说明分别保存在各自目录下：
- `autonomous-ai-agents/qwen-code/SKILL.md`
- `autonomous-ai-agents/claude-code/SKILL.md`
- `autonomous-ai-agents/codebuddy/SKILL.md`
- `autonomous-ai-agents/codex/SKILL.md`
- `autonomous-ai-agents/opencode/SKILL.md`