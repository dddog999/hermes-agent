# Feishu Message Debug
> Absorbed from `feishu-message-debug` — Feishu API debugging reference.

---


# Feishu Message Debug & History

Use when: user wants to see Feishu conversation content, debug message delivery, or view bot replies.

## Two Methods to View Messages

### Method 1: Real-time Logs (Metadata Only)

```bash
journalctl --user -u hermes-gateway -f | grep -E "(Feishu|Lark|im\.message)"
```

**What you see:**
- Message ID, chat ID, sender ID
- Message length (chars)
- Timestamp
- Send/receive status

**What you DON'T see:**
- Actual message content

### Method 2: Feishu API (Full Content)

Use Python to call Feishu Open API and retrieve actual message text.

#### Step 1: Get tenant_access_token

```python
import requests

app_id = "cli_xxx"  # from FEISHU_APP_ID in ~/.hermes/.env
app_secret = "xxx"  # from FEISHU_APP_SECRET in ~/.hermes/.env

r = requests.post(
    "https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal",
    json={"app_id": app_id, "app_secret": app_secret}
)
token = r.json()["tenant_access_token"]
```

#### Step 2: Get Message History

```python
chat_id = "oc_xxx"  # from logs: chat_id=oc_xxx

r = requests.get(
    "https://open.feishu.cn/open-apis/im/v1/messages",
    headers={"Authorization": f"Bearer {token}"},
    params={
        "container_id_type": "chat",
        "container_id": chat_id,
        "page_size": 10,
        "sort_type": "ByCreateTimeDesc"
    }
)

for item in r.json()["data"]["items"]:
    sender = item["sender"]["id"]
    content = json.loads(item["body"]["content"]).get("text", "")
    sender_type = "用户" if sender.startswith("ou_") else "机器人"
    print(f"{sender_type}: {content}")
```

## Workflow

1. **Find chat_id**: Check logs for `chat_id=oc_xxx` when user sends a message
2. **Get credentials**: Read `FEISHU_APP_ID` and `FEISHU_APP_SECRET` from `~/.hermes/.env`
3. **Get token**: Call tenant_access_token API
4. **Retrieve messages**: Call messages API with chat_id
5. **Parse content**: `msg_type=text` → `json.loads(content)["text"]`

## Pitfalls

- **App Secret must be FULL value** — .env display may truncate it (check actual file)
- **Token expires ~2 hours** — re-fetch if getting 99991663 error
- **Log file location**: `~/.hermes/logs/agent.log` has more detail than journalctl
- **Session files**: `~/.hermes/sessions/*.json` contain conversation context but not raw Feishu messages
- **Sender ID format**: `ou_xxx` = user, `cli_xxx` = bot

## Common Issues

| Symptom | Cause | Fix |
|---------|-------|-----|
| Can see user messages in logs but not bot replies | Logs only show metadata | Use Feishu API |
| "app secret invalid" error | Wrong/truncated secret | Read full secret from .env file |
| No messages returned | Wrong chat_id | Check logs for correct `chat_id=oc_xxx` |
| Bot replies are slow | Model response time | Check `time=XXs` in logs |

## Quick Check Script

Save as `~/feishu_messages.py`:

```python
#!/usr/bin/env python3
import requests, json, sys
from datetime import datetime

def get_messages(chat_id, limit=10):
    # Read credentials
    app_id = app_secret = ""
    with open("/home/kangle/.hermes/.env") as f:
        for line in f:
            if line.startswith("FEISHU_APP_ID="):
                app_id = line.split("=", 1)[1].strip()
            elif line.startswith("FEISHU_APP_SECRET="):
                app_secret = line.split("=", 1)[1].strip()
    
    # Get token
    r = requests.post(
        "https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal",
        json={"app_id": app_id, "app_secret": app_secret}
    )
    token = r.json()["tenant_access_token"]
    
    # Get messages
    r = requests.get(
        "https://open.feishu.cn/open-apis/im/v1/messages",
        headers={"Authorization": f"Bearer {token}"},
        params={"container_id_type": "chat", "container_id": chat_id, "page_size": limit}
    )
    
    for item in r.json()["data"]["items"]:
        ts = int(item["create_time"]) / 1000
        time_str = datetime.fromtimestamp(ts).strftime("%H:%M:%S")
        sender = "👤" if item["sender"]["id"].startswith("ou_") else "🤖"
        content = json.loads(item["body"]["content"]).get("text", "")
        print(f"[{time_str}] {sender} {content}")

if __name__ == "__main__":
    chat_id = sys.argv[1] if len(sys.argv) > 1 else "oc_63be2930e266dd8407ca73cfdad85b89"
    get_messages(chat_id)
```
