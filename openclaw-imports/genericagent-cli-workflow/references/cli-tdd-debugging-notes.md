# cli.py TDD 调试记录 (2026-05-15, wooking)

## 2026-05-15 第二轮调试：输出架构问题

### 问题
第一轮调试后，输出窗口仍然没反应。加了大量 debug print 后发现 `get_display()` 被频繁调用、`output_lines` 有数据，但 TUI 显示窗口不渲染。

### 根因发现
根本原因不是 UI 渲染 bug，而是**架构设计错误**：

1. **自己管理输出缓冲是错的**：agentmain.py 原版用简单的 `print(item['next'], end='', flush=True)` 逐字输出。而 cli.py 用 `output_lines` 列表 + `streaming_buf` 换行分割 + `FormattedTextControl` 渲染，完全多此一举。

2. **`dont_extend_height=True`** 导致 `Window` 在 `HSplit` 中高度为 0。

3. **`print()` debug 语句破坏 TUI**：在渲染回调 (`get_display`) 和 `task_polling` 中 print 会破坏 prompt_toolkit 的屏幕管理。

4. **每 token 一行**：`append_output(token)` 把每个 token chunk 当一行，输出全是碎片。

5. **清空后再检查**：`streaming_buf = ""; if streaming_buf.strip():` —— 永远为 False。

### 最终方案
完全照搬 agentmain.py 原版输出模式：
- 删除：`output_lines`、`streaming_buf`、`append_output`、`get_display`、`display_window`、`task_polling`
- 保留：`TextArea` 输入栏 + Enter/Ctrl+Enter
- 输出：`threading.Thread(target=stream_loop)` 里同步 `dq.get()` + `print(end='', flush=True)`，通过 `patch_stdout` 渲染

### 正确的 cli.py 架构
```python
def _handle_input(text):
    def stream_loop():
        agent.inc_out = True
        dq = agent.put_task(text, source='user')
        while True:
            item = dq.get()
            if 'next' in item:
                print(item['next'], end='', flush=True)
            if 'done' in item:
                print()
                break
    threading.Thread(target=stream_loop, daemon=True).start()

# 布局只有输入栏
layout = Layout(input_area)
```

---

## 问题
CLI 多轮对话：第二条消息发出后输出窗口没反应。

## TDD 定位过程

### 测试 1: put_task 返回队列类型
```
has display_queue attr: False
put_task returns: Queue
```
确认：`put_task()` 创建**新 Queue**，不是 `display_queue`。

### 测试 2: 队列切换逻辑（模拟）
```
第一轮 current_task_dq: 1819877017696
done后 current_task_dq: None
第二轮 current_task_dq: 1819877017984
q2 is q1: False
current_task_dq is q2: True
```
队列切换逻辑**本身正确**。

### 测试 3: 调试打印定位

在 `task_polling` 和 `_handle_input` 加调试：
- `[DEBUG] task_polling: next N chars` — 确认 polling 收到 next
- `[DEBUG] task_polling: elif branch` — 确认是否卡在 elif

**关键陷阱**：`elif is_running and agent and agent.is_running: pass`
当 `current_task_dq=None` 但 `agent.is_running=True` 时，polling 线程进入 elif 空转，忽略新队列。

### 测试 4: prompt_toolkit Application 模块级崩溃
```
ImportError: cannot import name 'GenericAgent' from 'agentmain'
NoConsoleScreenBufferError: Found xterm-256color, while expecting a Windows console
```
- `app = Application(...)` 在模块级创建导致非 TTY 环境崩溃
- 修复：移到 `run_cli()` 内部延迟创建

### 测试 5: GenericAgent 别名问题
```
ImportError: cannot import name 'GenericAgent' from 'agentmain'
Did you mean: 'GeneraticAgent'?
```
旧版 `agentmain.py` 只有 `GeneraticAgent`，无 `GenericAgent` 别名。
修复：`from agentmain import GeneraticAgent`（移除 `GenericAgent`）

## 修复清单

| # | 修复 | 位置 |
|---|------|------|
| 1 | 回退 `agentmain.py` 到源头旧版（262行） | `git show 6091bf0:agentmain.py > agentmain.py` |
| 2 | `GenericAgent` → `GeneraticAgent` | cli.py L226 |
| 3 | 延迟创建 `Application` | cli.py L229+，移到 `run_cli()` 内 |
| 4 | `app.invalidate()` 改用 `app_ref` 参数 | cli.py L203, L210 |

## 待验证
调试打印还在 cli.py 中，需要用户确认：
- 第一条消息：是否有 `[DEBUG] task_polling: next N chars`？
- 第二条消息：是否有 `[DEBUG] _handle_input: sent task` 但无 `task_polling: next`？
