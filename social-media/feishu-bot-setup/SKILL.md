---
name: feishu-bot-setup
description: Set up Feishu (飞书/Lark) bot integration with Hermes Gateway — including app creation, permissions, event subscriptions, and troubleshooting common issues.
---

# Feishu / Lark Bot Setup

Use when: user wants to connect Hermes to Feishu/Lark for messaging.

## Prerequisites
- A Feishu app at https://open.feishu.cn/ with App ID and App Secret
- App must have **机器人 (Bot)** capability enabled

## Steps

### 1. Configure Hermes .env

Add to `~/.hermes/.env`:

```
FEISHU_APP_ID=cli_xxx
FEISHU_APP_SECRET=your_full_secret_here
FEISHU_DOMAIN=feishu       # feishu for China, lark for international
FEISHU_CONNECTION_MODE=websocket
FEISHU_ALLOWED_USERS=ou_xxx,ou_yyy
```

### 2. Feishu Developer Console Setup

At https://open.feishu.cn/ → select your app:

**Permissions (权限管理):**
- `im:message:readonly` — 读取用户发给机器人的单聊消息
- `im:message` — 获取用户发给机器人的消息
- `im:message:send_as_bot` — 以应用的身份发消息

**Event Subscriptions (事件订阅):**
- Subscribe to `im.message.receive_v1` (接收消息)
- Select **长连接 (WebSocket)** as the subscription method

**Publishing:**
- Create a version in 版本管理与发布
- Add yourself as 体验人员 (test user) to skip approval, OR submit for review

### 3. Start Gateway

```bash
hermes gateway install    # install systemd service (first time)
hermes gateway start
```

Check logs:
```bash
journalctl --user -u hermes-gateway -f
```

### Critical Minimum (just for basic messaging)

```json
{
  "tenant": ["im:message:send_as_bot", "im:message:readonly", "im:message:read", "im:chat:readonly", "im:chat:read"],
  "user": ["docx:document:readonly"]
}
```

### File upload fails with 234001 Invalid request param
**Symptom:** `POST /im/v1/files` returns `{"code":234001,"msg":"Invalid request param."}` regardless of parameters tried (file_name, parent_type, file as multipart).
**Root cause:** Missing `im:file` or `im:message:upload_attachment` permission. Basic messaging permissions are insufficient for file upload.
**Fix:** Add `im:file` (上传消息文件) tenant permission in Feishu console → 权限管理, then republish. Also ensure `parent_type=im_message_file` is set.

### Bot A cannot respond when @mentioned by Bot B in group chat
**Symptom:** Human @Bot B → Bot B replies fine. Bot A @Bot B → Bot B does NOT reply, no error in logs.
**Root cause:** Missing `im:message:read` permission. Without it the bot cannot call `im:message:read` API to extract the `@mention` target ID from the message body. `_should_accept_group_message()` returns False and the message is silently dropped.
**Fix:** Add `im:message:read` (读取消息) tenant permission in Feishu console → 权限管理, then republish.

## Event Subscriptions (Feishu Dev Console → 事件订阅)

Not in OAuth scopes — configure in the console separately. Use **长连接 (WebSocket)** mode:

| Event | Purpose |
|-------|---------|
| `im.message.receive_v1` | Receive messages (required) |
| `im.message.message_read_v1` | Message read receipts |
| `im.message.reaction.created_v1` | Reactions created |
| `im.message.reaction.deleted_v1` | Reactions deleted |
| `im.chat.member.bot_added_v1` | Bot added to group |
| `im.chat.member.bot_deleted_v1` | Bot removed from group |
| `im.chat.access_event.bot_p2p_chat_entered_v1` | User enters P2P chat with bot |
| `im.message.recalled_v1` | Message recalled |
| `drive.notice.comment_add_v1` | Document comment added |

### No input box in chat window
**Cause:** Missing event subscription for `im.message.receive_v1`
**Fix:** Go to Feishu dev console → 事件订阅 → subscribe to 接收消息 (im.message.receive_v1)

### "Unauthorized user" in logs
**Cause:** User's open_id not in allowlist
**Fix:** Add user's `ou_xxx` to `FEISHU_ALLOWED_USERS` in .env, then restart gateway
**Find open_id:** Check gateway logs after user sends a message: `grep "Unauthorized" ~/.hermes/logs/gateway.log`

**⚠️ Common first-time setup pitfall:** `FEISHU_ALLOWED_USERS` is easy to forget. Without it, every Feishu user gets "Unauthorized" and the bot silently ignores them. Add it on first setup:
```
FEISHU_ALLOWED_USERS=ou_56cf8f3dff1d6515d04f56df2b690691
```
To find the open_id: look in `gateway.log` for the first message the user sends — it appears as `sender=user:ou_xxx` in the log entry.

### "Unable to hydrate bot identity"
**Cause:** Missing `admin:app.info:readonly` permission
**Fix:** Grant the permission in 飞书开发者后台 (low priority, doesn't affect core functionality)

### Gateway won't start after install
```bash
hermes gateway install   # reinstall service
hermes gateway start
```

## Urgent Messages (加急消息)

飞书支持对已发送消息追加加急通知。**用 PATCH 不是 POST！**

### App 内加急 (urgent_app) ✅ 推荐日常使用
弹窗 + 响铃 + 消息置顶。

```python
# 1. 先发消息
msg_r = requests.post(
    "https://open.feishu.cn/open-apis/im/v1/messages",
    params={"receive_id_type": "open_id"},
    headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json; charset=utf-8"},
    json={
        "receive_id": "ou_xxx",
        "msg_type": "text",
        "content": json.dumps({"text": "需要您确认: xxx"})
    }
)
message_id = msg_r.json()["data"]["message_id"]

# 2. 加急 (PATCH!)
urgent_r = requests.patch(
    f"https://open.feishu.cn/open-apis/im/v1/messages/{message_id}/urgent_app",
    params={"user_id_type": "open_id"},
    headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
    json={"user_id_list": ["ou_xxx"]}
)
# 成功: {"code":0,"data":{"invalid_user_id_list":[]},"msg":"success"}
```

### 电话/短信加急 (urgent_phone / urgent_sms)
自动拨打电话或发短信。**有每日限制（~5次/天），超限返回 code 230024。**

| 类型 | 效果 | 限制 | 场景 |
|------|------|------|------|
| urgent_app | 弹窗+响铃+置顶 | 宽松 | 权限确认 |
| urgent_phone | 自动语音电话 | ~5次/天 | 最紧急 |
| urgent_sms | 短信 | ~5次/天 | 飞书离线 |

### Pitfalls
- **PATCH 不是 POST** — POST 返回 404
- 先发消息才能加急
- 电话/短信加急有每日上限，错误码 230024

## Sending Messages Directly via Feishu Open API

When the gateway isn't running or lark-cli isn't configured, send messages directly using the app credentials from `~/.hermes/.env`.

### Get tenant_access_token

```python
import requests
r = requests.post("https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal", json={
    "app_id": "cli_xxx",          # from FEISHU_APP_ID
    "app_secret": "your_secret"   # from FEISHU_APP_SECRET
})
token = r.json()["tenant_access_token"]
```

### Send a rich card message (interactive)

```python
import requests, json

r = requests.post(
    "https://open.feishu.cn/open-apis/im/v1/messages",
    params={"receive_id_type": "open_id"},
    headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json; charset=utf-8"},
    json={
        "receive_id": "ou_xxx",  # user's open_id
        "msg_type": "interactive",
        "content": json.dumps({
            "config": {"wide_screen_mode": True},
            "header": {"title": {"tag": "plain_text", "content": "Title"}, "template": "blue"},
            "elements": [{"tag": "markdown", "content": "**Bold** and normal text"}]
        })
    }
)
```

### Send a plain text message

```python
r = requests.post(
    "https://open.feishu.cn/open-apis/im/v1/messages",
    params={"receive_id_type": "open_id"},
    headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json; charset=utf-8"},
    json={
        "receive_id": "ou_xxx",
        "msg_type": "text",
        "content": json.dumps({"text": "Hello!"})
    }
)
```

### Pitfalls
- `receive_id_type` must match the ID format: `open_id` for `ou_xxx`, `user_id` for user ID, `chat_id` for group chat `oc_xxx`
- Token expires after ~2 hours; re-fetch if sending fails with 99991663 error
- `msg_type`: `text` for plain text, `interactive` for rich cards with markdown support

### Send a file message (docx, pdf, etc.)

**必须分两步：先上传获取 file_key，再发送消息。**

```python
import requests, json

# Step 1: 上传文件（注意 file_type=stream！）
with open("file.docx", "rb") as f:
    upload_r = requests.post(
        "https://open.feishu.cn/open-apis/im/v1/files",
        headers={"Authorization": f"Bearer {token}"},
        data={"file_type": "stream", "file_name": "file.docx"},
        files={"file": f}
    )
upload_r.json()  # {'code': 0, 'data': {'file_key': 'xxx'}}
file_key = upload_r.json()["data"]["file_key"]

# Step 2: 发送文件消息
send_r = requests.post(
    "https://open.feishu.cn/open-apis/im/v1/messages",
    params={"receive_id_type": "chat_id"},  # 或 open_id
    headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
    json={
        "receive_id": "oc_xxx",  # chat_id 或 open_id
        "msg_type": "file",
        "content": json.dumps({"file_key": file_key})
    }
)
# send_r.json()['msg'] == 'success'
```

**关键细节（试错得出）：**
- `file_type` 参数必须传 `stream`，否则返回 `234001 Invalid request param`
- 不能跳过 Step 1 直接在消息 content 里带文件二进制
- `receive_id_type` 必须与 `receive_id` 格式匹配

## 加急消息 API (Urgent Messages)

发送消息后，对消息加急。三种类型：

| 类型 | API 路径 | 效果 | 限制 |
|------|----------|------|------|
| App 内加急 | `urgent_app` | 弹窗+响铃+置顶 | 无明显限制 |
| 电话加急 | `urgent_phone` | 自动拨打语音电话 | 每日约5次 |
| 短信加急 | `urgent_sms` | 发送短信提醒 | 每日约5次 |

**关键细节（试错得出）：**
- 必须用 **PATCH**（不是 POST）
- 必须加 `user_id_type=open_id` 参数
- `user_id_list` 用 open_id 格式 (`ou_xxx`)

```python
# 发送消息后获取 message_id，然后：
import requests

urgent_r = requests.patch(
    f"https://open.feishu.cn/open-apis/im/v1/messages/{message_id}/urgent_app",
    params={"user_id_type": "open_id"},
    headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
    json={"user_id_list": [user_open_id]}
)
# 成功: {"code": 0, "data": {"invalid_user_id_list": []}}
# 限流: {"code": 230024, "msg": "Reach the upper limit of urgent message."}
```

**用途：** 权限确认、紧急通知、需要用户立即关注的事件。

## Behavior

- **Private chat:** Bot responds to every message
- **Group chat:** By default, responds only when @mentioned
- Set `/sethome` in a chat to make it the home channel for cron jobs and cross-platform messages

### Group Chat Policy

Control group chat behavior with `FEISHU_GROUP_POLICY` in `.env`:

| Value | Behavior |
|-------|----------|
| `allowlist` (default) | Only respond in explicitly allowed groups |
| `open` | Respond to all @mentions in any group |

For bot to respond to **ALL messages** (not just @mentions) in a group:
1. Set `FEISHU_GROUP_POLICY=open` in `.env`
2. Grant `im:message.group_msg` permission in Feishu console
3. Restart gateway

## 加急消息 API (Urgent Messages)

飞书支持对已发送的消息添加加急提醒，有三种类型：

| 类型 | API 端点 | 效果 | 限制 |
|------|----------|------|------|
| App 内加急 | `urgent_app` | 弹窗 + 响铃 + 消息置顶 | 无明显限制 |
| 电话加急 | `urgent_phone` | 自动拨打语音电话 | 每日约 5 次 |
| 短信加急 | `urgent_sms` | 发送短信到绑定手机 | 每日约 5 次 |

### 调用方式

```python
import requests, json

# 1. 先发送消息，获取 message_id
msg_r = requests.post(
    "https://open.feishu.cn/open-apis/im/v1/messages",
    params={"receive_id_type": "open_id"},
    headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json; charset=utf-8"},
    json={
        "receive_id": "ou_xxx",
        "msg_type": "text",
        "content": json.dumps({"text": "通知内容"})
    }
)
message_id = msg_r.json()["data"]["message_id"]

# 2. 添加加急 (PATCH, 不是 POST)
for urgent_type in ["urgent_app", "urgent_phone", "urgent_sms"]:
    r = requests.patch(
        f"https://open.feishu.cn/open-apis/im/v1/messages/{message_id}/{urgent_type}",
        params={"user_id_type": "open_id"},
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
        json={"user_id_list": ["ou_xxx"]}
    )
    # 错误码 230024 = "Reach the upper limit of urgent message" (每日次数用完)
```

### Pitfalls
- 必须用 **PATCH**，不是 POST（POST 返回 404）
- `urgent_phone` / `urgent_sms` 有每日次数限制（错误码 230024），仅用于最紧急场景
- `urgent_app` 无明显限制，适合权限确认等场景
- 必须先发送消息拿到 `message_id`，再调加急接口

## Switching Feishu Between Machines (WSL ↔ Windows)

When Hermes runs on multiple machines simultaneously with the same Feishu app credentials, both instances receive messages and reply — causing conflicts.

**Migration steps (WSL → Windows):**

1. Stop WSL Gateway:
   ```bash
   wsl -- bash -c "systemctl --user stop hermes-gateway.service"
   wsl -- bash -c "systemctl --user disable hermes-gateway.service"
   ```

2. Configure Windows `.env` with Feishu credentials:
   ```
   FEISHU_APP_ID=cli_xxx
   FEISHU_APP_SECRET=xxx
   FEISHU_DOMAIN=feishu
   FEISHU_CONNECTION_MODE=websocket
   FEISHU_ALLOWED_USERS=ou_xxx
   ```

3. Start Windows Gateway: `hermes gateway install && hermes gateway start`

4. Verify: `tail C:\Users\<user>\AppData\Local\hermes\logs\ateway-stdio.log` → look for `[Lark] [INFO] connected to wss://msg-frontier.feishu.cn`

### ⚠️ Windows Dual .env File Trap (CRITICAL)

On Windows, Hermes reads `.env` from `C:\Users\<user>\AppData\Local\hermes\.env` — NOT from `C:\Users\<user>\.hermes\.env`. The latter is an MSYS/MinGW path alias that resolves to a different location. Always verify the correct path with `hermes config env-path`.

Symptoms when you edit the wrong .env: `FEISHU_ALLOWED_USERS` appears correct in `~/.hermes/.env`, but gateway logs still show "Unauthorized user" after restart. The gateway loaded the OTHER .env file.

**Correct file:**
```
C:\Users\<user>\AppData\Local\hermes\.env
```

**Wrong file (MSYS alias, does NOT work):**
```
C:\Users\<user>\.hermes\.env   ← Hermes does NOT read this on Windows
```

Use `hermes config env-path` to confirm which file Hermes is actually using.

**WSL hermes path** (not in PATH): `/home/kangle/.hermes/hermes-agent/venv/bin/hermes`

**WSL command from Windows:** `wsl -- bash -c "command"` (not tailscale SSH — works when other SSH approaches fail)

`hermes gateway restart` does NOT fully reinitialize — Feishu WebSocket stays connected and config may be cached. After changing `FEISHU_ALLOWED_USERS` or other Feishu settings, you MUST do:

```bash
hermes gateway stop    # kills the process
sleep 1
hermes gateway start   # fresh spawn, fully reloads .env
```

Symptoms of stale config: user sends message → gateway receives it (logged) → but "Unauthorized user" warning appears and no response. The old gateway log may show the new message with the old config, making it confusing to debug. Always check `gateway-stdio.log` for the startup banner timestamp to confirm which gateway instance is running.

## Monitoring Feishu Messages

### View message traffic
`journalctl` only shows connection status, NOT message content. To see actual messages:

```bash
# See incoming messages
grep "Inbound dm message received" ~/.hermes/logs/agent.log

# See recent messages with text content
grep -E "Inbound dm message received|text=" ~/.hermes/logs/agent.log | tail -20

# Real-time monitoring
tail -f ~/.hermes/logs/agent.log | grep --line-buffered -E "Inbound|response ready"
```

### Log entry formats
- **Incoming**: `[Feishu] Inbound dm message received: id=om_xxx type=text chat_id=oc_xxx text='message content'`
- **Outgoing**: `response ready: platform=feishu chat=oc_xxx time=XXs api_calls=N response=N chars`
- **Batching**: `[Feishu] Flushing text batch agent:main:feishu:dm:oc_xxx (N chars)`

### Log files location

**Windows** (native, not WSL):
```
C:\Users\<user>\AppData\Local\hermes\logs\
  ├── agent.log          # message traffic + agent activity
  ├── gateway.log        # gateway errors and connection issues
  ├── gateway-stdio.log  # gateway stdout/stderr (includes Feishu connect/disconnect)
  └── errors.log         # warnings and errors only
```
On Windows, Hermes uses `AppData\Local\hermes\` — NOT `~/.hermes/logs/`. The `~` alias resolves to the MSYS/MinGW home under `C:\Users\<user>\`, but the actual Hermes on Windows writes to the Windows-native AppData path.

**WSL / Linux**:
```
~/.hermes/logs/agent.log
~/.hermes/logs/gateway.log
~/.hermes/logs/errors.log
```
On WSL, `~/.hermes/logs/` is correct.

## Pitfalls
- App Secret must be the FULL value — the .env display may truncate it
- Must subscribe to events using **长连接 (WebSocket)** mode, NOT webhook (unless you have a public endpoint)
- The app must be published or the user must be added as a test user — otherwise the bot exists but can't receive messages
- After changing .env, the gateway must be restarted: `hermes gateway restart`
- **Group chat not responding**: If `FEISHU_GROUP_POLICY` is commented out, it defaults to `allowlist`. But if `FEISHU_ALLOWED_USERS` is also commented out, NO users can send group messages (all rejected). Fix: either set `FEISHU_GROUP_POLICY=open` or uncomment `FEISHU_ALLOWED_USERS` with valid open_ids.
- **api_server bind failure is non-fatal**: If `gateway.log` shows `ERROR ... could not bind on any address out of [('100.125.109.54', 8642)]` — the gateway **keeps running**. Feishu WebSocket (`wss://msg-frontier.feishu.cn`) connects normally and messaging works. The api_server is an optional Honcho memory component; its failure does not block Feishu.
- **journalctl doesn't show messages on Windows**: Use `type C:\Users\<user>\AppData\Local\hermes\logs\gateway-stdio.log` (Windows) or `tail -f` the equivalent path. `journalctl` is Linux-only.
- **journalctl doesn't show messages**: Use `~/.hermes/logs/agent.log` instead to see actual Feishu message content
