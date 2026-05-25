---
name: genericagent-cli-workflow
description: "GenericAgent CLI (cli.py) 开发调试工作流 — 保持 agentmain.py 干净、TDD 调试多轮对话问题"
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [genericagent, cli, tdd, multi-turn, debugging]
    related_skills: [test-driven-development, systematic-debugging]
---

# GenericAgent CLI 工作流

## 核心约束

**agentmain.py 保持干净** — 所有 CLI 修改放在 `cli.py`，不改动源头文件。

源头仓库的 `agentmain.py` 可能包含自己的 CLI 实现（如新版含 prompt_toolkit CLI）。当需要把 CLI 逻辑剥离到独立文件时，需要回退 `agentmain.py` 到旧版（不含 CLI 的版本）。

## 文件职责

| 文件 | 职责 | 来源 |
|------|------|------|
| `agentmain.py` | 核心 Agent 类 | 源头仓库（干净版，无 CLI 代码） |
| `cli.py` | CLI 入口、TUI、命令处理 | 本地开发 |
| `ga` / `ga.cmd` | 终端快捷命令 `ga` | 启动脚本，指向 `cli.py` |

## 输出架构：核心原则

**保持原版的输出模式，只替换输入方式。**

agentmain.py 原版（L254-259）的输出逻辑极其简洁：
```python
dq = agent.put_task(q)
while True:
    item = dq.get()
    if 'next' in item: print(item['next'], end='', flush=True)
    if 'done' in item: print(); break
```

**千万不要自己管理输出缓冲。** 以下做法都是错的：
- 用 `output_lines` 列表积累输出行 ❌
- 用 `streaming_buf` 按换行分割 ❌
- 用 `FormattedTextControl` + `get_display()` 渲染输出 ❌
- 用后台线程轮询队列 + `app.invalidate()` ❌

**正确的做法**：prompt_toolkit 只用于输入栏，输出完全通过 `patch_stdout` + `print()` 处理：
```python
# cli.py —— 正确架构
def _handle_input(text):
    def stream_loop():
        agent.inc_out = True
        dq = agent.put_task(text, source='user')
        while True:
            item = dq.get()
            if 'next' in item:
                print(item['next'], end='', flush=True)  # patch_stdout 自动渲染到 TUI
            if 'done' in item:
                print()
                break
    threading.Thread(target=stream_loop, daemon=True).start()

# 布局只有输入栏，不需要输出窗口
layout = Layout(input_area)

# 主入口
with patch_stdout():
    app.run()
```

这样 agent 核心的 `[Cache]`、`[Output]`、`[Debug]` 等调试输出也会自然穿插在回答中，与原版行为完全一致。

## prompt_toolkit TUI 陷阱

| 陷阱 | 后果 | 修复 |
|------|------|------|
| `Window(wrap_lines=True, dont_extend_height=True)` | 显示区高度为 0 | 去掉 `dont_extend_height` 或不用输出窗口 |
| 在 `get_display()` 或其他渲染回调里 `print()` | TUI 界面被破坏 | 不要在渲染路径里 print |
| 每个 token 都 `append_output()` 成一行 | 输出混乱，全是碎片 | 用 `print(end='', flush=True)` 逐字输出 |
| `streaming_buf = ""` 后再 `if streaming_buf.strip():` | 永远为 False | 先检查，再清空 |
| 后台轮询 `dq.get_nowait()` + `app.invalidate()` | 渲染不及时，Git Bash 下完全不刷新 | 用同步 `dq.get()` + `print()` |

## 典型任务：回退 agentmain.py 到源头旧版

当源头仓库更新了大量 CLI 代码，需要把 CLI 逻辑剥离到 `cli.py` 时：

```bash
# 1. 找 CLI 加入之前的 commit（在源头仓库 origin/main）
git log --oneline origin/main -- agentmain.py
# 找 commit message 含 "fix(cli)" 之前的版本

# 2. 提取旧版 agentmain.py
git show <旧commit>:agentmain.py > agentmain.py

# 3. 验证行数（旧版通常 260-270 行）
wc -l agentmain.py

# 4. 验证不含 CLI 代码
grep -c "prompt_toolkit\|single_instance\|acquire_instance_lock\|/model\|/queue" agentmain.py
# 应返回 1（只有 /resume 正则里的字符串）
```

## TDD 调试多轮对话问题

交接文档位置：`坚果云同步目录/GASync/留言板.md`

### 已知问题模式

**症状**：CLI 多轮对话，第二条消息发出后输出窗口没反应，但输入能发送。

**根因定位步骤**：

1. **确认队列切换逻辑**（TDD 测试）：
   ```python
   # 模拟 cli.py 的逻辑
   q1 = agent.put_task('turn1', source='user')
   current_task_dq = q1
   q1.put({'done': True})
   # polling done 后 current_task_dq = None
   
   q2 = agent.put_task('turn2', source='user')
   current_task_dq = q2  # ← cli.py 里必须手动切
   ```

2. **追踪 task_polling 的 elif 陷阱**：
   ```python
   # cli.py task_polling:
   elif is_running and agent and agent.is_running:
       pass  # ← 如果 agent.is_running 未重置，polling 会卡在这里
   ```
   当 `current_task_dq=None` 但 `agent.is_running=True` 时，polling 线程进入 elif 空转，忽略新队列。

3. **加调试打印定位**：
   - 在 `_handle_input` 打印：`[DEBUG] _handle_input: sent task, current_task_dq={id(q)}`
   - 在 `task_polling` 打印：`[DEBUG] task_polling: elif branch - is_running={is_running}, agent.is_running={agent.is_running}`

### prompt_toolkit 非 TTY 环境问题

`Application()` 在模块级创建会导致 `NoConsoleScreenBufferError`（Git Bash 等非 Windows 控制台环境）。

**修复**：延迟到 `run_cli()` 内部创建：
```python
# 错误（模块级创建）
app = Application(layout=layout, key_bindings=kb)
import cli  # ← 直接崩溃

# 正确（延迟创建）
def run_cli():
    app = Application(layout=layout, key_bindings=kb)
    polling_thread = threading.Thread(target=task_polling, args=(app,), ...)
```

### GenericAgent vs GeneraticAgent 命名问题

源头仓库新旧版本的类名不同：
- **旧版**（< 源头新 CLI）：只有 `class GeneraticAgent`
- **新版**（含自己的 CLI）：有 `class GeneraticAgent` + `GeneraticAgent = GenericAgent` 别名

**cli.py 导入**：
```python
# 旧版 agentmain.py
from agentmain import GeneraticAgent
agent = GeneraticAgent()

# 新版 agentmain.py
from agentmain import GenericAgent, GeneraticAgent
agent = GenericAgent()  # 或 GeneraticAgent()
```

## ga 快捷命令

终端输入 `ga` 即可打开 CLI：
- `ga` (Git Bash) → 执行 `ga` 脚本 → `python cli.py`
- `ga.cmd` (CMD/PowerShell) → `python.exe cli.py %*`

确保 `ga.cmd` 使用 `python.exe` 而非 `python`，避免 Git Bash 的 bash 环境覆盖 Windows Python。

## TDD 测试文件

`cli_tdd.py` 是多轮对话的 TDD 测试。注意路径问题：
- kangle (WSL)：`C:\Users\kangle\GenericAgent`
- wooking (Windows)：`C:\Users\dddog\GenericAgent`

路径写在测试文件顶部，跨机器交接时需要更新。
