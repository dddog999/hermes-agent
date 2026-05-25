---
name: fork-clean-workflow
description: Fork开发工作流——源头仓库保持干净，本地修改隔离到独立文件。多会话任务交接、跨设备同步时维持清晰的代码边界。
triggers:
  - 用户有一个fork项目，需要从上游更新
  - 交接文档提到"保持源头干净"
  - 多会话任务需要分离本地修改和上游代码
  - 拉取最新代码后出现合并冲突
---

# Fork Clean Workflow

## 核心原则

**源头仓库文件保持干净，所有本地修改隔离到独立文件（如 `cli.py`）**

适用场景：
- 第三方工具（`agentmain.py` 等），你想保留上游更新的同时加入自己的修改
- 多会话任务交接，需要清晰分离"谁改了什么"
- 跨设备同步，避免更新上游后丢失本地定制

---

## 标准操作流程

### 1. 建立 remotes

```bash
git remote -v
# 确认有 origin（你的 fork）和 upstream（源头）
git remote add upstream https://github.com/lsdefine/GenericAgent.git
```

### 2. 查看本地修改状态

```bash
git status
git diff --stat  # 快速概览
```

### 3. 从上游拉取最新代码

```bash
git fetch upstream
git pull upstream main   # 或指定分支
```

⚠️ 如果有本地修改，Git 会尝试合并。推荐先暂存：
```bash
git stash   # 临时保存本地修改
git pull upstream main
git stash pop   # 恢复本地修改
```

### 4. 回退某个文件到源头版本

当上游将本地定制代码（如 CLI）合并进主文件后，需要将文件回退到干净的上游旧版：

```bash
# 查历史，找 CLI 加入之前的干净版本（commit message 不含 fix(cli) 的更早提交）
git log --oneline origin/main -- agentmain.py | head -10

# 确认版本行数（无 CLI 代码的版本约 262 行）
git show <commit-hash>:agentmain.py | wc -l

# 用 git show 提取旧版文件内容（不是 git checkout，不会影响工作区状态）
git show <commit-hash>:agentmain.py > agentmain.py
```

**技巧**：上游旧版行数约 262 行（无 prompt_toolkit、单线程 CLI）；新版含双线程 CLI 约 533 行。通过行数快速判断。

### 4b. 回滚后的接口验证

回退后必须验证隔离文件（如 `cli.py`）依赖的方法都还在：
```bash
python -c "
from agentmain import GeneraticAgent
for m in ['put_task', 'abort', 'run', 'next_llm', 'list_llms', 'get_llm_name']:
    assert hasattr(GeneraticAgent, m), f'Missing: {m}'
import cli
print('OK')
"
```

---

## 多会话交接规范

参考 `L1-L44` 交接文档格式：

```
---
name: <任务名>
handoff-date: YYYY-MM-DD
handoff-from: <来源>
handoff-to: <目标>
status: in-progress
argument-hint: "<一句话问题描述>"
---

# <任务名> - 交接文档

## 问题描述
<核心问题>

## 核心约束
**文件名保持干净** - 所有修改放在 `cli.py`，不改动源头文件。

## 关键文件
- `cli.py` (N行) - 新TUI入口，修改在此
- `agentmain.py` (N行) - 源头文件，勿改

## 下一步行动
1. ...
```

---

## 常见陷阱

### prompt_toolkit 在非TTY环境崩溃

**问题**：`Application()` 在模块级创建时，导入即触发 Win32Output 检测，在 Git Bash / Docker 等环境失败。

**错误**：
```
prompt_toolkit.output.win32.NoConsoleScreenBufferError: Found xterm-256color
```

**修复**：延迟初始化，将 `app = Application(...)` 移到 `run_cli()` 函数内部：
```python
def run_cli():
    app = Application(layout=layout, key_bindings=kb)
    # ...
```

### Windows Git Bash 路径问题

**表现**：`cd /c/Users/ddddog/...` vs `cd /c/Users/dddog/...` 混淆（双d）。

**解决**：用 `cd C:/Users/dddog/...`（正斜杠）或直接用 Python 设置 sys.path。

### 模块级副作用

任何在 class/function 定义外执行代码的 import，都应在 `run_cli()` 内部做延迟导入，或捕获异常。

---

## 验证 checklist

- [ ] `agentmain.py` 行数回退到源头旧版（无 CLI 代码，约 262 行 vs 含 CLI 的 533 行）
- [ ] `grep -c "prompt_toolkit\|single_instance\|acquire_instance_lock" agentmain.py` 应返回 0（可能有假阳性匹配 /resume 正则里的 `\n`）
- [ ] `python -c "from agentmain import GeneraticAgent; import cli"` 成功
- [ ] `cli.py` 所有依赖的上游方法都存在
