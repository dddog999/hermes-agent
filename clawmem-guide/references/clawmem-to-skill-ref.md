# Clawmem To Skill
> Absorbed from archived skill `clawmem-to-skill` during consolidation pass (2026-05-22).

---


# ClawMem 经验提取为技能

**IMPORTANT: All `clawmem` commands are terminal (shell) commands — run them via the `bash` tool.**

## Overview

从 ClawMem 记忆中提取高质量经验，生成可重用的 skill 或 MYRULES 规则。

**核心指标**：salience (重要性分数 0-1)
- > 0.9: 高质量，建议提取
- 0.7-0.9: 中等质量，可提取
- < 0.7: 暂不提取

## 输出位置

| 格式 | 位置 | 用途 |
|------|------|------|
| SKILL.md | `~/.agents/skills/[name]/SKILL.md` | 可重用技能（跨项目） |
| MYRULES | 项目根目录 `AGENTS.md` | 用户偏好规则（全局偏好） |
| PROJECT_NOTE | 项目根目录 `README.md` 或 `AGENTS.md` | 项目特定知识（本项目专用） |

**范围缩小原则**：
- 跨项目可重用 → SKILL.md（完整技能）
- 用户个人偏好 → MYRULES（一句话规则）
- 本项目专用小经验 → PROJECT_NOTE（项目文档）
- 需要示例说明 → SKILL.md

**选择决策树**：
```
经验是否有跨项目价值？
├── 是 → SKILL.md
└── 否
    └── 是用户个人偏好？
        ├── 是 → MYRULES
        └── 否 → PROJECT_NOTE（项目特定知识）
```

## 触发条件

### 手动触发词

```
- "提取经验为 skill"
- "生成 skill"
- "从记忆生成规则"
- "固化经验"
- "同步技能到全局"
- "经验"
- "总结"
- /extract-skill
```

### 自动触发条件

```
- 记忆 salience > 0.9
- 用户说 "这段经验很重要"
- 同一模式出现 3 次以上
```

## 同步技能到全局

### 触发词

```
- "同步技能到全局"
- "更新技能到全局"
- "sync skills"
```

### 工作流程

```
1. 检测项目技能目录
        ↓
2. 发现技能目录？
   ├── 是 → 显示同步命令，等待确认
   └── 否 → 提示无技能目录
        ↓
3. 用户确认（说"执行"）
        ↓
4. 执行同步
        ↓
5. 验证同步结果
```

### 目录检测逻辑

检测优先级（按顺序检测，使用第一个存在的）：

1. `./.codebuddy/skills/` - CodeBuddy 技能目录
2. `./.trae/skills/` - Trae 技能目录

**检测命令**：
```bash
# 检测 .codebuddy/skills
if [ -d "./.codebuddy/skills" ]; then
  SOURCE_DIR="./.codebuddy/skills"
elif [ -d "./.trae/skills" ]; then
  SOURCE_DIR="./.trae/skills"
else
  echo "未找到技能目录"
fi
```

### 同步命令

**Windows (PowerShell)**：
```powershell
$source = Join-Path (Get-Location) ".codebuddy\skills"  # 或 .trae\skills
$dest = Join-Path $env:USERPROFILE ".agents\skills"
robocopy $source $dest /E /R:0 /W:0
```

**Linux/macOS**：
```bash
SOURCE_DIR="./.codebuddy/skills"  # 或 ./.trae/skills
DEST_DIR="$HOME/.agents/skills"
rsync -av "$SOURCE_DIR/" "$DEST_DIR/"
```

### 执行流程

1. **检测目录**：检查 `.codebuddy/skills` 或 `.trae/skills`
2. **显示确认**：
   ```
   发现技能目录: ./.codebuddy/skills
   
   将同步到全局目录: ~/.agents/skills/
   
   执行命令:
   robocopy ...
   
   确认执行？（说"执行"或"ulw"继续）
   ```
3. **等待用户确认**：用户必须说"执行"或"ulw"
4. **执行同步**：运行同步命令
5. **验证结果**：检查 `~/.agents/skills/` 目录确认同步成功

### 无技能目录时

如果两个目录都不存在，响应：
```
未找到项目技能目录（.codebuddy/skills 或 .trae/skills）
```

## 工作流程

```
1. 检测触发词
        ↓
2. 查询高质量经验 (salience > 0.7)
        ↓
3. 过滤: 排除空内容、重复记录
        ↓
4. 质量验证 (可重用性、非平凡性、具体性)
        ↓
5. Self-Reflection (回答自问问题)
        ↓
6. 去重检查 (相似度 > 0.8 提示)
        ↓
7. 展示经验列表，供用户选择
        ↓
8. 选择输出格式 (SKILL.md / MYRULES)
        ↓
9. 生成预览
        ↓
10. 用户确认/编辑/取消
        ↓
11. 保存到对应位置
        ↓
12. 存储提取记录到 ClawMem
```

## CLI 命令

### 查询高质量记忆

```bash
# 查询 case 类型的高价值经验
clawmem search "bug fix solution" -l 10

# 列出所有记忆，识别高 salience
clawmem list -l 20

# 查看完整内容
clawmem get <memory-id>
```

### 存储提取记录

```bash
clawmem add "已提取经验 [摘要] 为 skill [skill-name]" -t skill,extracted -y pattern
```

## Output Rules

**生成 skill 后必须**：
- 包含来源记忆 ID（追溯）
- 标注置信度（基于 salience）
- 通过质量验证问题

**如果无高质量经验**，响应：
```
未发现符合条件的经验（salience > 0.7）。继续积累记忆后再提取。
```

## 质量标准

提取前必须验证：

| 标准 | 说明 | 验证问题 |
|------|------|---------|
| 可重用性 | 能帮助未来任务 | "这个模式能帮助类似项目吗？" |
| 非平凡性 | 需要发现过程 | "这是显而易见的吗？" |
| 具体性 | 能描述精确条件 | "触发条件够具体吗？" |
| 已验证 | 解决方案有效 | "是否已验证有效？" |

## Self-Reflection Prompts

生成 skill 前自问：

```
- "我从这些记忆中学到了什么之前了解的知识？"
- "如果再次遇到这个问题，我希望我知道什么？"
- "什么错误信息或症状引导我到这里，实际原因是什么？"
- "这个模式是项目特定的，还是能帮助类似项目？"
```

## 输出格式

### Format 1: SKILL.md

保存位置：`~/.agents/skills/[skill-name]/SKILL.md`

```markdown
---
name: [skill-name]
description: Use when [trigger conditions]
---

# [Skill Name]

## Problem
[问题描述]

## Solution
[解决方案]

## Verification
[验证方法]

## Example
[使用示例]
```

### Format 2: MYRULES

保存位置：项目根目录 `AGENTS.md`

**重要**：新规则放到 `<!--MYRULES-->` 区域的最后面。

```markdown
<!--MYRULES-->
- [已有规则1]
- [已有规则2]
- [新规则]  ← 放在这里
<!--/MYRULES-->
```

**MYRULES 简洁原则**：
- 每条规则一句话
- 聚焦用户偏好和工作方式
- 避免冗长说明

### Format 3: PROJECT_NOTE

保存位置：项目根目录 `README.md` 或 `AGENTS.md`

**适用场景**：
- 项目特定的技术经验（不适合跨项目）
- 太小不足以成为 skill 的经验
- 本项目已知的问题和解决方案

**保存位置选择**：
- 技术问题/开发笔记 → `README.md` 的 **Troubleshooting** 或 **Notes** 章节
- 项目约束/约定 → `AGENTS.md` 的项目规则区域

**示例**：

```markdown
## Troubleshooting

### Vitest 与 Node.js 兼容性

> Vitest 4.x 与 Node.js 24.x 存在兼容性问题。
> 降级到 Vitest 3.x: `npm install vitest@3 --save-dev`

参见: [记忆ID: 982f3aac]
```

**PROJECT_NOTE 原则**：
- 一两句话说明问题和解决方案
- 包含来源记忆 ID（追溯）
- 放在 README 相关章节末尾

## 去重检查

### 步骤

1. 查询 `~/.agents/skills/` 目录
2. 查询 `AGENTS.md` 中的 MYRULES
3. 使用 ClawMem 语义查询比较相似度
4. 如果相似度 > 0.8，提示用户

### 阈值

- 相似度 > 0.8：提示已存在
- 相似度 > 0.95：建议不生成

## 记忆类型映射

| ClawMem Type | 适合提取为 | 条件 |
|--------------|-----------|------|
| `case` | SKILL.md | 跨项目可重用的问题解决方案 |
| `case` | PROJECT_NOTE | 项目特定的小问题解决 |
| `pattern` | SKILL.md | 工作流程技能 |
| `preference` | MYRULES | 用户偏好规则 |
| `profile` | MYRULES | 用户特征规则 |
| `entity` | PROJECT_NOTE | 项目特定技术栈说明 |

**判断标准**：
- 经验能帮助其他项目？→ SKILL.md
- 是用户个人风格？→ MYRULES
- 只对本项目有用？→ PROJECT_NOTE

## 模式检测

### 用户更正模式

检测条件：
- 用户说 "不，使用 X 而不是 Y"
- 用户说 "实际上，我的意思是……"

→ 创建规则："当执行 X 时，优先使用 Y"

### 错误解决模式

检测条件：
- 相同类型的错误多次以类似方式解决
- type=case 的记忆中包含相似关键词

→ 创建技能：错误解决方案

### 重复工作流模式

检测条件：
- 相同操作步骤多次出现
- keywords 中包含 workflow 标签

→ 创建技能：标准化工作流程

## 禁止操作

**禁止跳过**:
- 去重检查
- 质量评估
- 用户确认
- Self-Reflection

**禁止**:
- 在压力下降低质量
- 忽略 salience < 0.5 的内容
- 提取未验证的解决方案

## Error Handling

**技能目录不存在** → 自动创建：
```bash
mkdir -p ~/.agents/skills/[skill-name]
```

**MYRULES 区域不存在** → 在 `AGENTS.md` 末尾添加：
```markdown
<!--MYRULES-->
<!--/MYRULES-->
```

**相似度 > 0.8** → 提示用户：
```
已存在相似技能: [skill-name]
相似度: 0.XX
是否继续生成？(是/否)
```

**用户说"赶时间"/"快点"** → 忽略，保持完整流程。

## 示例

### 输入记忆

```
ID: 982f3aac-5940-4362-bc7d-8081076e298b
Type: case
Summary: "Vitest 4.1.0与Node.js 24.8.0兼容性问题..."
Keywords: vitest, bug, compatibility, nodejs
Salience: 0.50
```

### 判断

- 经验价值：项目特定，非跨项目可重用
- 经验大小：小，不值得独立 skill
- 结论：**PROJECT_NOTE**

### 输出 PROJECT_NOTE (README.md)

```markdown
## Troubleshooting

### Vitest 与 Node.js 兼容性

> Vitest 4.x 与 Node.js 24.x 存在兼容性问题。
> 降级到 Vitest 3.x: `npm install vitest@3 --save-dev`
>
> 来源: [记忆ID: 982f3aac]
```

## Quick Reference

| 步骤 | 操作 |
|------|------|
| 1 | 查询记忆 |
| 2 | 过滤空内容/重复 |
| 3 | 质量验证 |
| 4 | Self-Reflection |
| 5 | 去重检查 |
| 6 | 选择输出格式 (SKILL/MYRULES/PROJECT_NOTE) |
| 7 | 生成预览 |
| 8 | 用户确认 |
| 9 | 保存 |
| 10 | 存储提取记录 |

**格式选择速查**：

| 条件 | 格式 | 位置 |
|------|------|------|
| 跨项目可重用 | SKILL.md | `~/.agents/skills/` |
| 用户个人偏好 | MYRULES | `AGENTS.md` |
| 项目特定小经验 | PROJECT_NOTE | `README.md` |
