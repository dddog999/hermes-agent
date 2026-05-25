---
name: clawmem-usage
description: Use when conversation starts or user mentions preferences, problems solved, or decisions made. Guides AI on clawmem memory storage and retrieval using CLI commands.
context: inline
allowed-tools: Bash
---

# ClawMem 使用指南

**IMPORTANT: All `clawmem` commands are terminal (shell) commands — run them via the `bash` tool.**

## Overview

ClawMem 是个人记忆管理系统，采用分层存储架构：
- **L0**: 关键词标签（快速索引）
- **L1**: 摘要（~200字，默认返回）
- **L2**: 完整内容（按需获取）

**核心原则**：
- **存储**: 根据存储模式决定（见下方）
- **查询**: 回答需要用户背景吗？→ 需要就先查询
- **反馈**: 操作后必须告知用户

## 存储模式

| 模式 | 说明 | 适用场景 |
|------|------|----------|
| `smart`（默认） | 3个月法则，只存有价值信息 | 日常使用 |
| `full` | 全量记录所有对话 | 需要完整历史追溯 |

**切换模式**：
```bash
clawmem config set storageMode full   # 全量模式
clawmem config set storageMode smart  # 智能模式（默认）
```

**Full 模式行为**：
- 每次 AI 回复后自动存储对话摘要
- 用户说"记住"时存储完整内容
- 自动提取关键词标签

## 配置检查

**首次使用前确认**：
```bash
# 检查配置
clawmem config

# 如果无配置，初始化
clawmem config init
```

**配置文件位置**: `~/.clawmem/config.json`

## 决策流程

### 会话开始

```
会话开始
    │
    ▼
┌─────────────────────┐
│ clawmem search recent │  ← 查询最近记忆
│ clawmem list -l 5    │
└─────────────────────┘
    │
    ▼
┌─────────────────────┐
│ 向用户确认上下文     │
└─────────────────────┘
```

### 查询决策

```
用户输入
    │
    ▼
┌─────────────────────┐
│ 会话开始？          │──是──▶ 查询最近记忆
└─────────────────────┘
    │否
    ▼
┌─────────────────────┐
│ 涉及推荐/建议？     │──是──▶ 查询用户偏好
└─────────────────────┘
    │否
    ▼
┌─────────────────────┐
│ "我之前说过/做过"？ │──是──▶ 立即查询
└─────────────────────┘
    │否
    ▼
┌─────────────────────┐
│ 类似问题已解决？    │──是──▶ 查询经验案例
└─────────────────────┘
    │否
    ▼
   直接回答
```

### 存储决策

```
关键信息产生
    │
    ▼
┌─────────────────────┐
│ 存储模式 = full？   │──是──▶ 存储对话摘要
└─────────────────────┘
    │否 (smart模式)
    ▼
┌─────────────────────┐
│ 用户说关键词？      │──是──▶ 立即存储完整内容
│ "记住"、"以后要"    │
│ "不要"、"必须"      │
└─────────────────────┘
    │否
    ▼
┌─────────────────────┐
│ 用户偏好/身份？     │──是──▶ 存储 type=profile/preference
└─────────────────────┘
    │否
    ▼
┌─────────────────────┐
│ 问题已解决？        │──是──▶ 存储 type=case
└─────────────────────┘
    │否
    ▼
┌─────────────────────┐
│ 3个月后还有价值？   │──是──▶ 存储 type=event
└─────────────────────┘
    │否
    ▼
   不存储
```

## CLI 命令速查

| 场景 | 命令 |
|------|------|
| 查询记忆 | `clawmem search <query>` |
| 列出最近 | `clawmem list -l 10` |
| 存储记忆 | `clawmem add "内容" -t tag1,tag2 -y type` |
| 查看详情 | `clawmem get <id>` |
| 删除记忆 | `clawmem delete <id>` |

## 记忆类型

| Type | 用途 | 示例 |
|------|------|------|
| `profile` | 用户画像 | "用户是后端开发者" |
| `preference` | 偏好 | "用户喜欢简洁回答" |
| `entity` | 实体 | "项目使用 TypeScript" |
| `event` | 事件 | "今天完成了 X 功能" |
| `case` | 案例 | "问题 X 的解决方案" |
| `pattern` | 模式 | "调试流程: 先复现再定位" |

## 存储模板

### Full 模式对话摘要

```bash
# 每次 AI 回复后自动执行
clawmem add "[用户问题摘要] → [AI回答要点]" -t conversation,auto -y event
```

**示例**：
```bash
clawmem add "用户询问salience和hotness区别 → 解释: salience是存储的重要性分数, hotness是运行时热度计算" -t conversation,auto -y event
```

### 用户偏好

```bash
clawmem add "用户偏好简洁直接的回答风格，避免冗长解释" -t preference,style -y preference
```

### 问题解决案例

```bash
clawmem add "问题: [场景]出现[错误]; 原因: [根因]; 解决: [方法]; 效果: [结果]" -t bug,fix,[技术栈] -y case
```

### 工作流程

```bash
clawmem add "流程: [任务类型] → 步骤1 → 步骤2 → 步骤3" -t workflow,[领域] -y pattern
```

## 反馈机制

**存储后**：
```
✓ 已存储: [记忆摘要]
```

**查询后**：
```
找到 N 条相关记忆:
- [摘要1]
- [摘要2]
```

## 常见错误

| 错误 | 解决 |
|------|------|
| Smart 模式忘记存储 | 检查是否说"记住"等关键词 |
| Full 模式记忆过多 | 定期清理或切换回 smart |
| 忘记查询 | 涉及用户背景必先查 |
| 经验散乱 | 用结构化模板 |
| 黑盒操作 | 操作后告知用户 |
| `command not found: clawmem` | 先 `npm run build` 编译项目 |
| `Cannot find module` | 检查 `dist/cli/index.js` 是否存在 |
| `Ollama not available` | 向量搜索不可用，降级为 BM25 文本搜索 |

## Error Handling

**`command not found: clawmem`** → 项目未编译，执行：
```bash
cd c:/Users/kangle/clawmem && npm run build
```

**`Ollama not available`** → 向量搜索不可用，但 BM25 文本搜索仍可工作。如需向量搜索：
```bash
# 启动 Ollama
ollama serve

# 确认模型已下载
ollama list | grep qwen3-embedding
```

**配置文件丢失** → 自动检测坚果云路径，或手动配置：
```bash
clawmem config set syncDir "C:/Users/kangle/Nutstore/1/myNutstore/clawmem"
```

## Quick Reference

| 情况 | 操作 | 反馈 |
|------|------|------|
| 会话开始 | `clawmem list -l 5` | 告知最近记忆 |
| Full 模式每次回复 | 存储对话摘要 | ✓ 已记录 |
| 用户说"记住" | 立即存储完整内容 | ✓ 已存储 |
| 用户说"我喜欢" | 存储 preference | ✓ 已存储偏好 |
| 用户问"我之前" | 立即查询 | 列出相关记忆 |
| 问题解决 | 存储 case | ✓ 已存储经验 |
| 推荐/建议 | 先查偏好 | 基于偏好回答 |

## 完整会话示例

### 示例 1: 会话开始

```
[AI 执行]
$ clawmem list -l 3

[结果]
#1 [case] Vitest 4.1.0与Node.js 24不兼容 - 降级到3.2.4
#2 [preference] 用户喜欢简洁直接的回答风格
#3 [entity] 项目使用 TypeScript + Vitest

[AI 回复]
找到 3 条最近记忆:
- 上次解决了 Vitest 兼容性问题
- 你偏好简洁回答
- 项目是 TypeScript + Vitest

有什么需要帮忙的？
```

### 示例 2: Full 模式对话记录

```
[用户] salience 和 hotnessScore 有什么区别？

[AI 回复]
Salience 是存储的重要性分数...（解释省略）

[AI 执行 - Full 模式自动]
$ clawmem add "用户询问salience和hotnessScore区别 → 解释: salience是存储值表示重要性, hotnessScore是运行时热度计算用于排序" -t conversation,auto -y event

[AI 反馈]
✓ 已记录对话
```

### 示例 3: 用户表达偏好

```
[用户] 以后遇到框架兼容问题，先查 GitHub issues

[AI 执行]
$ clawmem add "遇到框架兼容问题优先查 GitHub issues 搜索相关报错" -t debugging,framework -y preference

[AI 回复]
✓ 已存储偏好
```

### 示例 4: 问题解决后存储经验

```
[用户] 问题解决了，是因为配置文件路径写错了

[AI 执行]
$ clawmem add "问题: 配置加载失败; 原因: 路径写错; 解决: 检查相对路径基准点" -t config,bug,path -y case

[AI 回复]
✓ 已存储经验
```

### 示例 5: 查询用户背景

```
[用户] 帮我写个测试

[AI 执行]
$ clawmem search "test preference"

[结果]
#5 [preference] 用户偏好使用 Vitest 测试框架
#8 [pattern] 测试命名规范: describe/it/expect

[AI 回复]
根据你的偏好，用 Vitest 写测试。命名规范用 describe/it/expect。

要测试什么功能？
```
