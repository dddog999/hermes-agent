---
name: clawmem-hooks-architecture
description: ClawMem hooks 双平台架构——dispatcher+adapter 模式同时支持 CodeBuddy 和 Hermes，记忆自动提取核心
---

# ClawMem Hooks 双平台架构（2026-05-21 更新）

## 架构：dispatcher + adapter

```
hermes-stop.mjs / stop.mjs（平台入口）
    ↓ readStdin()
dispatcher.mjs（平台检测）
    ├─ detectPlatform(): 全大写事件名 → codebuddy
    │                  on_/subagent_ 前缀 → hermes
    ↓
codbuddy-adapter.mjs / hermes-adapter.mjs（payload → 标准化格式）
    ↓ 标准化 payload: { platform, event, session_id, cwd, messages[] }
handleStop(messages, source)（核心函数）
    ↓
wiki/raw/memory/{topic}/*.md（L0/L1 记忆，按话题分目录）
```

## 关键文件（2026-05-21 确认）

| 文件 | 作用 | 路径 |
|------|------|------|
| `src/hooks/dispatcher.mjs` | 平台检测 + 路由 | `/mnt/c/Users/kangle/clawmem/src/hooks/` |
| `src/hooks/codbuddy-adapter.mjs` | CodeBuddy → 标准化格式 | 同上 |
| `src/hooks/hermes-adapter.mjs` | Hermes → 标准化格式 | 同上 |
| `src/hooks/hermes-stop.mjs` | Hermes `on_session_finalize` 入口 | 同上 |
| `src/hooks/hermes-session-start.mjs` | Hermes `on_session_start` 入口 | 同上 |
| `src/hooks/hermes-session-end.mjs` | Hermes `on_session_end` 入口 | 同上 |
| `src/hooks/stop.mjs` | CodeBuddy `Stop` 入口，`handleStop()` 已导出 | 同上 |
| `src/hooks/utils.mjs` | 共享工具函数（parseTranscript, extractKeywords） | 同上 |

> ⚠️ 旧 skill 记录的路径 `/mnt/c/Users/dddog/clawmem/src/hooks/` 已过时。正确路径是 `/mnt/c/Users/kangle/clawmem/src/hooks/`。

## Topic-Based 记忆路由（2026-05-21 新增）

`stop.mjs` 和 `hermes-session-end.mjs` 现在支持按话题分目录存储记忆。

### inferTopic() 话题检测规则

| 话题 | 子目录 | 匹配关键词 |
|------|--------|-----------|
| clawmem | `clawmem/` | clawmem, 记忆系统, memory system, phase\d |
| hermes-hooks | `hermes-hooks/` | hermes.*hook, shell.*hook, allowlist, session.*start/end/finalize |
| hermes-config | `hermes-config/` | hermes.*config, hermes.*setup/install/uninstall |
| ocr-paddleocr | `ocr-paddleocr/` | paddleocr, ocr, 文字识别, pp.*ocr/structure |
| keepass | `keepass/` | keepass, 密码, password, pykeepass |
| feishu | `feishu/` | 飞书, feishu, lark |
| openviking | `openviking/` | openviking, viking |
| networking | `networking/` | tailscale, ssh |
| github | `github/` | github, pull request, commit |
| user-prefs | `user-prefs/` | 偏好, 喜欢, 习惯, preference |
| workflow | `workflow/` | 流程, 步骤, 方法论, workflow, gsd, sdd |
| bugfix | `bugfix/` | bug, fix, 修复, error, crash |
| skills | `skills/` | skill, 技能 |
| project | `project/` | project, 架构, 决策, 设计, 模块, 组件, 系统 |
| misc | `misc/` | 默认 fallback |

### mkdirSync Fallback

当子目录创建失败（如坚果云同步目录只读），自动回退到根目录 `MEMORY_DIR`：

```javascript
try {
  mkdirSync(targetDir, { recursive: true });
} catch (e) {
  writeDir = MEMORY_DIR; // fallback
}
```

### 文件名清理

- 移除 `[Replying-to:...]` 前缀
- 空格 → `-`，合并连续 `-`
- 去除首尾 `-`
- 格式：`shortdesc-id.md`

## Hermes payload 格式（on_session_finalize）

```json
{
  "hook_event_name": "on_session_finalize",
  "session_id": "sess_abc123",
  "cwd": "/path",
  "extra": {
    "conversation_history": [
      {"role": "user", "content": "用户消息"},
      {"role": "assistant", "content": "AI回复"}
    ]
  }
}
```

**注意**：Hermes 没有 `transcript_path` 字段，对话内容直接内联在 `extra.conversation_history`。

## config.yaml 注册（已生效）

```yaml
hooks:
  on_session_finalize:
  - command: node /mnt/c/Users/kangle/clawmem/src/hooks/hermes-stop.mjs
    timeout: 120
  on_session_start:
  - command: node /mnt/c/Users/kangle/clawmem/src/hooks/hermes-session-start.mjs
  on_session_end:
  - command: node /mnt/c/Users/kangle/clawmem/src/hooks/hermes-session-end.mjs
hooks_auto_accept: true
```

## 手动测试命令

```bash
# 模拟 Hermes on_session_finalize 触发
echo '{
  "hook_event_name": "on_session_finalize",
  "session_id": "test",
  "cwd": "/tmp",
  "extra": {"conversation_history": [
    {"role": "user", "content": "测试消息"},
    {"role": "assistant", "content": "测试回复"}
  ]}
}' | node /mnt/c/Users/kangle/clawmem/src/hooks/hermes-stop.mjs 2>&1
```

## 验证 hooks 是否生效

```bash
# 检查 debug log
tail -20 ~/.clawmem/stop-hook-debug.log
tail -20 ~/.clawmem/hermes-session-end-debug.log

# 检查新文件是否按话题分目录
ls wiki/raw/memory/clawmem/
ls wiki/raw/memory/hermes-hooks/
```

## 关键教训

- Hermes hooks **必须**在 `config.yaml` 的 `hooks:` 块注册才会生效
- Hermes 事件名是 camelCase（`on_session_finalize`），不是 CodeBuddy 的大写（`Stop`）
- Hermes 没有 transcript 文件，对话通过 `extra.conversation_history` 内联传递
- Hook 脚本用 `.mjs` 后缀（Hermes 只支持 node 直接运行 .mjs）
- **坚果云同步目录只读**：`C:\Users\dddog\Nutstore\1\myNutstore\` 从 WSL/Windows 侧是只读的（Users 组只有 RX 权限）。hooks 写入时如果子目录创建失败，会回退到根目录。
- **Python 可以创建目录**：`os.makedirs()` 在坚果云目录上可能成功（即使 PowerShell/New-Item 报 Access Denied）
