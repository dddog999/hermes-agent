# dddog 用户档案 Skill

这是用户 dddog 的个人工作档案，包含工作偏好、技术栈、开发流程等信息。

## 目录结构

```
dddog-profile/
├── SKILL.md              # 主入口文件
├── README.md             # 本文件
└── references/           # 详细参考
    ├── preferences.md    # 用户偏好详细说明
    ├── workflow.md       # 工作流程参考
    └── tech-stack.md     # 技术栈参考
```

## 使用场景

当处理以下任务时会自动加载：

1. **编程任务** - 遵循 Spec-Driven Development 流程
2. **项目规划** - 使用 GSD 方法论
3. **文档编写** - 遵循用户文档偏好
4. **代码实现** - 先写规范再写代码
5. **Git 操作** - 使用正确的提交方式
6. **记忆提取** - 按照用户定义的分类规则

## 核心原则

### 效率优先

- 快速创建骨架，内容后续填充
- 精简文档，优先实现可工作的代码
- 时间敏感，快速开始

### 规范驱动

- 任务 → Spec 文件 → 实现
- 规范必须通过审查后才能标记完成
- 目录编号与计划保持一致

### 安全删除

- 确保无引用后再删除
- 完整的参数说明和功能描述
- 保留技术细节

## 记忆格式

提取记忆时使用以下 JSON 格式：

```json
{
  "memories": [
    {
      "category": "project|preference|technical|workflow",
      "l0_key": "type/name",
      "l0_description": "简短描述",
      "l1_heading": "主要标题",
      "l1_body": "详细内容",
      "salience": 0.8,
      "keywords": ["关键词1", "关键词2"]
    }
  ]
}
```

## 更新记录

- **2026-04-11**: 初始版本，从 MemVault 提取精华内容
