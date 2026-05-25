---
name: browser-harness-chrome-debugging
description: Chrome Remote Debugging connection pattern for browser-harness (agent-browser). When user manually logs into a site in Chrome, connect to that existing authenticated session to skip re-login.
---

# Chrome Remote Debugging for browser-harness

## Prerequisite

Chrome does NOT enable remote debugging by default. User must start Chrome with the flag:

```bash
# Windows
chrome.exe --remote-debugging-port=9222
```

## Connection

```bash
# Connect to existing Chrome session
agent-browser --auto-connect open https://example.com
agent-browser --auto-connect snapshot

# Or explicit CDP port
agent-browser --cdp 9222 snapshot
```

## Pitfall

If Chrome wasn't started with `--remote-debugging-port=9222`, `--auto-connect` fails silently:
- Starts a NEW browser instance instead (fresh, no auth)
- User appears logged out

Always confirm user started Chrome with the debugging flag.

## Use Case

User manually logs into a site in Chrome (completing 2FA/ SMS verification manually), then agent-browser connects to that authenticated session to continue automation without re-login.
