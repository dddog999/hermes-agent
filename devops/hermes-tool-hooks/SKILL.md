---
name: hermes-tool-hooks
description: Hermes Agent 工具拦截/改写钩子系统 — pre_tool_call、transform_tool_result、shell-hooks 能力边界与实战模式
version: 1.0.0
license: MIT
metadata:
  hermes:
    tags: [hermes, plugin, hooks, pre-tool-call, tool-rewrite, shell-hooks]
    related_skills: [hermes-agent]
---

# Hermes Tool Hooks（工具钩子完全指南）

## 概述

Hermes Agent 提供三层工具执行拦截能力，按执行顺序：

```
pre_tool_call  →  tool dispatch  →  post_tool_call  →  transform_tool_result
    (拦截)         (执行)              (观察)              (结果改写)
```

## 1. pre_tool_call（执行前拦截）

**位置**：`hermes_cli/plugins.py` → `get_pre_tool_call_block_message()`

**Python 插件回调签名**：
```python
def on_pre_tool_call(
    *, tool_name: str = "", args: Any = None,
    task_id: str = "", session_id: str = "", tool_call_id: str = "", **_
) -> Optional[dict]:  # 返回 {"action": "block", "message": "..."} 或 None
    if tool_name == "terminal" and "rm" in str(args.get("command", "")):
        return {"action": "block", "message": "不要用 rm，用 trash"}
    return None
```

**Shell 钩子响应协议**（stdout JSON）：
```json
{"action": "block", "message": "Forbidden command"}
{"decision": "block", "reason": "Forbidden command"}
```

**关键限制**：
- Shell 钩子**只能 block，不能 rewrite** — 没有 `replace` / `rewrite` 响应指令
- Python 插件回调同样只检查 block，**没有原生改写 args 的机制**
- args 是 dict（引用传递），原地修改 args 在技术层面可传播到 tool dispatch，但属于未归档行为

**注册方式**（config.yaml）：
```yaml
hooks:
  pre_tool_call:
    - matcher: "terminal"
      command: "/path/to/hook-script.sh"
      timeout: 30
```

## 2. transform_tool_result（结果改写）

**位置**：`model_tools.py` 第 759-776 行

- 发生在 tool 执行之后、结果返回给 LLM 之前
- 第一个返回 string 的 hook 结果会替换原结果
- **太晚** — rm 已经执行完，不能用于安全拦截

## 3. transform_terminal_output（终端输出改写）

- 针对 terminal tool 的 stdout/stderr 文本后处理
- 同样是执行后拦截，不适合安全拦截场景

## 实战模式：用 Python 插件改写 terminal 命令

虽然 `pre_tool_call` 没有官方改写机制，但可通过修改 `args["command"]` 实现：

```python
# ~/.hermes/plugins/command-rewriter/plugin.yaml
name: command-rewriter
version: 1.0.0

# ~/.hermes/plugins/command-rewriter/__init__.py
from typing import Any

def register(ctx):
    ctx.register_hook("pre_tool_call", on_pre_tool_call)

def on_pre_tool_call(
    *, tool_name: str = "", args: Any = None,
    task_id: str = "", session_id: str = "", tool_call_id: str = "", **_
):
    """将危险命令替换为安全版本"""
    if tool_name != "terminal":
        return None

    command = args.get("command", "") if isinstance(args, dict) else ""
    if not isinstance(command, str):
        return None

    # rm → trash-put（需要安装 trash-cli: sudo apt install trash-cli）
    import re
    # 匹配 rm -rf /path, rm /path 等模式
    if re.match(r'\brm\b', command):
        # 原地修改 dict，Python 传引用，修改会传播到 tool dispatch
        if isinstance(args, dict):
            args["command"] = command.replace("rm ", "trash-put ", 1)
            args["_rewritten"] = True

    return None  # 不阻止，正常执行
```

**安装步骤**：
1. `sudo apt install trash-cli`
2. 在 `~/.hermes/plugins/` 创建 `command-rewriter/` 目录
3. 写入 `plugin.yaml` 和 `__init__.py`
4. 在 `config.yaml` 加入：
   ```yaml
   plugins:
     enabled: [command-rewriter]
   ```

**验证**：
```bash
hermes hooks doctor --event pre_tool_call --for-tool terminal
```

## Hermes Agent 内部工具执行流程（关键路径）

```
run_agent.py  run_conversation()
    ↓
model_tools.py  handle_function_call()
    ↓
    get_pre_tool_call_block_message()  ← 唯一可在 dispatch 前 block 的点
    ↓
tools/registry.py  dispatch(name, args)
    ↓
    handler(args, **kwargs)  ← terminal_tool.terminal()
```

**没有现成的 "改写 args 后继续执行" 路径**，插件只能 block。

## Shell Alias 不生效的原因

Hermes terminal tool 使用 `subprocess.run(..., shell=False)` 执行命令，shell alias 不会被展开。命令必须以 argv 数组形式传入。

## 适用场景速查

| 需求 | 方案 | 限制 |
|------|------|------|
| 阻止危险命令 | `pre_tool_call` block | 仅拒绝，不替代 |
| 改写 terminal 命令 | Python 插件修改 args | 依赖 dict 引用传递（未归档） |
| 改写工具返回结果 | `transform_tool_result` | 执行已发生 |
| 注入上下文 | `pre_llm_call` context | 仅 LLM 调用 |
| 审计/日志 | `post_tool_call` | 观察性，无拦截能力 |
