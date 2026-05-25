# Command Rewriter Plugin — 将危险命令替换为安全命令

## 功能

拦截 Hermes terminal tool 的危险删除命令，替换为 `trash-cli` 的 `trash-put`（可恢复）。

## 前提

```bash
sudo apt install trash-cli   # 或: pip install trash-cli
```

## 文件结构

```
~/.hermes/plugins/command-rewriter/
├── plugin.yaml
└── __init__.py
```

## plugin.yaml

```yaml
name: command-rewriter
version: 1.0.0
description: >
  拦截 terminal 工具的危险删除命令，替换为 trash 命令。
  前提: sudo apt install trash-cli
```

## __init__.py

```python
"""command-rewriter: 拦截并改写危险 terminal 命令"""
from __future__ import annotations

import re
from typing import Any, Optional

__version__ = "1.0.0"


def register(ctx) -> None:
    """注册 pre_tool_call 钩子"""
    ctx.register_hook("pre_tool_call", on_pre_tool_call)


def on_pre_tool_call(
    *,
    tool_name: str = "",
    args: Any = None,
    task_id: str = "",
    session_id: str = "",
    tool_call_id: str = "",
    **_,
) -> Optional[dict]:
    """
    拦截 terminal 命令，替换危险删除操作。

    Python dict 传引用：修改 args 会传播到 tool dispatch。
    这是未归档的内部行为，但 Hermes 源码中 args 直接传给 handler，
    所以修改在实践中有效。
    """
    if tool_name != "terminal":
        return None

    if not isinstance(args, dict):
        return None

    command = args.get("command", "")
    if not isinstance(command, str):
        return None

    rewritten = _rewrite_dangerous_command(command)
    if rewritten is not None:
        args["command"] = rewritten
        args["_command_rewritten"] = True

    return None  # 不阻止，执行改写后的命令


def _rewrite_dangerous_command(command: str) -> Optional[str]:
    """
    检测并改写危险命令。

    Returns:
        替换后的命令，或 None（无需改写）
    """
    import re

    # 匹配以 rm 开头的命令（包括管道、多命令等）
    # rm -rf /path, rm -r /path, rm /path, exec rm /path 等
    rm_pattern = re.compile(
        r'^(\s*(?:exec|nohup|setsid|time)\s+)*'
        r'\s*\brm\b(?:\s+-[^\s]*)?',
        re.IGNORECASE
    )

    match = rm_pattern.match(command)
    if not match:
        return None

    # 提取 rm 及其后紧跟的参数部分
    # 用 trash-put 替换（trash-put 是 trash-cli 的核心命令，可恢复）
    prefix = match.group(0)
    rest = command[len(prefix):]

    # 替换 rm 为 trash-put
    new_prefix = re.sub(r'\brm\b', 'trash-put', prefix, flags=re.IGNORECASE)
    return new_prefix + rest
```

## config.yaml 配置

在 `~/.hermes/config.yaml` 中启用插件：

```yaml
plugins:
  enabled:
    - command-rewriter
```

## 验证

```bash
# 测试钩子是否注册
hermes hooks doctor --event pre_tool_call --for-tool terminal

# 手动测试改写逻辑
cd ~/.hermes/plugins/command-rewriter
python3 -c "
from __init__ import _rewrite_dangerous_command
tests = [
    'rm -rf /tmp/build',
    'rm -r /home/user/file.txt',
    'rm /etc/config',
    'nohup rm -rf /var/cache',
    'ls /tmp',
]
for t in tests:
    r = _rewrite_dangerous_command(t)
    print(f'{t!r} -> {r!r}')
"
```

期望输出：
```
'rm -rf /tmp/build' -> 'trash-put -rf /tmp/build'
'rm -r /home/user/file.txt' -> 'trash-put -r /home/user/file.txt'
'rm /etc/config' -> 'trash-put /etc/config'
'nohup rm -rf /var/cache' -> 'nohup trash-put -rf /var/cache'
'ls /tmp' -> None
```

## 注意事项

- **仅拦截直接调用 `rm`**：通过脚本、管道、调用的间接 rm 不会被拦截
- **不可逆命令仍会被 block**：HARDLINE_PATTERNS（如 `rm -rf /`）由 `approval.py` 的 hardline 检测处理，不受此插件影响
- **trash-cli 未安装时**：命令会失败 — 必要时在 `_rewrite_dangerous_command` 中加 `which trash-put` 检查
