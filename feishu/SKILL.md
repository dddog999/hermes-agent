---
name: feishu
description: 飞书（Feishu/Lark）平台集成完全指南 — 消息调试、审批确认、机器人配置。包含飞书开放平台 API 调用和 Hermes Gateway 代码补丁。
category: productivity
---

# 飞书平台集成指南

## 概述

Hermes 与飞书平台的集成包含两个层面：
1. **API 层**：通过飞书开放平台 API 获取消息历史、调试通信
2. **Gateway 层**：Hermes Gateway 中的飞书适配器代码补丁

---

## Part 1: 消息调试与历史获取

### 触发场景
用户想查看飞书对话内容、调试消息发送、或查看机器人回复历史。

### 两种查看方法

#### 方法 1：实时日志（元数据）
```bash
journalctl --user -u hermes-gateway -f | grep -E "(Feishu|Lark|im\.message)"
```

**可见信息：** 消息ID、chat ID、发送者ID、消息长度、时间戳、发送/接收状态

**不可见：** 实际消息内容

#### 方法 2：飞书 API（完整内容）

通过 Python 调用飞书开放平台 API 获取实际消息文本。

**Step 1: 获取 tenant_access_token**
```python
import requests

app_id = "cli_xxx"   # from FEISHU_APP_ID in ~/.hermes/.env
app_secret = "xxx"    # from FEISHU_APP_SECRET in ~/.hermes/.env

r = requests.post(
    "https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal",
    json={"app_id": app_id, "app_secret": app_secret}
)
token = r.json()["tenant_access_token"]
```

**Step 2: 获取消息历史**
```python
chat_id = "oc_xxx"  # 从日志中找 chat_id=oc_xxx

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

### 工作流程

1. **找 chat_id**：用户发消息时日志中找 `chat_id=oc_xxx`
2. **获取凭证**：从 `~/.hermes/.env` 读取 `FEISHU_APP_ID` 和 `FEISHU_APP_SECRET`
3. **获取 token**：调用 tenant_access_token API
4. **拉取消息**：用 chat_id 调用消息 API
5. **解析内容**：`msg_type=text` → `json.loads(content)["text"]`

### 快速检查脚本

保存为 `~/feishu_messages.py`：
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

### 常见问题

| 症状 | 原因 | 修复 |
|------|------|------|
| 日志能看到用户消息但看不到机器人回复 | 日志只显示元数据 | 使用飞书 API |
| "app secret invalid" | .env 显示截断了 secret | 直接读取 .env 文件获取完整值 |
| 没有消息返回 | chat_id 错误 | 从日志确认正确的 `chat_id=oc_xxx` |
| 机器人回复慢 | 模型响应时间 | 检查日志中 `time=XXs` |

### 陷阱

- **App Secret 必须是完整值** — .env 显示可能截断，直接读文件
- **Token 约 2 小时过期** — 收到 99991663 错误时重新获取
- **日志文件**：`~/.hermes/logs/agent.log` 比 journalctl 更详细
- **Session 文件**：`~/.hermes/sessions/*.json` 含对话上下文但不是飞书原始消息
- **发送者 ID 格式**：`ou_xxx` = 用户，`cli_xxx` = 机器人

---

## Part 2: 审批确认补丁

### 问题背景
点击飞书审批卡片按钮（Allow Once / Session / Always / Deny）后，除了卡片变色外，没有文字反馈，用户不确定是否收到响应。

### Patch

在 `gateway/platforms/feishu.py` 的 `_update_approval_card` 调用后、`return` 之前插入：

```diff
diff --git a/gateway/platforms/feishu.py b/gateway/platforms/feishu.py
--- a/gateway/platforms/feishu.py
+++ b/gateway/platforms/feishu.py
@@ -2001,6 +2001,14 @@ class FeishuAdapter(BasePlatformAdapter):
 
             # Update the card to show the decision
             await self._update_approval_card(state.get("message_id", ""), label, user_name, choice)
+
+            # Send a text confirmation so the user gets immediate feedback
+            cn_labels = {"once": "Allow Once", "session": "Session", "always": "Always", "deny": "Deny"}
+            cn_label = cn_labels.get(choice, choice)
+            try:
+                await self.send(chat_id=chat_id, content=f"✅ 已收到你的「{cn_label}」指令")
+            except Exception as exc:
+                logger.debug("[Feishu] Failed to send approval confirmation text: %s", exc)
             return
 
         synthetic_text = f"/card {action_tag}"
```

### 应用步骤

1. 检查是否已应用：
```bash
cd ~/.hermes/hermes-agent
grep "已收到你的" gateway/platforms/feishu.py
```

2. 如果未应用，直接编辑 `gateway/platforms/feishu.py`，在 `_update_approval_card` 调用后、`return` 之前插入上述代码块。

3. 重启 gateway：
```bash
systemctl --user restart hermes-gateway
```

### 更新后自动检查

Hermes 更新后，运行检查：
```bash
cd ~/.hermes/hermes-agent && grep -q "已收到你的" gateway/platforms/feishu.py && echo "OK" || echo "需要重新应用 patch"
```

---

## Part 3: 飞书发文件流程

### 1. 获取 tenant_access_token

```python
import requests

r = requests.post(
    "https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal",
    json={"app_id": APP_ID, "app_secret": APP_SECRET}
)
token = r.json()["tenant_access_token"]
```

### 2. 上传文件

```python
with open(file_path, "rb") as f:
    upload_r = requests.post(
        "https://open.feishu.cn/open-apis/im/v1/files",
        headers={"Authorization": f"Bearer {token}"},
        data={"file_type": "stream", "file_name": file_name},
        files={"file": (file_name, f, "application/octet-stream")}
    )
file_key = upload_r.json()["data"]["file_key"]
```

### 3. 发送文件消息

```python
send_r = requests.post(
    "https://open.feishu.cn/open-apis/im/v1/messages",
    params={"receive_id_type": "chat_id"},  # 群聊用 chat_id，私聊用 open_id
    headers={
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json; charset=utf-8"
    },
    json={
        "receive_id": chat_id,  # oc_xxx 格式
        "msg_type": "file",
        "content": json.dumps({"file_key": file_key})
    }
)
```

### 陷阱

- `file_type` 用 `stream`（普通文件），不是 `opus`（音频）
- `receive_id_type` 要匹配：群聊 `chat_id`(oc_xxx)，私聊 `open_id`(ou_xxx)
- App Secret 从 KeePass 获取，需完整值（.env 可能截断显示）
- Token 约 2 小时过期，发送失败时重新获取
