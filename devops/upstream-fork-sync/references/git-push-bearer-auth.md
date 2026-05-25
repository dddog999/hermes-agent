# git push via HTTPS with Bearer Token —绕过 Tailscale DNS 劫持

## 问题背景

WSL + Tailscale 环境下，github.com 被 DNS 劫持到 `198.18.x.x`（CIPA 内网段），导致：
- SSH port 22 连接被 reset
- HTTPS TLS 握手 EOF 失败

常用方案全部失败：
- URL 嵌入 token → `terminal prompts disabled`
- SSH 密钥 → 连接被 198.18.0.x reset
- Credential helper → 不适用

## 唯一可行方案

`GIT_HTTP_AUTHORIZATION=Bearer <token>` 环境变量：

```bash
cd ~/.hermes/hermes-agent/user-skills
git remote set-url fork https://github.com/owner/repo.git
GIT_TERMINAL_PROMPT=0 GIT_HTTP_AUTHORIZATION="Bearer ghp_XXXXXXXXXXXX" \
  git push -u fork master --force
```

## 完整重试脚本

```python
#!/usr/bin/env python3
"""git push via HTTPS Bearer auth — 绕过 Tailscale DNS 劫持"""
import subprocess
import os

TOKEN = "ghp_XXXXXXXXXXXX"  # 从 KeePass 获取
REPO = "/path/to/repo"

env = os.environ.copy()
env["GIT_TERMINAL_PROMPT"] = "0"
env["GIT_HTTP_AUTHORIZATION"] = f"Bearer {TOKEN}"

for attempt in range(1, 11):
    print(f"Attempt {attempt}/10...")
    proc = subprocess.run(
        ["git", "-C", REPO, "push", "-u", "fork", "master", "--force"],
        env={**env},
        capture_output=True, text=True, timeout=120
    )
    output = proc.stdout + proc.stderr
    if proc.returncode == 0:
        print("SUCCESS!")
        break
    print(output[:300])
    if "Everything up-to-date" in output:
        break
    time.sleep(5)
```

## 验证推送结果

```bash
# 查询分支 SHA 确认推送成功
gh api repos/owner/repo/git/refs/heads/branch-name --jq '.object.sha'

# 推送后检查远程分支
git ls-remote fork branch-name
```

## 注意事项

- **Token 类型**：必须是 `ghp_`（Classic PAT）而非 `gho_`（OAuth），后者没有 workflow scope
- **网络不稳定时**：多重试几次（脚本中 10 次），每次间隔 5 秒
- **`--force`**：首次推送新分支需要，后续同步不需要
- **分支名**：避免在 main/master 上 push，应在专门分支（如 `user-skills`）上操作