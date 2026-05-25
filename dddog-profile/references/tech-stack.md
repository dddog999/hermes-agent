# 技术栈参考

## 开发环境

### 操作系统

- **主系统**: Windows
- **开发环境**: WSL (Windows Subsystem for Linux)
- **用户目录**: `/mnt/c/Users/dddog/`

### 文件同步

- **坚果云**: `/mnt/c/Users/dddog/Nutstore/1/myNutstore/`
- **同步内容**: 编程项目、笔记、配置文件

## 编程语言

### Python

- **用途**: 主要开发语言
- **环境**: WSL 内的 Python 环境
- **包管理**: pip / conda

### Node.js

- **用途**: 前端工具、脚本
- **版本**: v20+
- **包管理**: npm / yarn

## 版本控制

### Git

- **远程仓库**: Gitee
- **提交风格**: 使用文件避免引号问题
- **分支策略**: feature/xxx, fix/xxx

### 常用命令

```bash
# 避免引号问题的提交
git commit -F commit_msg.txt

# 查看状态
git status

# 添加特定文件
git add <path>
```

## 笔记系统

### Obsidian

- **主库**: MemVault
- **位置**: `/mnt/c/Users/dddog/Nutstore/1/myNutstore/MemVault/`
- **结构**: CodeBuddyMemory (记忆), CodeBuddyHistory (历史)

### 记忆分类

- **MEMORY.md**: 环境事实、项目约定
- **USER.md**: 用户偏好、沟通风格

## AI 生态

### OpenClaw / ClawMem

- **用途**: AI 助手生态
- **记忆系统**: L0/L1 分层记忆
- **Hook 系统**: 事件驱动的钩子

### CodeBuddy

- **用途**: AI 编程助手
- **记忆格式**: YAML frontmatter + Markdown
- **分类**: project, preference, technical, workflow

## 密码管理

### KeePass

- **数据库**: `/mnt/c/Users/dddog/Nutstore/1/myNutstore/keepass/Database.kdbx`
- **同步**: 坚果云
- **用途**: 存储所有密码和密钥

## 输入法

### 小鹤音形 / 星空键道

- **类型**: 形码输入法
- **词典**: 
  - `srdc.dict.yaml` - 小鹤音形词典
  - `xkjd6.dict.yaml` - 星空键道词典
- **同步**: Rime 输入法同步

## 工具链

### 编辑器

- **Sublime Text**: 配置在坚果云同步
- **VS Code**: 可能使用

### 自动化

- **AutoHotkey**: Windows 自动化
- **Macro Creator**: 宏录制工具

## 项目结构

### 典型结构

```
项目名/
├── .specs/           # 规范文件
├── .sisyphus/        # 项目计划
├── src/              # 源代码
├── tests/            # 测试
├── docs/             # 文档
└── README.md         # 说明
```

### 配置文件

- `.env` - 环境变量（不提交）
- `.gitignore` - Git 忽略规则
- `config.yaml` - 项目配置

## 网络服务

### Gitee

- **用途**: 代码托管
- **认证**: SSH 密钥 / Personal Access Token

### 坚果云

- **用途**: 文件同步
- **WebDAV**: 可能用于自动化同步
