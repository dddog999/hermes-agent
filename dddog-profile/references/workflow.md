# 工作流程参考

## Spec-Driven Development 流程

### 标准流程

```
任务输入
    ↓
创建 Spec 文件 (.specs/NN-name.spec.md)
    ↓
Spec 审查
    ↓
实现代码
    ↓
验证测试
    ↓
标记完成
```

### Spec 文件模板

```markdown
# Spec: [功能名称]

## Scope
- 范围描述
- 边界说明

## Upstream references
- 相关依赖
- 参考文档

## Key points
- 核心要点1
- 核心要点2
- 核心要点3

## TODO
- 由后续AI助手填写
```

### 目录组织

```
项目根目录/
├── .specs/                    # 规范文件
│   ├── meta/                  # 规范格式规则
│   │   └── spec-format.spec.md
│   ├── 01-project-structure/  # 按编号组织
│   │   └── 01-directory-structure.spec.md
│   ├── integration/           # 集成规范
│   │   └── end-to-end.spec.md
│   └── uncertainties/         # 待定决策
│       └── agent-protocol.md
├── .sisyphus/                 # 项目计划
│   └── plans/
│       └── 001-xxx-plan.md
└── 项目文件...
```

## GSD 方法论

### 阶段划分

| 阶段 | 目标 | 产出 |
|------|------|------|
| Research | 调研、理解需求 | 需求文档、技术调研 |
| Planning | 规划、设计架构 | 架构图、任务分解 |
| Execute | 执行、实现功能 | 代码、配置文件 |
| Verify | 验证、测试确认 | 测试报告、验证结果 |

### 命令格式

- `/gsd:discuss-phase` - 进入调研阶段
- `/gsd:plan-phase` - 进入规划阶段
- `/gsd:execute-phase` - 进入执行阶段
- `/gsd:note` - 添加笔记
- `/gsd:status` - 查看状态

## Git 工作流

### 提交信息

使用文件避免 PowerShell 引号问题：

```bash
# 1. 创建提交信息文件
echo "feat: Add spec-driven development skeleton" > commit_msg.txt

# 2. 使用文件提交
git commit -F commit_msg.txt

# 3. 删除临时文件
rm commit_msg.txt
```

### 分支策略

- `feature/xxx` - 功能分支
- `fix/xxx` - 修复分支
- `reimpl/xxx` - 重实现分支

## 记忆提取流程

### 分类标准

| 类型 | 判断标准 | 示例 |
|------|----------|------|
| project | 项目决策/状态/架构 | "项目采用X架构" |
| preference | 用户偏好/习惯 | "用户偏好Y工具" |
| technical | 技术方案/问题解决 | "用Z框架解决了A问题" |
| workflow | 流程/模式/最佳实践 | "使用GSD方法论" |

### 输出格式

```json
{
  "memories": [
    {
      "category": "preference",
      "l0_key": "user/prefers-skeleton",
      "l0_description": "用户偏好快速骨架",
      "l1_heading": "快速骨架优先",
      "l1_body": "用户希望快速创建目录和文件结构，内容后续填充",
      "salience": 0.8,
      "keywords": ["skeleton", "minimal", "time-saving"]
    }
  ]
}
```

### 提取规则

1. 确保信息具备长期复用价值
2. 优先保留具体名词、参数名、版本号等技术细节
3. 最多 8 条，按重要性排序
4. 纯 JSON 输出，无额外文字
