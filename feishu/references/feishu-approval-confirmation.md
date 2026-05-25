# Feishu Approval Confirmation
> Absorbed from `feishu-approval-confirmation` — Feishu API debugging reference.

---


# Feishu Approval Button Confirmation Patch

用户点击飞书审批卡片按钮（Allow Once / Session / Always / Deny）后，除了卡片变色外，额外发送一条文字确认消息。

## 问题背景
点击 "Command Approval Required" 卡片按钮后，机器人没有文字反馈，用户不确定是否收到响应。

## Patch

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

## 应用步骤

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

## 更新后自动检查

Hermes 更新后，运行检查：
```bash
cd ~/.hermes/hermes-agent && grep -q "已收到你的" gateway/platforms/feishu.py && echo "OK" || echo "需要重新应用 patch"
```
