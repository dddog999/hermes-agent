# gsd-master 用户手册

GSD (Get Shit Done) 是一个规格驱动开发系统，帮助你在 AI 编程工具中管理项目。

---

## 命令速查

### 核心命令

| 命令 | 说明 |
|------|------|
| `/gsd:new-project [--auto [@<file>]]` | 初始化新项目 |
| `/gsd:new-milestone [name]` | 开始新里程碑 |
| `/gsd:discuss-phase [N] [--auto] [--batch[=N]] [--analyze]` | 收集实现偏好 |
| `/gsd:plan-phase [N] [--research\|--skip-research] [--skip-verify] [--gaps] [--prd <file>] [--auto] [--no-transition]` | 创建执行计划 |
| `/gsd:execute-phase [N] [--interactive] [--gaps-only] [--auto] [--no-transition]` | 执行计划 |
| `/gsd:verify-work [N]` | 用户验收测试 |
| `/gsd:verify-phase [N]` | 验证阶段目标 |
| `/gsd:ui-phase [N]` | 生成 UI 设计契约 |
| `/gsd:validate-phase [N]` | Nyquist 验证审计 |
| `/gsd:audit-milestone` | 验证里程碑完成度 |
| `/gsd:complete-milestone [version]` | 归档里程碑 |
| `/gsd:map-codebase` | 分析现有代码库 |

### 导航与状态

| 命令 | 说明 |
|------|------|
| `/gsd:progress` | 查看当前位置和进度 |
| `/gsd:resume-project` | 恢复项目上下文 |
| `/gsd:pause-work` | 保存状态并暂停 |
| `/gsd:next` | 自动执行下一步 |
| `/gsd:stats` | 显示项目统计 |
| `/gsd:help` | 显示帮助 |

### 阶段管理

| 命令 | 说明 |
|------|------|
| `/gsd:add-phase <description>` | 添加新阶段 |
| `/gsd:insert-phase <after> <description>` | 插入紧急阶段 |
| `/gsd:remove-phase <N>` | 移除阶段 |

### 质量与验证

| 命令 | 说明 |
|------|------|
| `/gsd:ui-review [N]` | 6 维度 UI 审计 |
| `/gsd:review [N] [--gemini\|--claude\|--codex\|--all]` | 跨 AI 同行评审 |

### 任务与笔记

| 命令 | 说明 |
|------|------|
| `/gsd:add-todo [description]` | 添加待办事项 |
| `/gsd:check-todos [area]` | 列出/筛选待办 |
| `/gsd:note [text\|list\|promote N] [--global]` | 零摩擦笔记 |

### 工具与自动化

| 命令 | 说明 |
|------|------|
| `/gsd:quick [description] [--discuss] [--research] [--full]` | 快速任务执行 |
| `/gsd:autonomous [--from N]` | 自动驱动所有阶段 |
| `/gsd:settings` | 配置 GSD 设置 |
| `/gsd:health [--repair]` | 健康检查/修复 |
| `/gsd:update` | 检查更新 |
| `/gsd:cleanup` | 归档已完成里程碑 |

### 调试与审查

| 命令 | 说明 |
|------|------|
| `/gsd:diagnose-issues [description]` | 并行调试调查 |
| `/gsd:profile-user [--questionnaire] [--refresh]` | 开发者画像 |

### 通用参数

| 参数 | 说明 |
|------|------|
| `--auto` | 自动模式，减少交互 |
| `--interactive` | 交互模式，逐个执行 |
| `--research` | 强制进行研究 |
| `--skip-research` | 跳过研究 |
| `--skip-verify` | 跳过验证 |
| `--gaps` | 从验证差距创建计划 |
| `--gaps-only` | 仅执行 gap 计划 |
| `--no-transition` | 不执行阶段转换 |
| `--batch[=N]` | 批量提问（2-5 个/批） |
| `--analyze` | 显示选项分析 |
| `--prd <file>` | PRD 快速路径 |
| `--repair` | 自动修复 |
| `--from N` | 从指定阶段开始 |
| `--questionnaire` | 仅问卷模式 |
| `--refresh` | 刷新数据 |
| `--full` | 启用完整质量保障 |
| `--discuss` | 执行前讨论 |
| `--global` | 强制全局存储 |
| `@<file>` | 附加文件 |

---

## 目录

- [工作流程](#工作流程)
- [命令参考](#命令参考)
  - [核心工作流命令](#核心工作流命令)
  - [导航与状态命令](#导航与状态命令)
  - [阶段管理命令](#阶段管理命令)
  - [质量与验证命令](#质量与验证命令)
  - [任务与笔记命令](#任务与笔记命令)
  - [工具与自动化命令](#工具与自动化命令)
  - [调试与审查命令](#调试与审查命令)
- [通用参数](#通用参数)
- [配置参考](#配置参考)
- [使用示例](#使用示例)
- [故障排除](#故障排除)

---

## 工作流程

### 完整项目生命周期

```
┌──────────────────────────────────────────────────┐
│                   NEW PROJECT                    │
│  /gsd:new-project                                │
│  提问 -> 研究 -> 需求 -> 路线图                    │
└─────────────────────────┬────────────────────────┘
                          │
           ┌──────────────▼─────────────┐
           │      每个阶段循环:          │
           │                            │
           │  /gsd:discuss-phase        │  <- 确认实现偏好
           │  /gsd:plan-phase           │  <- 研究 + 计划
           │  /gsd:execute-phase        │  <- 并行执行
           │  /gsd:verify-work          │  <- 手动验收
           │                            │
           │     下一阶段?───────────────┘
           └────────────────────────────┘
                          │
          ┌───────────────▼──────────────┐
          │  /gsd:audit-milestone        │
          │  /gsd:complete-milestone     │
          └───────────────┬──────────────┘
                          │
                 另一个里程碑?
```

### 调用方式

**命令格式**（精确控制）：
```
/gsd:new-project
/gsd:plan-phase 1
/gsd:execute-phase
```

**自然语言**（便捷调用）：
```
"开始一个新项目"
"计划第一阶段"
"执行计划"
```

---

## 命令参考

### 核心工作流命令

#### `/gsd:new-project`

初始化新项目。通过提问、研究（可选）、需求定义、路线图生成来配置整个项目。

| 参数 | 说明 |
|------|------|
| `--auto` | 自动模式：跳过提问，从提供的文档中提取上下文 |
| `@<file>` | 指定 PRD 或想法文档，与 `--auto` 配合使用 |

**示例:**
```
/gsd:new-project                    # 交互式初始化
/gsd:new-project --auto @prd.md     # 从文档自动初始化
```

#### `/gsd:new-milestone [name]`

在已有项目中开始新里程碑周期。收集里程碑目标、定义需求、生成路线图。是已有项目的 brownfield 入口。

| 参数 | 说明 |
|------|------|
| `name` | 可选。里程碑名称（如 "v1.1 Security"） |

#### `/gsd:discuss-phase [N]`

在进入规划之前，收集用户对当前阶段实现偏好的决策。生成 CONTEXT.md，供后续研究和规划代理使用。不是采访——是与用户的思维协作。

| 参数 | 说明 |
|------|------|
| `[N]` | 可选。阶段编号，如 `1`。省略则检测下一个未计划的阶段 |
| `--auto` | 自动模式，自动选择推荐选项 |
| `--batch` | 批量提问模式（每轮 2-5 个问题一起回答） |
| `--batch=<N>` | 指定每批问题数量（2-5） |
| `--analyze` | 在提问前显示 trade-off 分析表格 |

**示例:**
```
/gsd:discuss-phase 1              # 讨论第一阶段
/gsd:discuss-phase 3 --auto       # 自动讨论第三阶段
/gsd:discuss-phase 2 --batch      # 批量提问模式
/gsd:discuss-phase 2 --batch=3    # 每批 3 个问题
/gsd:discuss-phase 2 --analyze    # 显示选项分析
```

#### `/gsd:plan-phase [N]`

为指定阶段创建可执行计划。默认流程：研究（如需要）-> 规划 -> 验证 -> 完成。

| 参数 | 说明 |
|------|------|
| `[N]` | 可选。阶段编号。省略则检测下一个未计划的阶段 |
| `--research` | 强制在规划前进行研究 |
| `--skip-research` | 跳过研究，直接规划 |
| `--skip-verify` | 跳过计划验证 |
| `--gaps` | Gap 模式：从 VERIFICATION.md 读取差距并创建修复计划 |
| `--prd <filepath>` | PRD 快速路径：从 PRD 文件生成 CONTEXT.md，跳过讨论 |
| `--auto` | 自动模式，自动推进到 execute-phase |
| `--no-transition` | 执行后不进行阶段转换（用于自动链接） |

**示例:**
```
/gsd:plan-phase 1                 # 规划第一阶段（默认会询问是否研究）
/gsd:plan-phase 1 --research      # 强制研究后规划
/gsd:plan-phase 1 --skip-research # 跳过研究直接规划
/gsd:plan-phase 1 --gaps          # 从验证差距创建修复计划
/gsd:plan-phase 1 --prd docs/prd.md  # 从 PRD 快速规划
/gsd:plan-phase 1 --auto          # 规划后自动执行
```

#### `/gsd:execute-phase [N]`

执行阶段中所有计划。使用基于 wave 的并行执行模型。

| 参数 | 说明 |
|------|------|
| `[N]` | 可选。阶段编号 |
| `--interactive` | 交互模式：逐个计划执行，用户可在每步审查 |
| `--gaps-only` | 仅执行 gap_closure 类型的计划（修复验证发现的差距） |
| `--auto` | 自动模式 |
| `--no-transition` | 执行后不进行阶段转换（用于自动链接） |

**示例:**
```
/gsd:execute-phase 1              # 并行执行第一阶段所有计划
/gsd:execute-phase 1 --interactive # 交互执行
/gsd:execute-phase 1 --gaps-only  # 仅执行修复计划
```

#### `/gsd:verify-work [N]`

用户验收测试（UAT）。从 SUMMARY.md 中提取可测试项，逐个向用户展示测试预期行为，记录结果。发现差距时自动诊断并规划修复。

| 参数 | 说明 |
|------|------|
| `[N]` | 可选。阶段编号。省略则列出活跃的 UAT 会话 |

**示例:**
```
/gsd:verify-work 1                # 测试第一阶段
/gsd:verify-work                  # 列出活跃 UAT 会话
```

#### `/gsd:verify-phase [N]`

通过逆向分析验证阶段目标是否达成。检查目标而非任务完成情况。

| 参数 | 说明 |
|------|------|
| `[N]` | 可选。阶段编号 |

#### `/gsd:ui-phase [N]`

为前端阶段生成 UI 设计契约（UI-SPEC.md）。在规划前锁定间距、排版、颜色、文案等设计决策。

| 参数 | 说明 |
|------|------|
| `[N]` | 可选。阶段编号 |

#### `/gsd:validate-phase [N]`

审计已完成阶段的 Nyquist 验证差距。生成缺失的测试，更新 VALIDATION.md。

| 参数 | 说明 |
|------|------|
| `[N]` | 可选。阶段编号 |

#### `/gsd:audit-milestone`

验证里程碑完成度。聚合阶段验证结果，检查跨阶段集成，评估需求覆盖率。

#### `/gsd:complete-milestone`

归档已交付的里程碑。创建历史记录、归档 ROADMAP 和 REQUIREMENTS、更新 PROJECT.md、打 git 标签。

| 参数 | 说明 |
|------|------|
| 可选：里程碑版本 | 如 `v1.0`，省略则检测当前里程碑 |

#### `/gsd:map-codebase`

并行分析现有代码库，生成 7 份结构化文档（STACK.md、ARCHITECTURE.md 等）。适用于已有项目初始化前。

---

### 导航与状态命令

#### `/gsd:progress`

显示项目状态、近期工作、当前位置，并智能路由到下一步行动。回答"我在哪？"

**示例:**
```
/gsd:progress                     # 查看完整进度
```

#### `/gsd:resume-project`

恢复项目上下文。检测未完成的工作、中断的代理、待办的 todo，提供下一步建议。

#### `/gsd:pause-work`

创建结构化交接文件（HANDOFF.json + .continue-here.md），保留完整工作状态以便跨会话恢复。

#### `/gsd:next`

自动检测项目状态并立即执行下一个逻辑工作流步骤。无需确认——零摩擦推进。

#### `/gsd:stats`

显示项目统计数据：阶段进度、计划完成率、需求完成率、Git 指标、时间线。

#### `/gsd:help`

显示所有可用命令的快速参考。

---

### 阶段管理命令

#### `/gsd:add-phase <description>`

在当前里程碑末尾添加新的整数编号阶段。自动计算下一阶段编号，创建目录，更新 ROADMAP。

| 参数 | 说明 |
|------|------|
| `<description>` | 必需。阶段描述 |

**示例:**
```
/gsd:add-phase Add authentication system
```

#### `/gsd:insert-phase <after> <description>`

在现有整数阶段之间插入紧急的小数编号阶段（如 72.1）。用于中途发现的紧急工作，不需要重新编号整个路线图。

| 参数 | 说明 |
|------|------|
| `<after>` | 必需。插入在哪个阶段之后（整数） |
| `<description>` | 必需。阶段描述 |

**示例:**
```
/gsd:insert-phase 72 Fix critical auth bug
```

#### `/gsd:remove-phase <N>`

移除未启动的未来阶段。删除目录、重新编号后续阶段、更新 ROADMAP、提交变更。

| 参数 | 说明 |
|------|------|
| `<N>` | 必需。要移除的阶段编号（整数或小数） |

**示例:**
```
/gsd:remove-phase 17
/gsd:remove-phase 16.1
```

#### `/gsd:transition`

**内部工作流命令——不是用户命令。** 由 execute-phase 在自动推进时自动调用，标记当前阶段完成并推进到下一阶段。用户不应手动调用此命令。

---

### 质量与验证命令

#### `/gsd:ui-review [N]`

对已实现的前端代码进行 6 维度视觉审计。可在任何项目上独立运行（不限于 GSD 管理的项目）。生成 UI-REVIEW.md 评分报告。

| 参数 | 说明 |
|------|------|
| `[N]` | 可选。阶段编号 |

**6 个审计维度:**
- Copywriting（文案）
- Visuals（视觉效果）
- Color（颜色）
- Typography（排版）
- Spacing（间距）
- Experience Design（体验设计）

#### `/gsd:review [N]`

跨 AI 同行评审。调用外部 AI CLI（Gemini、Claude、Codex）独立审查阶段计划，合并为 REVIEWS.md。

| 参数 | 说明 |
|------|------|
| `[N]` | 可选。阶段编号 |
| `--gemini` | 仅使用 Gemini |
| `--claude` | 仅使用 Claude（外部会话） |
| `--codex` | 仅使用 Codex |
| `--all` | 使用所有可用的外部 CLI |

**示例:**
```
/gsd:review 1                     # 用所有可用的外部 CLI 审查
/gsd:review 1 --gemini            # 仅用 Gemini
```

---

### 任务与笔记命令

#### `/gsd:add-todo [description]`

捕获会话中出现的想法、任务或问题为结构化 todo。

| 参数 | 说明 |
|------|------|
| `[description]` | 可选。todo 描述。省略则从最近对话中提取 |

**示例:**
```
/gsd:add-todo Add auth token refresh   # 直接添加
/gsd:add-todo                          # 从对话中提取
```

#### `/gsd:check-todos [area]`

列出所有待办事项，支持按领域筛选，选择后可路由到行动（立即工作、加入计划、头脑风暴）。

| 参数 | 说明 |
|------|------|
| `[area]` | 可选。按领域筛选：`api`、`ui`、`auth`、`database`、`testing`、`docs`、`planning`、`tooling`、`general` |

**示例:**
```
/gsd:check-todos                    # 列出所有
/gsd:check-todos api                # 仅查看 API 相关
```

#### `/gsd:note [text]`

零摩擦想法捕获。写入即确认，不提问不交互。

| 参数/子命令 | 说明 |
|-------------|------|
| `[text]` | 直接写入笔记内容 |
| `list` | 列出所有笔记（项目级 + 全局） |
| `promote <N>` | 将第 N 条笔记转换为 todo |
| `--global` | 强制存储为全局笔记（`~/.claude/notes/`） |

**示例:**
```
/gsd:note consider adding rate limiting    # 快速记录
/gsd:note list                             # 列出所有笔记
/gsd:note promote 3                        # 将第 3 条转为 todo
/gsd:note --global cross-project idea      # 全局笔记
```

---

### 工具与自动化命令

#### `/gsd:quick [description]`

执行小型、临时任务，具有 GSD 保证（原子提交、STATE.md 跟踪）。支持规划、讨论、研究和验证的可组合标志。

| 参数 | 说明 |
|------|------|
| `[description]` | 可选。任务描述 |
| `--discuss` | 执行前进行轻量级讨论，捕获灰色区域决策 |
| `--research` | 执行前派研究代理调查实现方案 |
| `--full` | 启用计划验证（最多 2 轮修订）+ 执行后验证 |

**示例:**
```
/gsd:quick                             # 交互式输入
/gsd:quick Fix mobile login button     # 直接描述
/gsd:quick --discuss --research Add dark mode   # 讨论+研究+执行
/gsd:quick --full --discuss Implement auth guard  # 讨论+全质量保障
```

**标志可组合:** `--discuss --research --full` = 讨论 + 研究 + 计划验证 + 执行验证

#### `/gsd:autonomous [--from N]`

自动驱动所有剩余里程碑阶段。对每个未完成的阶段：smart discuss -> plan -> execute。仅在需要用户决策时暂停。

| 参数 | 说明 |
|------|------|
| `--from N` | 从指定阶段编号开始（跳过之前所有阶段） |

**示例:**
```
/gsd:autonomous                      # 自动完成所有
/gsd:autonomous --from 5             # 从第 5 阶段开始
```

#### `/gsd:settings`

交互式配置 GSD 工作流设置。更新 `.planning/config.json`，可选保存为全局默认值。

**可配置项:**
- 模型配置（Quality/Balanced/Budget/Inherit）
- 研究代理开关
- 计划验证开关
- 执行验证开关
- 自动推进开关
- Nyquist 验证开关
- UI 阶段开关
- UI 安全门开关
- Git 分支策略（None/Per Phase/Per Milestone）
- 上下文窗口警告开关
- 研究前置问题开关

#### `/gsd:health [--repair]`

验证 `.planning/` 目录完整性，报告可操作问题。

| 参数 | 说明 |
|------|------|
| `--repair` | 自动修复可修复的问题（如重建 STATE.md、config.json） |

**返回状态:**
- `HEALTHY` - 一切正常
- `DEGRADED` - 有警告或部分问题
- `BROKEN` - 有错误需要修复

#### `/gsd:update`

检查 GSD 更新，显示更新日志，确认后执行安装。

#### `/gsd:cleanup`

归档已完成里程碑的阶段目录到 `.planning/milestones/v{X.Y}-phases/`。显示干运行摘要，确认后移动。

---

### 调试与审查命令

#### `/gsd:diagnose-issues [description]`

并行调试代理调查 UAT 中发现的差距，定位根因。为 plan-phase --gaps 提供精确修复方向。

| 参数 | 说明 |
|------|------|
| `[description]` | 可选。问题描述。通常由 verify-work 自动调用 |

#### `/gsd:profile-user`

开发者画像。分析 session 记录或问卷，生成 8 维行为画像，保存为 USER-PROFILE.md。

| 参数 | 说明 |
|------|------|
| `--questionnaire` | 跳过 session 分析，仅使用问卷 |
| `--refresh` | 重新分析 session 以更新画像 |

**画像的 8 个维度:**
1. Communication Style（沟通风格）
2. Decision Speed（决策速度）
3. Explanation Depth（解释深度）
4. Debugging Approach（调试方法）
5. UX Philosophy（UX 哲学）
6. Vendor Philosophy（供应商评估方式）
7. Frustration Triggers（挫折触发点）
8. Learning Style（学习风格）

---

## 通用参数

以下参数在多个命令中通用：

| 参数 | 适用命令 | 说明 |
|------|---------|------|
| `--auto` | discuss-phase, plan-phase, execute-phase, autonomous | 自动模式，减少用户交互，自动推进 |
| `--batch` | discuss-phase | 批量提问模式 |
| `--analyze` | discuss-phase | 显示选项 trade-off 分析 |
| `--research` | plan-phase, quick | 强制进行研究 |
| `--skip-research` | plan-phase | 跳过研究 |
| `--skip-verify` | plan-phase | 跳过计划验证 |
| `--gaps` | plan-phase | 从验证差距创建修复计划 |
| `--gaps-only` | execute-phase | 仅执行修复计划 |
| `--interactive` | execute-phase | 交互执行模式 |
| `--no-transition` | plan-phase, execute-phase | 不执行阶段转换（用于自动链接） |
| `--prd <file>` | plan-phase | PRD 快速路径 |
| `--repair` | health | 自动修复 |
| `--from N` | autonomous | 从指定阶段开始 |
| `--questionnaire` | profile-user | 仅问卷模式 |
| `--refresh` | profile-user | 刷新画像 |
| `--full` | quick | 启用完整质量保证 |
| `--discuss` | quick | 执行前讨论 |
| `--global` | note | 强制全局笔记 |

---

## 配置参考

GSD 在 `.planning/config.json` 中存储项目设置。

### 核心设置

| 设置 | 选项 | 默认值 | 说明 |
|------|------|--------|------|
| `mode` | `interactive`, `yolo` | `interactive` | `yolo` 自动批准决策 |
| `granularity` | `coarse`, `standard`, `fine` | `standard` | 阶段粒度 |
| `model_profile` | `quality`, `balanced`, `budget`, `inherit` | `balanced` | 模型配置 |
| `parallelization` | `true`, `false` | `true` | 计划是否并行执行 |
| `commit_docs` | `true`, `false` | `true` | 是否将规划文档提交到 git |

### 工作流开关

| 设置 | 默认值 | 说明 |
|------|--------|------|
| `workflow.research` | `true` | 规划前领域研究 |
| `workflow.plan_check` | `true` | 计划验证循环 |
| `workflow.verifier` | `true` | 执行后验证 |
| `workflow.auto_advance` | `false` | 自动推进管线（discuss → plan → execute） |
| `workflow.nyquist_validation` | `true` | 规划期间验证架构研究 |
| `workflow.ui_phase` | `true` | 为前端阶段生成 UI 设计契约 |
| `workflow.ui_safety_gate` | `true` | 规划前端阶段前提示运行 UI-phase |
| `hooks.context_warnings` | `true` | 上下文超过 65% 时注入警告 |
| `hooks.research_questions` | `false` | 提问前搜索最佳实践 |
| `git.branching_strategy` | `"none"` | Git 分支策略：`"none"`、`"phase"`、`"milestone"` |

### 完整配置结构

```json
{
  "mode": "interactive",
  "granularity": "standard",
  "model_profile": "balanced",
  "parallelization": true,
  "commit_docs": true,
  "planning": {
    "commit_docs": true
  },
  "workflow": {
    "research": true,
    "plan_check": true,
    "verifier": true,
    "auto_advance": false,
    "nyquist_validation": true,
    "ui_phase": true,
    "ui_safety_gate": true
  },
  "git": {
    "branching_strategy": "none"
  },
  "hooks": {
    "context_warnings": true,
    "workflow_guard": true,
    "research_questions": false
  }
}
```

---

## 使用示例

### 新项目（完整周期）

```
/gsd:new-project            # 回答问题，配置，批准路线图
/gsd:discuss-phase 1        # 确认偏好
/gsd:plan-phase 1           # 研究 + 计划
/gsd:execute-phase 1        # 并行执行
/gsd:verify-work 1          # 手动验收
... 对每个阶段重复
/gsd:audit-milestone        # 检查所有功能
/gsd:complete-milestone     # 归档，打标签，完成
```

### 从现有文档初始化

```
/gsd:new-project --auto @prd.md   # 从文档自动运行
/gsd:discuss-phase 1              # 正常流程
```

### 现有代码库

```
/gsd:map-codebase           # 分析现有代码
/gsd:new-project            # 问题聚焦于你要添加的内容
```

### 快速 Bug 修复

```
/gsd:quick
> "修复移动端登录按钮无响应问题"
```

### 带质量保障的快速任务

```
/gsd:quick --discuss --research --full Add rate limiting to API
```

### 恢复工作

```
/gsd:progress               # 查看上次进度
# 或
/gsd:resume-project         # 完整上下文恢复
```

### 自动化管线

```
/gsd:discuss-phase 1 --auto  # 自动 discussion → plan → execute
```

### 添加/移除阶段

```
/gsd:add-phase Add user analytics    # 添加新阶段
/gsd:insert-phase 3 Fix critical bug # 插入紧急阶段
/gsd:remove-phase 7                  # 移除不需要的阶段
```

---

## 故障排除

### "项目已初始化"

`.planning/PROJECT.md` 已存在。如需重新开始，先删除 `.planning/` 目录。

### 上下文退化

在主要命令之间清除上下文窗口。GSD 设计围绕全新上下文——每个子代理获得干净的窗口。如果质量下降，清除后使用 `/gsd:resume-project` 恢复状态。

### 计划看起来不对

在规划前运行 `/gsd:discuss-phase [N]`。大多数计划质量问题来自 AI 做出了 CONTEXT.md 本可防止的假设。

### 执行失败或产生桩代码

检查计划是否过于宏大。计划最多应有 2-3 个任务。如果任务太大，会超出单个上下文窗口能可靠生成的范围。用更小的范围重新规划。

### 不知道在哪

运行 `/gsd:progress`。它会读取所有状态文件，告诉你确切位置和下一步。

### 需要在执行后修改

不要重新运行 `/gsd:execute-phase`。使用 `/gsd:quick` 进行针对性修复，或 `/gsd:verify-work` 通过 UAT 系统识别和修复问题。

### Windows 上代理生成时卡死

这是 Windows 上的已知问题（stdio 死锁）。解决方案：
1. 强制关闭终端
2. 清理残留的 node 进程
3. 减少 MCP 服务器数量
4. 使用 `--skip-research` 减少代理链

---

## 项目文件结构

```
.planning/
  PROJECT.md              # 项目愿景和上下文
  REQUIREMENTS.md         # 范围需求
  ROADMAP.md              # 阶段分解
  STATE.md                # 决策、阻塞、会话记忆
  config.json             # 工作流配置
  phases/
    XX-phase-name/
      XX-YY-PLAN.md       # 原子执行计划
      XX-YY-SUMMARY.md    # 执行结果
      CONTEXT.md          # 实现偏好
      RESEARCH.md         # 生态研究发现
      VERIFICATION.md     # 执行后验证结果
      VALIDATION.md       # Nyquist 验证策略
      UI-SPEC.md          # UI 设计契约
      UI-REVIEW.md        # UI 审计报告
  milestones/
    v1.0-ROADMAP.md       # 已归档路线图
    v1.0-REQUIREMENTS.md  # 已归档需求
  research/               # 项目级研究
```

---

## 快速恢复参考

| 问题 | 解决方案 |
|------|----------|
| 丢失上下文/新会话 | `/gsd:resume-project` 或 `/gsd:progress` |
| 阶段出错 | `git revert` 回滚，然后重新规划 |
| 需要改变范围 | `/gsd:add-phase`, `/gsd:insert-phase`, `/gsd:remove-phase` |
| 出问题了 | `/gsd:diagnose-issues "描述"` |
| 快速针对性修复 | `/gsd:quick` |
| 计划不符合预期 | `/gsd:discuss-phase [N]` 然后重新规划 |
| 配置设置 | `/gsd:settings` |
| 系统健康检查 | `/gsd:health` 或 `/gsd:health --repair` |
