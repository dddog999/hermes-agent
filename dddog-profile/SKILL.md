---
name: dddog-profile
description: 用户 dddog 的工作偏好、技术栈和开发流程预设。当处理编程任务、项目规划、文档编写时自动加载。
version: 1.0.1
author: Hermes Agent
metadata:
  hermes:
    tags: [user-profile, workflow, preferences, spec-driven]
---

# dddog 用户档案

这是用户 dddog 的工作偏好和开发流程预设。在处理相关任务时请遵循这些规范。

## 用户画像

- **工作环境**: Windows WSL，坚果云同步，Obsidian 笔记
- **输入法**: 小鹤音形 / 星空键道
- **效率偏好**: 快速骨架 + 后续填充，不喜欢过度文档
- **时间敏感**: 注重效率，经常提到"节约时间"、"快下班了"

## 核心工作流程

### Planning-with-Files（强制）

每次复杂任务（>5 tool calls 或跨阶段工作）必须使用三文件管理：

| 文件 | 作用 | 更新时机 |
|------|------|----------|
| `task_plan.md` | 阶段追踪、当前phase | 每phase完成后 |
| `findings.md` | 研究发现、关键信息 | 每2次view/browser/search后 |
| `progress.md` | 会话日志、错误记录 | 整个session持续 |

**流程**：读 task_plan.md → 确认当前phase → 执行 → 更新文件 → commit（非trivial改动后）

### Spec-Driven Development（规范驱动开发）

用户偏好规范驱动的开发方式：

```
任务 → Spec 文件 → 实现
```

**关键原则**：
1. 先写规范，再写代码
2. 规范必须通过审查后才能标记任务完成
3. 目录编号需与计划保持一致

### Spec 目录结构

```
.specs/
├── meta/                    # 规范格式规则
├── 01-project-structure/    # 项目结构
├── 02-agentsmd-system/      # Agent 系统
├── 03-core-agents/          # 核心 Agent
├── integration/             # 集成规范
└── uncertainties/           # 待定决策
```

### Spec 文件命名

格式：`NN-description.spec.md`

示例：
- `01-directory-structure.spec.md`
- `02-openmemory-skill.spec.md`
- `integration/end-to-end.spec.md`

## 用户偏好

### 文档偏好

1. **快速骨架优先**：先创建目录和文件名，内容后续填充
2. **精简文档**：保留但精简 .specs/，优先实现可工作的代码
3. **详细参数说明**：为每个参数提供用途解释
4. **快速参考手册**：需要包含所有命令和参数的参考

### 删除偏好

- 确保无引用后再删除
- 检查 `.codebuddy/agents/`、skill 配置及其他引用点
- 完整的参数说明和功能描述

### 输出格式

- 记忆输出必须是纯 JSON，无额外文字
- JSON 包含 `memories` 数组，每项包含：
  - `category`: project / preference / technical / workflow
  - `l0_key`: 类型/名称（英文）
  - `l0_description`: 简短描述
  - `l1_heading`: 主要标题
  - `l1_body`: 详细内容
  - `salience`: 0-1 重要性分数
  - `keywords`: 关键词数组
- 最多 8 条，按重要性排序

## 技术栈

- **语言**: Python, Node.js
- **版本控制**: Git + Gitee
- **笔记系统**: Obsidian (MemVault)
- **云同步**: 坚果云
- **密码管理**: KeePass
- **AI 生态**: OpenClaw / ClawMem / CodeBuddy

## GSD 方法论

项目采用 GSD（Get Shit Done）方法论：

| 阶段 | 命令 | 说明 |
|------|------|------|
| Research | `/gsd:discuss-phase` | 调研阶段 |
| Planning | `/gsd:plan-phase` | 规划阶段 |
| Execute | `/gsd:execute-phase` | 执行阶段 |
| Verify | Nyquist 验证 | 验证阶段 |

## 记忆分类规则

| 类型 | 判断标准 | 示例 |
|------|----------|------|
| project | 项目决策/状态/架构 | "项目采用X架构" |
| preference | 用户偏好/习惯 | "用户偏好Y工具" |
| technical | 技术方案/问题解决 | "用Z框架解决了A问题" |
| workflow | 流程/模式/最佳实践 | "使用GSD方法论" |

## 常用工具

- **Git 提交**：`git commit -F commit_msg.txt`（避免 PowerShell 引号问题）
- **目录创建**：`md .specs\01-project-structure`（Windows）或 `mkdir`（WSL）
- **安全删除**：`rd /s /q`（Windows）或 `rm -rf`（WSL）

## 子代理偏好

**尽量使用 Qwen CLI 作为子代理**（免费，不用白不用）：
- 优先通过 `delegate_task(acp_command="qwen")` 分配复杂任务
- Qwen CLI 已认证（OAuth），免费额度 1000 次/天
- 适用于：编码、分析、计算、研究等需要消耗 token 的任务
- 简单查询、对话、文件操作仍由主代理直接处理

## 项目位置

- **坚果云同步**: `/mnt/c/Users/dddog/Nutstore/1/myNutstore/`
- **MemVault**: `/mnt/c/Users/dddog/Nutstore/1/myNutstore/MemVault/`
- **编程项目**: `/mnt/c/Users/dddog/Nutstore/1/myNutstore/coding/`
