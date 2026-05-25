---
name: clawmem-guide
description: ClawMem个人记忆管理工具使用指南，包含安装、配置、使用方法和常见问题
user-invocable: true
allowed-tools: "Read, Write, Bash, Glob"
---

# ClawMem 使用指南

## 概述

ClawMem 是一个基于 CLI 的个人记忆管理工具，支持本地存储和可选的向量搜索功能。

## 安装

### 全局安装
```bash
npm install -g clawmem
```

### 本地开发安装
```bash
cd clawmem
npm install
npm run build
npm link
```

## 基本使用

### 添加记忆
```bash
# 添加单条记忆
clawmem add "这是我的记忆内容"

# 添加带标签的记忆
clawmem add "React框架" --tags "前端,JavaScript"

# 添加带来源的记忆
clawmem add "Python教程" --source "https://example.com"
```

### 搜索记忆
```bash
# 基础搜索
clawmem search "搜索词"

# 使用 MMR 多样性重排
clawmem search "搜索词" --mmr

# 限制结果数量
clawmem search "搜索词" --limit 20
```

### 其他命令
```bash
# 列出所有记忆
clawmem list

# 获取特定记忆详情
clawmem get <记忆ID>

# 从文件导入记忆
clawmem import 文件路径

# 显示帮助信息
clawmem --help
```

## 数据存储

### 默认位置
- 默认数据目录：`~/.clawmem`
- 数据库文件：`clawmem.db`

### 自定义数据目录
```bash
# 使用自定义目录
clawmem --data-dir /path/to/data add "记忆内容"

# 使用坚果云同步目录（推荐）
clawmem --data-dir "D:/Nutstore/ClawMem" add "记忆内容"
```

## 向量搜索功能

### 前提条件
需要运行 Ollama 服务：
```bash
# 启动 Ollama
ollama serve

# 下载嵌入模型
ollama pull qwen3-embedding:0.6b
```

### 配置 Ollama
```bash
# 使用默认配置
clawmem add "记忆内容"

# 使用自定义 Ollama 配置
clawmem --ollama-url http://localhost:11434 --ollama-model qwen3-embedding:0.6b add "记忆内容"
```

## 存储策略

### 当前架构
- **单文件存储**：所有数据存储在单个 SQLite 数据库中
- **包含内容**：对话记录和向量 embedding
- **同步问题**：整个数据库文件需要同步

### 推荐分离策略
1. **对话记录**：放在坚果云同步目录
2. **向量检索库**：放在本地不参与同步
3. **配置方式**：通过 `--data-dir` 和 `--embedding-dir` 选项分离

## 常见问题

### 1. 添加记忆时出现 "too many arguments" 错误
**问题**：Windows PowerShell 引号解析问题
**解决**：使用双引号包裹内容，或升级到最新版本（已修复）

### 2. 搜索结果为空
**检查**：
1. 确认记忆已正确添加
2. 检查搜索词是否准确
3. 尝试使用更短的搜索词

### 3. 向量搜索不工作
**排查**：
1. 确认 Ollama 服务运行中
2. 检查模型是否下载：`ollama list`
3. 测试连接：`curl http://localhost:11434/api/tags`

### 4. 同步目录配置
```bash
# 推荐配置方式
clawmem --data-dir "D:/Nutstore/ClawMem" add "记忆内容"

# 或通过环境变量
export CLAWMEM_DATA_DIR="D:/Nutstore/ClawMem"
```

## 高级配置

### 环境变量
- `CLAWMEM_DATA_DIR`：默认数据目录
- `CLAWMEM_OLLAMA_URL`：Ollama API 地址
- `CLAWMEM_OLLAMA_MODEL`：默认嵌入模型

### 配置文件
创建 `~/.clawmem/config.json`：
```json
{
  "dataDir": "D:/Nutstore/ClawMem",
  "ollama": {
    "baseUrl": "http://localhost:11434",
    "model": "qwen3-embedding:0.6b"
  },
  "defaultLimit": 10
}
```

## 工作流程建议

1. **日常使用**：配置坚果云同步目录，自动同步对话记录
2. **搜索性能**：向量搜索仅在本地运行，不依赖网络
3. **备份策略**：定期备份坚果云中的数据库文件
4. **多设备同步**：通过坚果云实现多设备记忆同步

## 相关资源

- [项目仓库](https://github.com/clawmem/clawmem)
- [Ollama 官网](https://ollama.ai)
- [坚果云同步](https://www.jianguoyun.com)

## 故障排除

### 数据库损坏
```bash
# 备份当前数据库
cp ~/.clawmem/clawmem.db ~/.clawmem/clawmem.db.backup

# 重新初始化（会丢失数据）
clawmem --data-dir ~/.clawmem init
```

### 性能优化
```bash
# 限制搜索结果数量
clawmem search "搜索词" --limit 10

# 禁用 MMR 重排（更快）
clawmem search "搜索词" --no-mmr
```