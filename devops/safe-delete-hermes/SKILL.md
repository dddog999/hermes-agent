---
name: safe-delete-hermes
description: Hermes AI Agent 安全删除插件 — 用 gio trash 替代 rm，通过 Python 插件 pre_tool_call 钩子拦截并改写命令，配合 command_allowlist 白名单永久免审批
version: 1.0.0
license: MIT
tags: [hermes, plugin, safe-delete, rm-to-trash, gio-trash, pre-tool-call]
related_skills: [hermes-tool-hooks, hermes-agent]
---

# Safe-Delete Hermes Plugin

## 目标

拦截 Hermes terminal tool 中的 `rm` 命令，自动替换为 `gio trash`，文件进入回收站而非永久删除，防止误删。

## 核心发现

### 1. pre_tool_call 可以改写命令

Python 插件的 `pre_tool_call` 回调中，`args` 是 dict 引用。直接修改 `args["command"]`，修改会传播到 tool dispatch 层，实测有效。

```python
def _on_pre_tool_call(*, tool_name, args, **kwargs):
    if tool_name != "terminal":
        return None
    command = args.get("command", "")
    if "rm " not in command:
        return None
    rewritten = _rewrite_to_trash(command)
    if rewritten:
        args["command"] = rewritten  # ← 直接改 args，原地传播
    return None  # 放行
```

**注意**：返回值 `{"action": "block"}` 会阻止命令执行。如果只想改写不要 block，返回 `None`。

### 2. gio trash 比 trash-cli 更好

| 方案 | 问题 |
|------|------|
| npm install -g trash-cli | Windows npm 路径，WSL 里调不到 |
| apt install trash-cli | 需要额外安装 |
| **gio trash** | Linux 原生，WSL Ubuntu 自带，无需安装 |

```bash
gio --version  # v2.80.0+，WSL Ubuntu 自带
```

### 3. command_allowlist 白名单免审批

改写后的命令仍含 `rm` 字符串（如 `gio trash foo` 里没有 `rm`，但 rewrite 前的原始命令有），
会触发 Hermes 的 `DANGEROUS_PATTERNS` 检测。需要在 `config.yaml` 里永久白名单：

```yaml
command_allowlist:
# ... 原有项 ...
# safe-delete plugin: rm is rewritten to gio trash, which is recoverable
- delete in root path
- recursive delete
- recursive delete (long flag)
- xargs with rm
```

白名单在模块 import 时加载，`config.yaml` 改后需重启 gateway。

### 4. 命令链 rewrite 难点

`rm foo; rm bar` 里 `;` 可能紧贴路径（`2>/dev/null;`），正则要同时处理有空格和无空格两种情况：

```python
# 匹配 &&, ||, ;（有无空格均可）
_CHAIN_SPLIT_RE = re.compile(r'(\s+(?:&&|\|\||;)\s+|(?<=[^\s]);\s*)')
```

## 插件结构

```
~/.hermes/plugins/safe-delete/
├── plugin.yaml        # 插件清单
└── __init__.py        # 钩子逻辑
```

**plugin.yaml**：
```yaml
name: safe-delete
version: 1.0.0
description: Redirect rm to gio trash via pre_tool_call hook.
```

**config.yaml**：
```yaml
plugins:
  enabled:
    - safe-delete
```

## 支持的模式

| 输入 | 输出 |
|------|------|
| `rm foo.txt` | `gio trash foo.txt` |
| `rm -rf /tmp/build` | `gio trash /tmp/build` |
| `rm foo && rm bar` | `gio trash foo && gio trash bar` |
| `rm foo; rm bar` | `gio trash foo; gio trash bar` |
| `ls; rm foo` | `ls; gio trash foo` |
| `rm --dry-run foo` | **不 rewrite**，直接放行 |
| `rm foo && echo done` | `gio trash foo && echo done` |

## 意外安全效果

`rm -rf /` → rewrite 成 `gio trash /` → `gio` 会**拒绝**删除根目录，反而比原始命令更安全。

## 验证方法

在飞书/Telegram 发一条 `rm /tmp/test.txt`，应该直接执行不弹审批提示。
