# Openviking Usage
> Absorbed from `openviking-usage` — OpenViking vector DB configuration and usage notes.

---


# OpenViking 使用指南

## 服务信息
- Endpoint: 见环境变量 OPENVIKING_ENDPOINT
- API Key: 见环境变量 OPENVIKING_API_KEY

## 核心操作

### 1. 上传资源（两步）
```bash
# 第一步: 上传文件拿到 temp_file_id
TEMP_ID=$(curl -s -X POST $OV_ENDPOINT/api/v1/resources/temp_upload \
  -H "Authorization: Bearer $OV_KEY" \
  -F "file=@/path/to/file.md" | jq -r '.result.temp_file_id')

# 第二步: 添加到 resources（wait=false 避免超时）
curl -s -X POST $OV_ENDPOINT/api/v1/resources \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $OV_KEY" \
  -d "{\"temp_file_id\":\"$TEMP_ID\",\"to\":\"viking://resources/my-resource\",\"reason\":\"说明\",\"wait\":false}"
```

### 2. 搜索
```bash
curl -s -X POST $OV_ENDPOINT/api/v1/search/search \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $OV_KEY" \
  -d '{"query":"关键词","scope":"resources","limit":5}'
```

### 3. 读取内容
```bash
curl -s "$OV_ENDPOINT/api/v1/content/read?uri=viking://resources/xxx" \
  -H "Authorization: Bearer $OV_KEY"
```

### 4. 浏览目录
```bash
curl -s "$OV_ENDPOINT/api/v1/fs/ls?uri=viking://resources" \
  -H "Authorization: Bearer $OV_KEY"
```

### 5. 写入记忆
```bash
curl -s -X POST $OV_ENDPOINT/api/v1/content/write \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $OV_KEY" \
  -d '{"uri":"viking://agent/memories/xxx.md","content":"内容"}'
```

## Hermes 工具映射
| 工具 | API | 注意 |
|------|-----|------|
| viking_search | POST /search/search | 正常 |
| viking_read | GET /content/read | 正常 |
| viking_browse | GET /fs/ls | 正常 |
| viking_remember | POST /content/write | 正常 |
| viking_add_resource | POST /resources | 字段名不匹配, 需手 curl |

## 常见错误
| 错误 | 原因 | 解决 |
|------|------|------|
| 403 Missing API Key | 没传 Authorization | 加 header |
| extra_forbidden | 字段名错误 | 用 temp_file_id, 不是 url/content |
| DEADLINE_EXCEEDED | 大文件 wait=true | 改 wait=false |
| 429 Jina 限流 | 不带 key | 加 JINA_API_KEY header |

## URI 结构
- viking://resources/ — **同 account 共享**（三台机器都能读写）
- viking://agent/memories/ — Agent 记忆（**v0.3.8: 仅本 user 可访问，不支持跨 user 共享**）
- viking://user/memories/ — 用户记忆（按 user_id 隔离）
- viking://sessions/ — 会话上下文

## 多租户 Admin API（root key 需要）
```bash
ROOT_KEY=<从 ov.conf 的 server.root_api_key 读取>

# 列出 accounts
curl -s $OV_ENDPOINT/api/v1/admin/accounts \
  -H "Authorization: Bearer $ROOT_KEY" \
  -d '{"account_id":"hermes","admin_user_id":"root"}'

# 列出 users
curl -s "$OV_ENDPOINT/api/v1/admin/accounts/ACCOUNT/users?admin_user_id=root" \
  -H "Authorization: Bearer $ROOT_KEY"

# 重新生成 user key（旧 key 立即失效）
curl -s -X POST "$OV_ENDPOINT/api/v1/admin/accounts/ACCOUNT/users/USER/key" \
  -H "Authorization: Bearer $ROOT_KEY" \
  -d '{"admin_user_id":"root"}'
# 返回: {"result":{"user_key":"xxx"}}
```

## L0/L1/L2 摘要层级

| 层级 | 文件 | 大小 | 用途 |
|------|------|------|------|
| L0 | `.abstract.md` | ~100 tokens | 向量搜索索引（**搜索依赖这个**） |
| L1 | `.overview.md` | ~2k tokens | Rerank 精排、导航指引 |
| L2 | 原始文件 | 无限制 | 完整内容，按需读取 |

- **搜索搜不到？** → L0 还没生成（异步队列），等 deriver 处理
- **直接读全文不需要等** → `viking_read(level="full")` 随时可用
- 生成顺序：叶子节点 → 父目录 → 根目录（自底向上）
- **实际文件路径有 hash 后缀**：上传后 browse 看到的是目录，实际文件在子目录里（如 `upload_xxx.md`），先 browse 找到真实 URI 再 read

## 会话自动记录

- Hermes 对话**自动推送到 OV session**（session_id 对应 Hermes session ID）
- OV deriver 后台异步处理，提取观察/记忆
- session 位置：`viking://session/{user}/{session_id}/`
- 内容结构：`messages.jsonl`（当前）+ `history/archive_NNN`（归档片段）
- 归档片段有 L0 摘要，session 级别 L1 通常未生成
- **这不是手动存入**——每次对话都会自动记录，无需干预

## 已知限制（v0.3.8）
- `agent_scope_mode` 只接受 `user+agent` 或 `agent`（`account` 会报错）
- config 不支持 `namespace` 字段（Unknown config field）
- **agent 记忆不支持跨 user 共享**：即使用 root key 也不行，PermissionError
- `isolate_agent_scope_by_user` 配置在 v0.3.8 不可用（Admin API 无此端点）
- **共享方案：用 `viking://resources/` 存需共享的内容，agent 记忆仅本机私有**

## 多机器项目协作 — 项目制进度追踪

按项目建目录（不按机器），任何机器都能追加进度：

```
viking://resources/projects/{项目名}/
├── progress.md   ← 进度记录（标注 [机器名] 日期）
└── context.md    ← 项目说明/交接指引
```

```markdown
# progress.md 格式
## [kangle] 2026-04-20 22:00
- 完成了 xxx
- 下一步: yyy

## [workbuddy] 2026-04-21 09:00
- 接力处理 yyy，卡在 zzz
```

创建目录: POST /api/v1/fs/mkdir `{"uri":"viking://resources/projects/项目名"}`
上传文件: temp_upload + POST /resources `{"to":"viking://resources/projects/项目名/progress","wait":false}`

## 启动/重启
```bash
pkill -f openviking; sleep 2
nohup openviking-server --port 1933 --host 0.0.0.0 > /tmp/openviking.log 2>&1 &
sleep 5 && curl -s http://127.0.0.1:1933/health
```
