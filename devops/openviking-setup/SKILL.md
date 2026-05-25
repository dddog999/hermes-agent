---
name: openviking-setup
description: 安装部署 OpenViking 上下文数据库服务器，配置 Hermes 连接。解决依赖安装超时、火山云 SDK 绕过、embedding 配置等坑。含多租户配置。
---

# OpenViking 安装部署指南

## 架构

```
OpenViking Server (:1933)  ← HTTP → Hermes OpenViking Plugin (只需 httpx)
```

Hermes 插件是纯 HTTP 客户端，不依赖 openviking Python 包。服务器单独运行。

## 安装

```bash
pip install openviking
```

### 常见坑：依赖安装超时

wooking 上 pip 下载慢，逐个装依赖。关键依赖链：
```
argon2-cffi → fastapi → uvicorn → pydantic → aiosqlite → sqlmodel → 
loguru → Pillow → apscheduler → json-repair → litellm
```

**volcengine SDK 无法安装？** 创建空桩绕过。

## 配置

文件：`~/.openviking/ov.conf`

### 基础配置（单机）

```json
{
  "server": {
    "host": "0.0.0.0",
    "port": 1933,
    "root_api_key": "生成的密钥"
  },
  "embedding": {
    "dense": {
      "provider": "jina",
      "model": "jina-embeddings-v3",
      "api_key": "jina_xxx",
      "dimension": 1024
    }
  },
  "vlm": {
    "provider": "openai",
    "model": "google/gemini-2.5-flash-preview",
    "api_base": "https://openrouter.ai/api/v1",
    "api_key": "sk-or-xxx"
  },
  "storage": {
    "workspace": "./data",
    "vectordb": { "backend": "local" }
  }
}
```

## 启动

```bash
openviking-server --port 1933 --host 0.0.0.0 &
curl -s http://localhost:1933/health
```

## Hermes 连接

在 Hermes 的 `.env` 中添加：
```
OPENVIKING_ENDPOINT=http://127.0.0.1:1933
OPENVIKING_API_KEY=你的root_api_key或user_key
OPENVIKING_USER=wooking
OPENVIKING_AGENT=hermes-wooking
```

**重要**：`memory.provider` 设在 `config.yaml`，不是 `.env`：
```yaml
memory:
  provider: openviking
```

## 多租户配置

### 关键理解

- `config.yaml` 中的 `memory.provider` 控制使用哪个 provider（不是 env 变量）
- `ov.conf` 是 JSON 格式
- 非 localhost 绑定必须配 `root_api_key`
- user key 认证后服务端自动解析身份

### 步骤

**1. Admin API 创建 account + users**

```bash
ROOT_KEY="your_root_key"

# 创建 account + 首个 admin
curl -X POST http://server:1933/api/v1/admin/accounts \
  -H "X-API-Key: $ROOT_KEY" \
  -H "Content-Type: application/json" \
  -d '{"account_id": "hermes", "admin_user_id": "wooking"}'

# 注册其他 user
curl -X POST http://server:1933/api/v1/admin/accounts/hermes/users \
  -H "X-API-Key: $ROOT_KEY" \
  -H "Content-Type: application/json" \
  -d '{"user_id": "kangle", "role": "user"}'
```

**2. 各机器用各自的 user key**

每台机器的 `.env` 用拿到的 user_key 作为 `OPENVIKING_API_KEY`。

### 验证

```bash
curl -s -H "Authorization: Bearer <user_key>" http://server:1933/api/v1/system/status
```

### 数据隔离

| 数据类型 | 隔离边界 | 跨读方式 |
|----------|----------|----------|
| user memory | user_id | ROOT key + X-OpenViking-User header |
| session | user_id | 同上 |
| resources | account（共享） | 同 account 自动可读 |

## Resources 写入 API（踩坑记录）

写入 resources 文件的正确流程是**两步**：先 temp_upload，再 register。

```bash
# Step 1: 上传文件到临时区
TEMP_ID=$(curl -s -X POST \
  -H "Authorization: Bearer <user_key>" \
  -H "X-OpenViking-Account: hermes" \
  -H "X-OpenViking-User: wooking" \
  -F "file=@/path/to/file.md" \
  http://server:1933/api/v1/resources/temp_upload | python3 -c "import sys,json;print(json.load(sys.stdin)['result']['temp_file_id'])")

# Step 2: 注册为正式资源
curl -s -X POST \
  -H "Authorization: Bearer <user_key>" \
  -H "Content-Type: application/json" \
  -H "X-OpenViking-Account: hermes" \
  -H "X-OpenViking-User: wooking" \
  -d "{\"temp_file_id\":\"$TEMP_ID\",\"path\":\"viking://resources/your/path.md\"}" \
  http://server:1933/api/v1/resources
```

**踩坑**：`path` 参数不一定控制最终 URI，服务端可能用 `temp_file_id` 命名。`content/write` 端点只用于更新已有文件，不能创建新文件。`viking_add_resource` 工具返回 403（不发送租户 headers），必须用手动 curl 两步流程。

## 记忆检索流程

- `viking_remember` 存储后不会立即可搜，需要 **session commit** 才会索引
- commit 是异步的，提交后需等几秒再搜索
- `resources` 上传后可立即通过 `content/read` 读取

```bash
# 手动 commit session
curl -s -X POST -H "Authorization: Bearer <user_key>" \
  http://server:1933/api/v1/sessions/<session_id>/commit
```

### 搜索返回空/异常排查（2026-04-18 验证）

**情况 A：browse 正常但 search 返回空（不是 500，是空结果）**

这是 **Hermes 会话状态 stale** 问题，不是 OV 服务端问题。

**根因**：Hermes Agent 的 AIAgent 会话在初始化时缓存了 OV 连接状态（OV_ENDPOINT、OV_API_KEY 等）。.env 或 config.yaml 改完后，现有会话不会刷新内部缓存，仍然用旧的（可能是 None/空的）OV 实例。browse 用的是直接 HTTP 请求所以不受影响，search 走的是会话缓存的 OV client 所以返回空。

**判断方法**：
- `viking_search` 返回 `{"results": [], "total": 0}` 但 `viking_browse` 能正常列出目录
- 说明 OV 服务端正常，是会话侧的 client 状态问题

**解法**：开新会话（`/new`），不要在旧会话里调试。旧会话的 model/config 变更都不生效（和"状态栏模型不随 config 变"是同一机制）。

**预防**：重要配置变更后（换 OV endpoint/key、换 embedding provider），确认开了新会话再工作。

**情况 B：search 返回 500**

**根本原因：embedding 后端挂了，不是索引竞态。**

排查流程：
1. browse 正常但 search 500 → 几乎一定是 embedding 问题
2. 直接测试 embedding API：`curl POST https://api.jina.ai/v1/embeddings` 用 ov.conf 里的 key
3. 如果 embedding API 返回 401/400 → 换 key 或换 provider

**其他已知问题：**
- 搜索结果偏向目录元数据（`.overview.md`），分数偏低（0.2-0.5）
- `viking_remember` 需 session commit 后才可搜到
- **切换 embedding 后端后，旧索引不兼容，必须重新 commit session 才能搜到旧数据**
- 精确检索仍依赖 `session_search`（Hermes 内置 FTS5）

## 多模态 Embedding

当前支持的多模态 embedding 模型：

| 模型 | Provider | 输入类型 | 维度 |
|------|----------|----------|------|
| doubao-embedding-vision-251215 | volcengine | 文本+图片 | 1024 |
| tongyi-embedding-vision-plus | dashscope | 文本+图片 | 1152 |
| qwen3-vl-embedding | dashscope | 文本+图片+视频 | 2560 |

配置时加 `"input": "multimodal"`：
```json
{
  "embedding": {
    "dense": {
      "provider": "jina",
      "api_key": "***",
      "model": "jina-embeddings-v3",
      "dimension": 1024,
      "input": "multimodal"
    }
  }
}
```

**自定义 API 地址**：所有 provider 都支持 `api_base` 字段。开源模型（如 Qwen3-Embedding-8B）可用 `provider: "openai"` + 自定义 `api_base`。

## Gateway 重启

修改 `config.yaml`（memory.provider）或 `.env`（OPENVIKING_API_KEY）后，**必须重启 gateway**。Hermes 的 memory provider 在 gateway 启动时初始化，运行中不热加载配置变更。

```bash
# systemd 管理的
systemctl --user restart hermes-gateway

# 手动启动的
kill $(ps aux | grep "gateway run" | grep -v grep | awk '{print $2}')
nohup python -m hermes_cli.main gateway run --replace &
```

## Gitee AI Embedding（模力方舟）

Gitee AI（模力方舟）提供 embedding API，OpenAI 兼容格式。

### 前置条件
**必须绑定资源包**，否则所有 API 调用返回 400。
- **全模型资源包**：购买后自动绑定所有 token，推荐
- **算力资源包**：需手动绑定 token
- 免费额度：每账号每天 100 次，但也需要有资源包才能生效
- 购买入口：https://ai.gitee.com → 工作台 → 全模型资源包购买页

### 配置示例（ov.conf）
```json
"embedding": {
  "dense": {
    "provider": "openai",
    "model": "Qwen3-Embedding-0.6B",
    "api_base": "https://ai.gitee.com/v1",
    "api_key": "你的token",
    "dimension": 1024
  }
}
```

### 已验证的 embedding 模型（2026-04-18 wooking 实测）

| 模型 | 维度 | 语义区分度 | 备注 |
|------|------|-----------|------|
| jina-embeddings-v4 | 2048 | 较好（相关0.6-0.7 vs 不相关0.3-0.4） | ✅ 推荐 |
| Qwen3-Embedding-0.6B | 1024 | 正常 | ✅ 备选 |

### 配置示例（jina-v4 via Gitee AI）

```json
"embedding": {
  "dense": {
    "provider": "openai",
    "model": "jina-embeddings-v4",
    "api_base": "https://ai.gitee.com/v1",
    "api_key": "Gitee AI token",
    "dimension": 2048
  }
}
```

**注意**：Gitee AI embedding 需绑定资源包（全模型资源包自动绑定），否则 400。
- 购买入口：https://ai.gitee.com → 工作台 → 全模型资源包购买页
- 免费额度（100次/天）也需要先有资源包才能生效
- 列出可用模型：`GET /v1/models`（token 有效即可，不需要资源包）

## 换 Embedding Provider 后必须

1. **重启 OpenViking server**（`kill <pid>` 再启动）
2. **旧数据需重新 commit session** 才能用新 embedding 索引
3. 测试：`viking_search("测试关键词")` 确认返回结果

## VLM 配置（Session L0/L1 压缩）

OpenViking 对 session 有 L0/L1/L2 层级压缩：
- **L0** `.abstract.md` → 一句话摘要（由 VLM 生成）
- **L1** `.overview.md` → 结构化概览（由 VLM 生成）
- **L2** `messages.jsonl` → 完整原文

**L0/L1 的生成依赖 VLM 配置**。VLM 挂了 → 压缩失败 → 搜索只返回目录元数据。

### 排查流程
```bash
# 测试 VLM 是否能调通
curl -X POST https://openrouter.ai/api/v1/chat/completions \
  -H "Authorization: Bearer $OPENROUTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"你的模型","messages":[{"role":"user","content":"say hi"}],"max_tokens":10}'
```

### 已知问题：免费模型频繁下架
`gemini-2.0-flash-001:free` 曾可用，2026-04-18 实测返回 404。

### 验证可用的免费 VLM（2026-04-18）：
- `nvidia/nemotron-3-super-120b-a12b:free` ✅
- `nvidia/nemotron-3-nano-30b-a3b:free` ✅（更小更快）
- 列出当前免费模型：`GET /v1/models` → 筛选 `:free` 后缀
- ⚠️ 免费模型频繁下架，如果 VLM 调用 404 → 换模型

### 配置示例
```json
"vlm": {
  "provider": "openai",
  "model": "nvidia/nemotron-3-super-120b-a12b:free",
  "api_base": "https://openrouter.ai/api/v1",
  "api_key": "${OPENROUTER_API_KEY}"
}
```

改完 `ov.conf` 后重启 OpenViking server。

**踩坑：ov.conf 不支持环境变量插值**。`${OPENROUTER_API_KEY}` 写进去不会被解析，必须写真实 key。2026-04-18 实测 `vlm.api_key: "${OPEN...KEY}"` 导致 VLM 无法调用，改成真实 key 后恢复正常。

### L0/L1 压缩现状（2026-04-18 实测）

即使 VLM 正常工作，session 的 L0/L1 压缩效果有限：
- `.abstract.md` → commit 后仍为空
- `.overview.md` → 只生成目录结构描述，不含对话内容摘要

**可能原因：** OpenViking 0.3.8 版本的 session 压缩 pipeline 尚未完善，VLM 调用可能只触发在特定场景（如 resource 内容摘要）而非 session 对话摘要。
**结论：** 不要依赖 session L0/L1 做语义搜索，session 搜索仍用 Hermes 内置 `session_search`。

## 搜索范围限制

`viking_search` **只搜 resources 和 user memory，不搜 session 对话历史**。

| 数据类型 | 能搜到 | 说明 |
|---------|--------|------|
| resources | ✅ | 上传的文档、URL 索引 |
| user memory | ✅ | `viking_remember` 存的偏好/实体/事件 |
| session 对话 | ❌ | L0/L1 有设计但未接入搜索索引 |

**精确 session 搜索仍依赖 Hermes 自带的 `session_search`（SQLite FTS5）。**

## 换 Ollama Embedding

```json
"embedding": {
  "dense": {
    "provider": "ollama",
    "model": "qwen3-embedding:latest",
    "dimension": 1024
  }
}
```

---

## Resources 共享约定

同 account 下 `resources` 天然共享，各机器用 resources 实现跨机协作。

### 目录结构

```
viking://resources/
├── wooking-进度/      # wooking 的任务计划和进度
├── kangle-进度/       # kangle 的任务计划和进度
├── 共享文档/           # 两台都能读写的共享区
└── ...
```

### 写入规则

| 机器 | 写入路径 | 内容 |
|------|---------|------|
| wooking | `viking://resources/wooking-进度/` | 本机任务计划、进度日志 |
| kangle | `viking://resources/kangle-进度/` | 本机任务计划、进度日志 |

### 何时写入

- **任务开始**：写计划到 `{机器}-进度/plan-{日期}-{任务名}.md`
- **进度更新**：追加进度到对应文件
- **任务完成**：写结果摘要
- **重要产出**：存到 `resources/` 共享区供对方查阅

### 写入方法（两步）

```bash
# 1. 创建临时文件
cat > /tmp/plan.md << 'EOF'
# 任务计划
- 目标: xxx
- 步骤: 1. xxx  2. xxx
EOF

# 2. 上传
TEMP_ID=$(curl -s -X POST \
  -H "Authorization: Bearer <user_key>" \
  -F "file=@/tmp/plan.md" \
  http://server:1933/api/v1/resources/temp_upload | jq -r '.result.temp_file_id')

# 3. 注册
curl -s -X POST \
  -H "Authorization: Bearer <user_key>" \
  -H "Content-Type: application/json" \
  -d "{\"temp_file_id\":\"$TEMP_ID\"}" \
  http://server:1933/api/v1/resources
```

### 跨读

用对方的 user key 或 ROOT key 即可读取。resources 在同 account 下自动共享。

```bash
# kangle 读 wooking 的进度（用 kangle 的 user key）
curl -s -H "Authorization: Bearer <kangle_key>" \
  http://server:1933/api/v1/fs/ls?uri=viking://resources/wooking-进度/
```

### 创建命名目录

用 `fs/mkdir` API 创建指定名称的目录（不依赖 temp_upload 命名）：

```bash
curl -s -X POST -H "Authorization: Bearer <user_key>" \
  -H "Content-Type: application/json" \
  -d '{"uri":"viking://resources/我的目录"}' \
  http://server:1933/api/v1/fs/mkdir
```

**注意**：`resources` 注册 API 的 `path` 参数不影响最终 URI，服务端总是用 `temp_file_id` 命名。需要有意义的路径名必须先用 `fs/mkdir` 创建目录。

### L0/L1 资源摘要

VLM 正常工作时，上传的 resources 会自动生成：
- **L0 (abstract)**：一句话摘要，存在目录的 `.abstract.md`
- **L1 (overview)**：结构化概览+导航，存在目录的 `.overview.md`

验证：`viking_read(uri, level="abstract")` 或 `level="overview"`。VLM 挂了则只返回目录结构描述，不含内容摘要。

2026-04-18 实测：`nvidia/nemotron-3-nano-30b-a3b:free`（通过 OpenRouter）可以正常生成 L0/L1，4575 tokens 完成一个文件的两级摘要。

### 触发 VLM 的时机

| 操作 | 是否触发 VLM | 备注 |
|------|-------------|------|
| 上传新 resource | ✅ | 自动生成 L0/L1 |
| `content/reindex` | ❌ | 只重做 embedding，不触发 VLM |
| `session/extract` | ✅ | 提取结构化记忆 |
| `session/commit` | ⚠️ | 生成基础计数，不生成语义摘要 |

**旧资源无 L0/L1 → 必须重新上传**，reindex 无法补救。

### 验证 VLM 活动

```bash
# 查看 VLM 调用统计
curl -s -H "Authorization: Bearer <key>" \
  http://server:1933/api/v1/observer/models
```

VLM 调用次数和 token 用量在 `VLM Models` 表中。上传资源后调用次数应增加。

### Session 记忆提取

手动触发 session 记忆提取（异步）：

```bash
curl -s -X POST -H "Authorization: Bearer <user_key>" \
  -H "Content-Type: application/json" \
  "http://server:1933/api/v1/sessions/<session_id>/extract"
```

返回提取的记忆 URI 列表。`viking_remember` 存储的记忆也需要 session commit 后才可搜。

## 跨机连接排查

kangle 连 wooking 的 OpenViking：Tailscale IP `100.67.91.123`，端口 1933。

**常见问题：**
- Tailscale 走 DERP 中继时延迟 300-600ms，不影响功能
- SSH 连 kangle 超时 → kangle 可能没开 sshd，需在 kangle 本地装 openssh-server
- Tailscale SSH 需浏览器认证，无法远端自动化
- kangle `.env` 需 4 个值：ENDPOINT / API_KEY / USER / AGENT，缺一不可
- 重建 user key 会立即使旧 key 失效

### 重新生成 User Key

没有专门的 regenerate API。需要先删后建：

```bash
ROOT_KEY="your_root_key"

# 删旧用户
curl -X DELETE http://server:1933/api/v1/admin/accounts/hermes/users/kangle \
  -H "X-API-Key: $ROOT_KEY"

# 重建（返回新 user_key）
curl -X POST http://server:1933/api/v1/admin/accounts/hermes/users \
  -H "X-API-Key: $ROOT_KEY" \
  -H "Content-Type: application/json" \
  -d '{"user_id": "kangle", "role": "user"}'
```

⚠️ 旧 key 立即失效，记得更新对应机器的 `.env`。

## ov CLI 客户端工具

`pip install openviking` 安装后自带 Rust 二进制 `ov`（不是 Python CLI），可从任意机器连接远程 OpenViking 服务器。

### 二进制位置

```
{venv}/lib/python3.11/site-packages/openviking/bin/ov
```

也注册了 `openviking`、`ov` 两个 console_scripts 入口（Python 包装 → execv 到 Rust 二进制）。

### 配置方式

**方式 1：配置文件** `~/.openviking/ovcli.conf`（JSON）：

```json
{
  "url": "http://100.67.91.123:1933",
  "api_key": "你的user_key",
  "account": "hermes",
  "user": "kangle",
  "agent_id": "hermes-kangle",
  "timeout": 60.0,
  "output": "table"
}
```

**方式 2：环境变量**：

```bash
export OPENVIKING_URL=http://100.67.91.123:1933
export OPENVIKING_CLI_CONFIG_FILE=/path/to/custom.conf  # 可选，指定配置文件路径
```

### HTTP Headers

Rust CLI 自动发送的 headers：
- `X-API-Key` — API key（从 api_key 字段）
- `X-OpenViking-Account` — account 标识
- `X-OpenViking-User` — user 标识
- `X-OpenViking-Agent` — agent 标识

### 常用命令

```bash
ov health                              # 检查连接
ov ls viking://resources/              # 列目录
ov read <uri>                          # 读 L2 完整内容
ov overview <uri>                      # 读 L1 概览
ov abstract <uri>                      # 读 L0 摘要
ov find -q "关键词"                     # 语义搜索
ov add-resource <path>                 # 上传资源
ov add-memory "内容"                   # 添加记忆
ov session new                         # 创建会话
ov session commit <session_id>         # 提交会话
ov config show                         # 查看当前配置
ov admin list-accounts                 # 列出 accounts（需 root key）
ov admin list-users <account>          # 列出 users
ov tui                                 # 交互式 TUI 文件浏览器
```

### 调试技巧

**发现 CLI 支持的环境变量**（通用方法）：

```bash
strings {venv}/openviking/bin/ov | grep -i "OPENVIKING\|api_key\|config"
```

实测发现的 env vars：
- `OPENVIKING_URL` — 服务器地址
- `OPENVIKING_CLI_CONFIG_FILE` — 配置文件路径

### 注意

- `ov config show` 返回的是**默认值**，不显示实际生效值（Rust 二进制的 config 模块在运行时合并）
- 未配置 `ovcli.conf` 时默认连 `http://localhost:1933`，无 API key
- CLI 是纯 Rust 二进制，Windows/macOS/Linux 都有对应的 wheel

---

## 跨机留言板

坚果云 hermes-sync 根目录建 `留言板.md`，两台共用。长期迁移到 `viking://resources/留言板/` 目录。

### 注意：ov.conf 不支持环境变量插值

`"api_key": "${OPENROUTER_API_KEY}"` 不会解析，必须写真实 key。
