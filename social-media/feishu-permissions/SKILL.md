---
name: feishu-permissions
description: 飞书应用权限完整清单与权限问题排查。通过代码审查 reverse-engineer 飞书 API 调用，自动生成所需 OAuth scopes 与事件订阅列表。
---

# Feishu Permissions — 从代码反向推导所需权限

## 核心经验（试错得出）

### Bot 群内相互 @ 不响应 — 最常见根因

**现象：** 人类 @Bot B → Bot B 回复正常。Bot A @Bot B → Bot B 无响应，日志无报错。
**代码路径：** `_handle_message_event_data` → `_should_accept_group_message` → `normalize_feishu_message` → `_post_mentions_bot`
**根因：** 缺少 `im:message:read` 权限。WebSocket 事件只提供消息原始 JSON，但提取 `@mention` 目标 ID（`mentioned_ids`）需要调用 `im:message:read` API。权限缺失时 `normalize_feishu_message` 返回空 `mentioned_ids` → `_should_accept_group_message` 返回 False → 消息被静默丢弃。
**修复：** 在飞书开放平台 → 权限管理 → 添加 `im:message:read`（读取消息）租户权限 → 重新发布应用。

## 完整 OAuth Scopes

### Tenant Scopes

```json
[
  "im:message:send_as_bot",
  "im:message:readonly",
  "im:message:read",
  "im:message:recall",
  "im:message:update",
  "im:message.reactions:read",
  "im:message.reactions:write_only",
  "im:message.pins:read",
  "im:message.pins:write_only",
  "im:message.group_at_msg:readonly",
  "im:message.group_msg",
  "im:message.p2p_msg:readonly",
  "im:message.urgent",
  "im:message.urgent:phone",
  "im:message.urgent:sms",
  "im:message.urgent.status:write",
  "im:message:send_multi_depts",
  "im:message:send_multi_users",
  "im:message:send_sys_msg",
  "im:chat:readonly",
  "im:chat:read",
  "im:chat:create",
  "im:chat:delete",
  "im:chat:update",
  "im:chat:operate_as_owner",
  "im:chat:moderation:write_only",
  "im:chat.access_event.bot_p2p_chat:read",
  "im:chat.announcement:read",
  "im:chat.announcement:write_only",
  "im:chat.chat_pins:read",
  "im:chat.chat_pins:write_only",
  "im:chat.collab_plugins:read",
  "im:chat.collab_plugins:write_only",
  "im:chat.managers:write_only",
  "im:chat.members:read",
  "im:chat.members:write_only",
  "im:chat.members:bot_access",
  "im:chat.menu_tree:read",
  "im:chat.menu_tree:write_only",
  "im:chat.moderation:read",
  "im:chat.tabs:read",
  "im:chat.tabs:write_only",
  "im:chat.top_notice:write_only",
  "im:chat.widgets:read",
  "im:chat.widgets:write_only",
  "docx:document:readonly",
  "drive:comment:readonly",
  "admin:app.info:readonly",
  "contact:user.id:readonly"
]
```

### User Scopes

```json
["im:message", "docx:document:readonly"]
```

### 最小权限集（仅基础消息功能）

```json
{
  "tenant": [
    "im:message:send_as_bot",
    "im:message:readonly",
    "im:message:read",
    "im:chat:readonly",
    "im:chat:read"
  ],
  "user": ["docx:document:readonly"]
}
```

## 事件订阅（不在 OAuth scopes，需在飞书后台单独配置）

在 飞书开放平台 → 事件订阅 → 长连接（WebSocket）模式：

| 事件名 | 用途 |
|--------|------|
| `im.message.receive_v1` | 接收消息（必须） |
| `im.message.message_read_v1` | 消息已读回执 |
| `im.message.reaction.created_v1` | 用户添加 reaction |
| `im.message.reaction.deleted_v1` | 用户删除 reaction |
| `im.chat.member.bot_added_v1` | Bot 被加入群 |
| `im.chat.member.bot_deleted_v1` | Bot 被移出群 |
| `im.chat.access_event.bot_p2p_chat_entered_v1` | 用户进入与 bot 的 P2P 聊天 |
| `im.message.recalled_v1` | 消息被撤回 |
| `drive.notice.comment_add_v1` | 文档新增评论（需同时申请 `drive:comment:readonly` 权限） |

## 从代码反向推导权限的方法

当新增飞书 API 功能时，按以下步骤推导所需权限：

1. **找到所有 API 调用**（grep `im\.v1\.|lark_oapi` 在 `gateway/platforms/feishu.py` 和 `tools/` 下）
2. **识别缺少的权限**：调用的 API 需要什么 scope
3. **检查事件订阅**：新增 `register_p2_*` 或 `register_customized_event` 意味着需要在后台订阅事件
4. **OAuth vs 事件订阅**：事件订阅不在 OAuth scopes 里，在飞书后台「事件订阅」页面配置

### 常用 API 对应权限参考

| API | 所需权限 |
|-----|----------|
| `im.v1.message.create` | `im:message:send_as_bot` |
| `im.v1.message.reply` | `im:message:send_as_bot` |
| `im.v1.message.update` | `im:message:update` |
| `im.v1.message.recall` | `im:message:recall` |
| `im.v1.message.get` | `im:message:readonly` |
| `im.v1.message_resource.get` | `im:message:read` |
| `im.v1.image.create` | `im:message:send_as_bot` |
| `im.v1.file.create` | `im:message:send_as_bot` |
| `im.v1.chat.get` | `im:chat:readonly` |
| `im.v1.message_reaction.create` | `im:message.reactions:write_only` |
| `im.v1.message_reaction.delete` | `im:message.reactions:write_only` |
| `drive.notice.comment_add_v1` | `drive:comment:readonly`（事件订阅） |
