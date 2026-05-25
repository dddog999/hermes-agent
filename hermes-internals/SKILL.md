---
name: hermes-internals
description: "Hermes Agent infrastructure: CLI maintenance, provider config routing, tool-hooks plugin system, and retry/fallback internals for run_agent.py. Load this skill when the task touches config.yaml providers, /model syntax, update/uninstall workflows, hermestown gateway restart, plugin hooks, or fallback chain cooldown."
---

# Hermes Infrastructure & Internals

This skill covers low-level Hermes Agent infrastructure concerns — CLI maintenance, provider-config routing, tool-hooks (pre_tool_call / transform_tool_result), and the retry/fallback cascade in `run_agent.py`. Unlike `autonomous-ai-agents/hermes-agent` (which covers setup, configuration, spawning, and general usage), this skill covers *implementation internals and maintenance operations* of Hermes itself.

---

## hermes-cli-maintenance — update / uninstall / fork-sync

`hermes update` internally: `git stash` → `git checkout main` → `git pull` → `git merge upstream/main` → `git stash pop` → `pip install`.

**Known traps:**
- **Stash state inconsistency**: After upstream merge failure, `git stash list` may show an entry but the changes are already in working tree → `git stash drop`
- **Untracked files blocking merge**: `git merge upstream/main` fails on `.github/workflows/lint.yml` already present → `rm -f` it, then retry
- **Version-number-grade downgrade display**: pip output may show "0.13.0 → 0.12.0" — the real state is `git log HEAD`, not the pip log
- `hermes update` can hang when upstream merge conflicts exist (H.F.C. gallery)

**Windows uninstall (full):**
- Junction safety — only `cmd /c "rmdir <path>"` removes a junction without touching the target
- Preserved vs deleted: config.yaml/.env/sessions/logs/memories are preserved by default; `Remove-Item -Recurse -Force "$env:LOCALAPPDATA\hermes"` does a full wipe
- `hermes.exe uninstall` does NOT exist; must follow manual link-backward-ops script
- Powershell `$` escaping: complex commands must be written to `.ps1` files and run via `pwsh.exe -File`

---

## hermes-provider-config-pitfalls — /model syntax & .env write limits

`/model` command does NOT support `provider:model` colon syntax. That sends the whole string as a model name to the current provider → HTTP 400.

**Correct syntax:**
```
/model sensenova-6.7-flash-lite --provider sensenova
/model <name> --global                          # persist to config.yaml
/model --provider <provider>                    # provider-only switch
```
`--global` writes `model.default` + `model.provider` to `config.yaml`. Without it, changes are in-memory only and lost on `/new` or gateway restart.

**`config.yaml` config structure:**
```yaml
providers:
  sensenova:
    name: sensenova
    api_mode: chat_completions
    base_url: https://token.sensenova.cn/v1
    key_env: SENSENOVA_API_KEY
    default_model: sensenova-6.7-flash-lite   # ← field is default_model, not model
    # (omit default_model → use /model value)
```

**pitfalls list:**
1. **No colon syntax** — `provider:model` is read as whole-model-name
2. **providers key must not collide with built-in registry keys** (minimax, openrouter, etc.)
3. **`default_model` not `model`** in providers dict
4. **API key via `key_env`**, never hardcode
5. **`.env` is protected** — `write_file`/`patch` silently fails on it; use `sed -i` or Node.js script
6. **`auxiliary.compression.provider: auto`** avoids MiniMax M2.7 context cap (204K) — use `auto` to inherit main provider
7. OpenRouter `max_tokens` truncation warning is model-side, not Hermes fault — set conservative `max_tokens: 8192`

---

## hermes-tool-hooks — pre_tool_call / transform_tool_result / shell-hooks

Three-layer hook system (in execution order):
```
pre_tool_call       → block only, no rewrite   (shell + Python callback)
tool dispatch       → actual execution
transform_tool_result → result rewriting (post-execution)
```

**`pre_tool_call`**: Returns `{"action":"block","message":"..."}` or `{"decision":"block","reason":"..."}` from shell/script, or `Optional[dict]` from Python plugin callback. **Shell hooks cannot rewrite** — only block. The Python callback can modify `args` dict in-place (dict is passed by reference) as an undocumented path.

**`transform_tool_result`**: First non-None return replaces the LLM-visible result. Too late for security interception — dangerous command already ran.

**`transform_terminal_output`**: post-run stdout/stderr text filtering.

**Practical pattern — rm → trash via Python plugin:**
```python
def on_pre_tool_call(*, tool_name="", args=None, **kw):
    if tool_name == "terminal" and isinstance(args, dict):
        cmd = args.get("command", "")
        if cmd.startswith("rm "):
            args["command"] = cmd.replace("rm ", "trash-put ", 1)
            args["_rewritten"] = True     # debug marker
    return None   # don't block — let it run
```

**Shell alias doesn't work**: Hermes terminal tool uses `subprocess.run(..., shell=False)`. Shell aliases are not expanded. Commands must be argv arrays.

**Registration** (config.yaml):
```yaml
hooks:
  pre_tool_call:
    - matcher: "terminal"
      command: "/path/to/hook.sh"
      timeout: 30
```

---

## hermes-retry-fallback-fix — rate-limit cascade pattern in run_agent.py

When a provider returns HTTP 429, Hermes uses `jittered_backoff()` and then switches to the fallback provider chain. The bug (fixed 2026-05-07) was **zero-delay fallback** — the next provider was tried immediately, burning through the entire chain in seconds with cascading failures.

**Fix pattern applied:**
| Transition | Old delay | Fixed delay |
|---|---|---|
| Normal retry backoff | 10–60s | 15–90s |
| Rate-limit → eager fallback | 0s | 15–45s (jittered) |
| Fallback chain cooldown | 0s | 30–120s (per-index) |
| Non-retryable → fallback | 0s | 10–30s |

**Universal rule**: always add cooldown *before* switching providers. Make cooldown increase with `fallback_index` — later fallbacks get longer waits since earlier ones failed first.

**Provider notes:**
- **MiniMax CN**: Token Plan rate limits are quota-based, not request-count-based — credential rotation can't recover; skip straight to fallback
- **OpenRouter free**: Transient transport errors are worth retrying via `_try_recover_primary_transport`
- Use `jittered_backoff`, not fixed `time.sleep`, to prevent thundering-herd

---

## hermes-gateway-fix — gateway 启动失败诊断

Gateway 启动失败排查流程（已合并入 hermes-internals，完整内容见 `references/hermes-gateway-fix.md`）：

### 症状识别
- `curl http://localhost:8642/health` → 连接失败
- `systemctl --user status hermes-gateway.service` → `ModuleNotFoundError: No module named 'httpx'`
- `ERROR gateway.run: PID file race lost to another gateway instance`
- 飞书显示"已离线"

### 诊断三件套
```bash
ss -tlnp | grep 8642                           # 端口监听
systemctl --user status hermes-gateway.service  # systemd 状态
cat ~/.hermes/gateway.pid && kill -0 $(cat ~/.hermes/gateway.pid)  # PID 存活检查
```

### 最常见的修复

| 原因 | 修复命令 |
|------|---------|
| hermes-agent venv 缺 httpx | `~/.hermes/venv/bin/pip install httpx` |
| Stale PID file | `rm ~/.hermes/gateway.pid && hermes gateway start` |
| systemd 服务重启失败 | `systemctl --user daemon-reload && systemctl --user restart hermes-gateway` |

Full diagnostic + step-by-step fix flow: `references/hermes-gateway-fix.md`


---

## openviking — vector DB memory system

OpenViking 是多机共享记忆的向量数据库（abbreviated as OV in this codebase). Cross-machine memory isolation 与 multi-tenant Admin API 参考见 `references/openviking-cross-machine.md` 和 `references/openviking-usage.md`.

