---
name: clawmem-hermes-hooks-status
description: ClawMem Hermes hooks 当前状态 — 未注册、payload 缺陷、替代方案
---

# ClawMem Hermes Hooks 状态（2026-05-08）

## config.yaml 中 hooks 是空的

```bash
$ grep -A5 "^hooks:" ~/.hermes/config.yaml
hooks: {}
hooks_auto_accept: false
```

**源码存在但未注册**：
- `src/hooks/hermes-stop.mjs` ✓ 存在
- `src/hooks/hermes-session-start.mjs` ✓ 存在
- `src/hooks/hermes-session-end.mjs` ✓ 存在
- 但 `config.yaml` 没有注册条目

## Hermes on_session_finalize 不传对话历史

即使注册了，Hermes 的 `on_session_finalize` 也不传对话内容：
- `extra.conversation_history` 不存在
- `extra.transcript_text` 不存在
- 详见 `clawmem-hooks-architecture` skill 的 `references/hermes-payload-pitfall.md`

**结论**：Hermes hooks 当前不会自动写记忆文件。

## 用户状态

- 已放弃 CodeBuddy hooks
- 只用 Hermes hooks
- 需要另外的方案来实现会话结束自动写记忆

## 注册方法（参考 clawmem-hooks-architecture skill）

```yaml
hooks:
  on_session_finalize:
    - command: node /mnt/c/Users/kangle/clawmem/src/hooks/hermes-stop.mjs
      timeout: 120
  on_session_start:
    - command: node /mnt/c/Users/kangle/clawmem/src/hooks/hermes-session-start.mjs
      timeout: 30
  on_session_end:
    - command: node /mnt/c/Users/kangle/clawmem/src/hooks/hermes-session-end.mjs
      timeout: 60
```
