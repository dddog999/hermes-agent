# GenericAgent Fork 维护参考

## 项目约定

**`agentmain.py` 保持干净** — 这是源头文件，只做核心 agent 逻辑。所有 CLI/TUI 入口修改放在 `cli.py`，不改动源头。

参考：`skills/mattpocock/productivity/cli/` 的 wrapper 模式。

## Fork 架构

```
GenericAgent/
├── agentmain.py   # 源头文件（回退目标：6091bf0，无 CLI）
├── cli.py         # 本地 CLI 入口（260行，不属于源头）
├── frontends/     # 各类前端适配器
└── ga_cli/        # 另一个 ask 入口
```

## 同步操作记录（2026-05-15）

### 从 gitee fork 拉取最新（保留本地修改）
```bash
cd C:/Users/dddog/GenericAgent
git fetch gitee
git pull gitee main
```

### 回退 agentmain.py 到源头旧版（无 CLI）
```bash
# 找最后一个不含 CLI 的 commit
git log --oneline origin/main -- agentmain.py | grep -i cli
# 验证行数
git show 6091bf0:agentmain.py | wc -l  # 262 = 无 CLI 版本

# 回退（checkout 语法不可用，用重定向）
git show 6091bf0:agentmain.py > agentmain.py
```

### 验证接口兼容性
```bash
grep -E "def (put_task|abort|list_llms|next_llm|get_llm_name|run)\(|class GenericAgent" agentmain.py
```
确保旧版仍有 `GeneraticAgent` 类和 `put_task`/`abort` 等方法。

### 检查源头是否有 cli.py
```bash
git ls-tree origin/main -- cli.py  # 空 = 源头无此文件
```

## Remote 配置
```
gitee   https://gitee.com/dddog535459/ga-fork.git (fetch/push)
origin  https://github.com/lsdefine/GenericAgent.git (fetch)
```

## 源头仓库
- **GenericAgent**: https://github.com/lsdefine/GenericAgent
