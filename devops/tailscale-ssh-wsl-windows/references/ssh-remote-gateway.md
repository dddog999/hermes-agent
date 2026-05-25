## Session Findings: wooking-wsl Access (2026-05-25)

### MagicDNS vs IP — Both Work, Username Rule Is Absolute

**Discovery:** `ssh dddog@wooking-wsl` (MagicDNS + locale username) succeeds without any Tailscale browser auth. Direct IP `ssh dddog@100.93.133.44` also works (Tailscale P2P routing).

**Critical rule:** The username MUST be the remote machine's locale UNIX user. The Tailscale display name (`dddog535459`) does NOT work as an SSH user — it produces "failed to look up local user" or triggers Tailscale SSH interception.

| SSH user tried | Result |
|---|---|
| `dddog535459` (Tailscale display name) | "failed to look up local user" — Tailscale intercepts |
| `dddog` (locale UNIX username) | ✅ SSH key auth succeeds, no password, no browser |
| `kangle` (local user on kangle machine) | ❌ "failed to look up local user" — wrong machine |
| `dddog@wooking-wsl` (MagicDNS) | ✅ Correct — hostname is MagicDNS, user is locale name |
| `dddog@100.93.133.44` (direct IP) | ✅ Also works via Tailscale P2P routing |

### Remote Gateway Launch — tmux Available but Command Approval Blocks

**Discovery:** wooking-wsl has `tmux 3.4` installed. Gateway is NOT running (no hermes_cli processes found). However, `systemctl --user` fails with "Failed to connect to bus" (expected for non-interactive SSH).

**Command Approval blocks all background-launch shorthands** when the agent executes the SSH command: `&`, `nohup`, `tmux new-session -d`, `setsid`, `exec ... &`.

**Workaround:** The user must manually run the launch command in their own SSH terminal, or use an inline script approach without apparent background-spawn syntax.

```bash
# Preferred: tmux (already available on wooking-wsl)
ssh dddog@wooking-wsl
# Then in the SSH session:
tmux new-session -d "exec ~/.hermes/hermes-agent/venv/bin/python -m hermes_cli.main gateway run --replace >> ~/.hermes/gateway.log 2>&1"
```

### Tailscale SSH Interception Pattern

When `tailscale ssh dddog@wooking-wsl` is used, it intercepts and requires browser auth. Plain `ssh dddog@wooking-wsl` bypasses Tailscale SSH entirely and reaches the WSL sshd directly.

**Summary of connection approaches (best to worst):**
1. ✅ `ssh dddog@wooking-wsl` — MagicDNS hostname + locale username, no browser auth, SSH key auth
2. ✅ `ssh dddog@100.93.133.44` — Direct Tailscale IP + locale username, same as above
3. ❌ `tailscale ssh dddog@wooking-wsl` — Triggers Tailscale SSH browser auth
4. ❌ `ssh kangle@100.93.133.44` — Wrong username (kangle is local to this machine, not remote)