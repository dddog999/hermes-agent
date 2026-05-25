---
name: feishu-at-mention-format
description: 飞书 @mention 格式问题排查与修复——区分高亮可点击 mention 和纯文本
---

# 飞书 @mention 格式：可点击高亮 vs 纯文本

## 核心发现

飞书群里 @mention 有两种实现方式，效果截然不同：

| 方式 | 消息 content 结构 | 渲染效果 | 对方能否响应 |
|------|-----------------|---------|------------|
| 飞书内置 picker | `{tag:"at", open_id:"ou_xxx", user_name:"botname"}` | 高亮可点击链接 | ✅ 是 |
| 手动输入 `@botname` | 纯文本 `"@botname"` | 普通文字，无高亮 | ❌ 否 |

**手动输入 `@wooking` 虽然看起来像 mention，但飞书不当作 mention 事件处理。**

## 对 Hermes 的影响

Hermes 的 `feishu.py` 在发送回复时（`_build_outbound_payload`），所有内容都被转成 `post` 类型的 `md` 元素。如果文本里有 `@wooking`，它会被渲染成纯文本而非 at-element。

### 修复方法

在 `_build_markdown_post_rows` 中，对非代码块文字做 @mention 转换：

1. 新增正则 `_BOT_AT_RE = re.compile(r"@([\w\u4e00-\u9fff-]+)")` 匹配文字中的 `@botname`
2. `_split_text_with_at_elements()` 将匹配的 self-mention 转换为 `{tag:"at", open_id:"...", user_name:"..."}` 元素
3. 仅对自身 bot name 转换，避免误转其他 @名字
4. 代码块内不做转换（隔离处理）
5. 调用链：`_build_outbound_payload` → `_build_markdown_post_payload` → `_build_markdown_post_rows` → `_split_text_with_at_elements`

### 飞书权限排除项

排查过程中确认：群内 bot 相互 @ 失败，权限不是主因（已有 `im:message:send_as_bot` 等）。主要原因是 **消息格式**，次要原因是 **Bot 隐私设置**（飞书后台 → 机器人隐私 → 「允许其他机器人 @我」）。
