# dida365-cli 使用注意

## 安装
```bash
npm install -g dida365-ai-tools
```

## 输出解析
CLI 通过 stdio 通信，**所有命令输出**均包含 `[dida365-ai-tools] Server running on stdio` 前缀。`jq` 不可用，解析 JSON 用 `grep -o`。

## 常用命令

```bash
# 认证状态
dida365 auth status

# 获取 inboxId（创建任务时需要 projectId）
dida365 sync all --json 2>&1 | grep -o 'inboxId[^,]*'
# 输出示例: inboxId": "inbox1011271911"

# 列出项目
dida365 project list

# 创建任务（收件箱）
dida365 task create "<标题>" -p inbox1011271911 -d 2026-05-17 --priority 3
```

## 任务创建参数
- `-p <projectId>` — 项目 ID（必填）
- `-d <date>` — 截止日期（ISO 8601: YYYY-MM-DD）
- `--priority <n>` — 优先级：0=无, 1=低, 3=中, 5=高
- `-c <content>` — 任务内容/描述
