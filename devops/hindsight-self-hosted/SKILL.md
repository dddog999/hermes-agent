---
name: hindsight-self-hosted
description: Hindsight 自建服务器完整指南 — Docker 3种部署方式、Python 嵌入式、Hermes 接入、Client SDK 用法
triggers:
  - "hindsight 自建"
  - "hindsight 安装"
  - "hindsight docker"
  - "hindsight 本地部署"
  - "hermes memory hindsight"
---

# Hindsight 自建服务器

> 项目地址：https://github.com/vectorize-io/hindsight ⭐ 9.3K
> 文档：https://hindsight.vectorize.io

## 核心定位

**Hindsight** 是知识图谱 + 实体解析 + 多策略检索的记忆系统，亮点是独家 `hindsight_reflect`（跨记忆综合推理）。

| 工具 | 功能 |
|------|------|
| `hindsight_retain` | 存入 + 实体提取 |
| `hindsight_recall` | 多策略搜索（语义/关键词/图谱/时间） |
| `hindsight_reflect` | 跨记忆综合分析（其他 provider 没有的能力） |

---

## 部署方式

### 方式1：Docker 一键部署（推荐 ⭐）

自带 embedded PostgreSQL，无需额外数据库：

```bash
export OPENAI_API_KEY=你的key

docker run --rm -it --pull always -p 8888:8888 -p 9999:9999 \
  -e HINDSIGHT_API_LLM_API_KEY=$OPENAI_API_KEY \
  -v $HOME/.hindsight-docker:/home/hindsight/.pg0 \
  ghcr.io/vectorize-io/hindsight:latest
```

启动后：
- **API**: http://localhost:8888
- **UI**: http://localhost:9999

LLM Provider 可选 `HINDSIGHT_API_LLM_PROVIDER`：`openai`（默认）、`anthropic`、`gemini`、`groq`、`ollama`、`lmstudio`。**MiniMax 用 `openai` + `HINDSIGHT_API_LLM_BASE_URL=https://api.minimax.chat/v1`**。

### 方式2：Docker + 外部 PostgreSQL

```bash
export OPENAI_API_KEY=***
export HINDSIGHT_DB_PASSWORD=***
cd docker/docker-compose
docker compose up
```

适合生产环境、多用户。

**注意**：`hindsight_api.create_app()` 需要传入 `memory=MemoryEngine(...)` 参数，不能空手调用。

### 方式3：Python 嵌入式（⚠️ 有已知问题，见 Pitfalls）
### 方式3：Python 嵌入式（⚠️ 有已知问题，见 Pitfalls）

```bash
pip install hindsight-all -U
```

```python
import os
from hindsight import HindsightServer, HindsightClient

with HindsightServer(
    db_url="pg0",                    # embedded PG，不要用 pg_data_dir（这是旧参数）
    llm_provider="openai",            # 内置: groq/openai/ollama/gemini/anthropic/lmstudio
    llm_api_key=os.environ["OPENAI_API_KEY"],
    llm_base_url=None,                # OpenAI 则留 None；用 MiniMax 则填 "https://api.minimax.chat/v1"
    llm_model="gpt-4o-mini",
    port=8888,
) as server:
    client = HindsightClient(base_url=server.url)
    client.retain(bank_id="my-bank", content="Alice works at Google")
    results = client.recall(bank_id="my-bank", query="Where does Alice work?")
```

**MiniMax 方案**（国内无 SSL 问题）：
```python
HindsightServer(
    db_url="pg0",
    llm_provider="openai",
    llm_api_key="你的MiniMax API Key",
    llm_base_url="https://api.minimax.chat/v1",
    llm_model="MiniMax-M2.7",  # 注意：MiniMax-Text-01 已改名为 MiniMax-M2.7
    port=8888,
)
```

**混合 Provider 生产配置（推荐）**

三个组件可分别使用不同 provider，适合有多个 API key 的场景：

```bash
# LLM：MiniMax（推理能力强，便宜）
export HINDSIGHT_API_LLM_PROVIDER=openai
export HINDSIGHT_API_LLM_API_KEY="sk-cp-..."
export HINDSIGHT_API_LLM_BASE_URL='https://api.minimax.chat/v1'
export HINDSIGHT_API_LLM_MODEL='MiniMax-M2.7'

# Embedding：AI Gitee Qwen3-Embedding-8B（1024维，免费）
export HINDSIGHT_API_EMBEDDINGS_PROVIDER=openai
export HINDSIGHT_API_EMBEDDINGS_OPENAI_API_KEY="AI Gitee Token"
export HINDSIGHT_API_EMBEDDINGS_OPENAI_BASE_URL='https://ai.gitee.com/v1'
export HINDSIGHT_API_EMBEDDINGS_OPENAI_MODEL='Qwen3-Embedding-8B'

# Reranker：AI Gitee bge-reranker-v2-m3（LiteLLM 模式）
export HINDSIGHT_API_RERANKER_PROVIDER=litellm
export HINDSIGHT_API_RERANKER_LITELLM_API_BASE='https://ai.gitee.com/v1'
export HINDSIGHT_API_RERANKER_LITELLM_API_KEY="AI Gitee Token"
export HINDSIGHT_API_RERANKER_LITELLM_MODEL='bge-reranker-v2-m3'

hindsight-api
```

**Windows 启动正确方式**（`hindsight-api.exe` CLI 在大陆网络会超时挂起，必须用 Python 模块）：

```bash
# Python 3.12 显式调用（不能用 execute_code 的 Python 3.11，会找不到 hindsight_api 模块）
PY312="C:\Users\dddog\AppData\Local\Programs\Python\Python312\python.exe"
"%PY312%" -c "from hindsight_api.main import main; main()"
```

设置同样的环境变量后启动。等待约 15-20 秒让嵌入 PG 初始化 + 迁移完成。

**验证启动成功**：`curl http://127.0.0.1:8888/health` 返回 `{"status":"healthy","database":"connected"}`

**AI Gitee token 注意事项**：必须先在 https://ai.gitee.com/{username}/dashboard/resource 绑定资源包，否则所有模型调用返回 `{"error":{"code":"400","message":"您正在使用的访问令牌尚未绑定到任何资源包"}}`。

**MiniMax API key 真实值查找**：存储中所有 key 都是 `sk-cp-...j3cM` 格式（masked 占位符）。完整 key 存在 KeePass 数据库（`Nutstore/1/keepass/Database.kdbx`，Windows DPAPI 加密，需用户提供主密码读取）或坚果云 `.env`（需解密）。在 auth.json 和 config.yaml 中也都是 masked，无法直接使用。**必须获取完整 key 才能正常启动**。

**注意**：`hindsight_api.create_app()` 需要传入 `memory=MemoryEngine(...)` 参数，不能空手调用。

---

## Hermes 接入 Hindsight

```bash
hermes memory setup
# → 选 hindsight，向导自动安装依赖
# Cloud 模式：装 hindsight-client
# Local 模式：装 hindsight-all
```

配置文件：`$HERMES_HOME/hindsight/config.json`

本地模式需要 LLM API key（OpenAI/Groq/OpenRouter 等）。

---

## 与 ClawMem 的核心区别

| 维度 | Hindsight | ClawMem |
|------|-----------|---------|
| **核心能力** | 知识图谱 + 跨记忆综合推理 | Markdown 文件 + frontmatter 溯源 |
| **存储格式** | PostgreSQL 向量 + 图谱 | Markdown 文件（可坚果云同步） |
| **嵌入方案** | 自带（需 LLM API key） | Jina Embeddings v4 |
| **部署复杂度** | Docker 或 Python | Node.js + MCP |
| **与 Hermes 集成** | `hermes memory setup` 官方支持 | MCP hooks 方式 |

---

## Client SDK 用法

### Python

```bash
pip install hindsight-client -U
```

```python
from hindsight_client import Hindsight

client = Hindsight(base_url="http://localhost:8888")

# 创建记忆银行
bank = client.create_bank(bank_id="my-bank", name="My Bank")
print(bank.bank_id, bank.name)  # 注意字段是 bank_id，不是 id

# 存入记忆（异步 API）
result = client.aretain(bank_id="my-bank", content="Alice works at Google")
print(result.success)  # True 表示成功存入

# 搜索记忆
results = client.recall(bank_id="my-bank", query="Where does Alice work?")
for r in results.results:
    print(r.text)  # 不是 r.context，是 r.text

# 列出所有记忆
memories = client.list_memories(bank_id="my-bank")
print(memories.total)       # 总数
for m in memories.items:     # 注意是 items，不是 memories
    print(m.text, m.entities)

# 跨记忆综合推理
summary = client.reflect(bank_id="my-bank", query="Tell me about Alice")
print(summary.content)

client.close()
```

**SDK 字段速查**：`BankProfileResponse` 用 `bank_id`/`name`，`ListMemoryUnitsResponse` 用 `items`（不是 `memories`），`RecallResult` 的项用 `text`（不是 `context`）。

### Node.js

```bash
npm install @vectorize-io/hindsight-client
```

```javascript
const { HindsightClient } = require('@vectorize-io/hindsight-client');

const main = async () => {
  const client = new HindsightClient({ baseUrl: 'http://localhost:8888' });
  await client.retain('my-bank', 'Alice loves hiking in Yosemite');
  const results = await client.recall('my-bank', 'What does Alice like?');
  console.log(results);
}
main();
```

---

## Pitfalls

- **切换 embedding 模型导致维度冲突**：embedding dimension 从 384 改为 1024（或任何不匹配）时启动报错 `Cannot change embedding dimension from 384 to 1024`。解决步骤：
  1. `taskkill //F //IM postgres.exe` 停掉所有 PG 进程
  2. `cp -r ~/.pg0/instances/hindsight/data ~/.pg0_backup_$(date +%Y%m%d)/` 备份数据
  3. `rm -rf ~/.pg0/instances/hindsight/data/*` 清空数据目录
  4. 重启 hindsight-api（会用新维度重新初始化）
  5. 注意：所有旧记忆会丢失，需要重新 retain
- **启动脚本的 MINIMAX_API_KEY 占位符**：`start_hindsight.sh` 里的 `MINIMAX_API_KEY='sk-cp-...j3cM'` 是历史占位符，每次重启前必须填入真实 key。查找真实 key：`grep -r "sk-cp-" ~/.hermes/ --include="*.json" | grep MINIMAX`。**注意（2026-05-19 更新）**：脚本已改为自动从 KeePass 读取 key（`keepassxc-cli show -a Password ... "/LLM-APIs/MiniMax-M2.7"`）。重启前只需 `export KEEPASS_PASSWORD='...'`，脚本自动拉取 key，不经过任何明文文件
- **`taskkill //F //IM python.exe` 会杀掉自己**：在 Hermes TUI/CLI 里执行会把自己（Hermes Agent）也杀掉。停 hindsight 用 `taskkill //F //IM postgres.exe`（Hindsight 内嵌 PG）或 `taskkill //F //IM hindsight-api.exe`。
- **`hindsight-api` CLI 是非交互式的**：直接在 shell 中设置环境变量后运行即可，不需要子命令。用后台模式 `hindsight-api &` 或 Hermes terminal 的 `background=true`。不要尝试交互输入。
- **`hindsight-api.exe` 在 Windows 上会超时**：`hindsight-api.exe` CLI 启动时会联网下载/验证组件，在大陆网络环境下会超时挂起。**必须用 Python 模块方式**（见上方"混合配置"节的 Windows 启动命令）。
- **嵌入式 PostgreSQL 数据损坏/丢失**：当 `~/.pg0/instances/hindsight/data/` 为空或文件丢失时，hindsight 启动失败，报 `connection to server at 127.0.0.1, port 5432 failed: server closed the connection unexpectedly`。**无需手动重建 PG**：只要备份并清空 data 目录（留下空目录），重启 hindsight 会自动重新初始化 PG + 运行迁移。步骤：
  1. `taskkill //F //IM postgres.exe`（停所有 PG 进程）
  2. `cp -r ~/.pg0/instances/hindsight/data ~/.pg0_backup_$(date +%Y%m%d)/`（备份）
  3. `rm -rf ~/.pg0/instances/hindsight/data/*`（清空数据，保留目录）
  4. 重启 hindsight（会自动 init PG + migrate）
  5. 验证：`curl http://127.0.0.1:8888/health`
  - 注意：所有旧记忆会丢失（因为数据目录被清空）
- **Embedding dimension 自动迁移**：Hindsight v0.6+ 支持在 PG 数据目录为空时自动 ALTER column dimension（384→1024 等），无需手动清表。但如果数据库有数据且维度不匹配，仍会报错退出。
- **`sentence-transformers` 导入报错**：`RuntimeError: operator torchvision::nms does not exist`。原因：已安装的 `torchvision` 是 CUDA 版（`0.20.1+cu121`）但 `torch` 是 CPU 版（`2.12.0`），版本不匹配。修复：`pip install torchvision --index-url https://download.pytorch.org/whl/cpu`（重装 CPU 版 torchvision）
- **MiniMax Embedding API 余额不足**：MiniMax embedding（`embo`）模型默认余额为0，API 返回 `insufficient balance`。Hindsight 本地 embedding 模式用 `BAAI/bge-small-en-v1.5`（从 HuggingFace 下载，无需 API key），无需额外配置。
- **HindsightServer `pg_data_dir` 参数已废弃**：实际用 `db_url="pg0"`（embedded 模式）；外部 PG 用 `db_url="postgresql://user:pass@host:5432/dbname"`
- **MiniMax 不是内置 provider 名**：要用 `llm_provider="openai"` + `llm_base_url="https://api.minimax.chat/v1"` 组合
- **`create_app()` 需要 `memory` 参数**：直接调用 `create_app()` 会报 `TypeError: create_app() missing 1 required positional argument: 'memory'`
- **LLM API key 必须**：即使是本地模式也需要 LLM API key 用于实体提取和推理
- **切换 embedding 模型时维度必须匹配**：如果数据库中已有数据（`memory_units` 表有行），新模型的向量维度必须一致，否则启动时报错 `Cannot change embedding dimension from 384 to 1024` 并强制退出（不会自动 migrate）。解法：停服务 → 清理 `DELETE FROM public.memory_units;` → 重启。
- **AI Gitee Token 必须绑定资源包**：所有 AI Gitee 模型（包括 embedding/reranker）调用时都会返回 `{"error":{"code":"400","message":"您正在使用的"访问令牌"尚未绑定到任何资源包，或账号未购买可用的资源包"}}`。必须先去 https://ai.gitee.com/{username}/dashboard/resource 领取/购买资源包并绑定 token，才能正常调用。**包括 chat/deepseek 模型也同样需要绑定**，不要误以为 embedding 模型可以绕过。
- **端口冲突**：8888 和 9999 被占用时用 `-p` 指定其他端口
- **WAL 模式数据库**：`.hindsight-docker` 目录里的 PostgreSQL 数据不要放坚果云同步（SQLite/WAL 不能放文件同步服务）
- **WSL 环境**：`python` 命令指向 Windows Python312，`python3` 指向 WSL 系统 Python，不一样。Windows 用户目录在 WSL 里是 `/c/Users/...`（小写 c）

## 参考文件
- `references/minimax-api.md` — MiniMax API 模型名和调用方式实测记录
- `references/ai-gitee-api.md` — AI Gitee API 模型列表、token 绑定问题、embedding/reranker 配置（含三组件混合配置）
- `references/hindsight-debug.md` — Hindsight 调试笔记（Python 版本冲突、PG 数据损坏修复、401 故障排查）
- `scripts/start_hindsight.sh` — Windows/MSYS 环境 Hindsight API 启动脚本（Python 3.12 模块方式启动）