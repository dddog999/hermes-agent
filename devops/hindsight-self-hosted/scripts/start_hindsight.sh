#!/bin/bash
# Hindsight API Server 启动脚本（Windows/MSYS 用）
# 
# 用法: bash start_hindsight.sh
#
# 完整混合配置：MiniMax LLM + AI Gitee Embedding + AI Gitee Reranker
#
# MiniMax API key 自动从 KeePass 读取（/LLM-APIs/MiniMax-M2.7）
# KeePass DB: Nutstore/1/keepass/Database.kdbx

GITEE_TOKEN='P0YCD8QAR9UPUWS57IA9BYFAU5RQAL6O2GVSO51W'  # AI Gitee token（需绑定资源包）

# Convert Windows HERMES_HOME to POSIX path for bash
_hs_raw="${HERMES_HOME:-/c/Users/dddog/AppData/Local/hermes}"
if command -v cygpath &>/dev/null; then
    HS_DIR="$(cygpath "$_hs_raw")/hindsight"
else
    # Manual conversion: C:\foo\bar -> /c/foo/bar
    HS_DIR="$(echo "$_hs_raw" | sed 's/\\/\//g' | sed 's/^\([A-Za-z]\):/\/\1/')/hindsight"
fi
if [ -f "$HS_DIR/.env" ]; then
    set -a
    source "$HS_DIR/.env"
    set +a
fi

# MiniMax API key: 从 .env 直接读取（已存入 ~/.hermes/hindsight/.env）
if [ -z "$MINIMAX_API_KEY" ] || [ "$MINIMAX_API_KEY" = "sk-cp-...j3cM" ]; then
    echo "ERROR: MINIMAX_API_KEY not set. Check ~/.hermes/hindsight/.env"
    exit 1
fi
echo "✓ MiniMax API key loaded (${#MINIMAX_API_KEY} chars)"

# Python 3.12 路径（不能用 execute_code 的 Python 3.11，找不到 hindsight_api 模块）
PY312="${USERPROFILE:=/c/Users/dddog}/AppData/Local/Programs/Python/Python312/python.exe"

cd /c/Users/dddog

# LLM（MiniMax）
export HINDSIGHT_API_LLM_PROVIDER=openai
export HINDSIGHT_API_LLM_API_KEY="${MINIMAX_API_KEY}"
export HINDSIGHT_API_LLM_BASE_URL='https://api.minimax.chat/v1'
export HINDSIGHT_API_LLM_MODEL='MiniMax-M2.7'          # 注意：不是 MiniMax-Text-01（已废弃）

# Embedding（AI Gitee，OpenAI-compatible）
export HINDSIGHT_API_EMBEDDINGS_PROVIDER=openai
export HINDSIGHT_API_EMBEDDINGS_OPENAI_API_KEY="${GITEE_TOKEN}"
export HINDSIGHT_API_EMBEDDINGS_OPENAI_BASE_URL='https://ai.gitee.com/v1'
export HINDSIGHT_API_EMBEDDINGS_OPENAI_MODEL='Qwen3-Embedding-8B'

# Reranker（AI Gitee，LiteLLM 模式）
export HINDSIGHT_API_RERANKER_PROVIDER=litellm
export HINDSIGHT_API_RERANKER_LITELLM_API_BASE='https://ai.gitee.com/v1'
export HINDSIGHT_API_RERANKER_LITELLM_API_KEY="${GITEE_TOKEN}"
export HINDSIGHT_API_RERANKER_LITELLM_MODEL='bge-reranker-v2-m3'

export HINDSIGHT_API_PORT=8888
export HINDSIGHT_API_HOST='127.0.0.1'

LOG_DIR="/c/Users/dddog/AppData/Local/hermes/hindsight"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/hs.log"

echo "Starting Hindsight API..."
echo "Log: $LOG_FILE"

# 用 Python 3.12 模块方式启动（不能用 hindsight-api.exe，会超时）
"$PY312" -c "from hindsight_api.main import main; main()" \
    > "$LOG_FILE" 2>&1 &
PID=$!

echo "PID: $PID"
echo "Waiting 20s for embedded PG init + migrations..."
sleep 20

if curl -s --max-time 5 http://127.0.0.1:8888/health | grep -q "healthy"; then
    echo "✓ Hindsight is healthy!"
else
    echo "✗ Health check failed. See log:"
    tail -30 "$LOG_FILE"
fi
