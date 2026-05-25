---
name: hermes-upstream-windows-integration
description: Hermes Agent 上游官方版 Windows 适配融合工作流——官方安装 + 补丁保留 + 配置迁移（2026-05-18 实测）
category: devops
---

# Hermes 上游官方版 Windows 融合指南

## 背景

2026-05 上游已原生支持 Windows（v0.14.0），不再需要维护独立的 feat/windows-native fork。本 skill 记录从旧 fork 迁移到官方版并保留必要补丁的完整流程。

## 当前环境（2026-05-18）

| 组件 | 路径 |
|---|---|
| 旧 fork | `C:\Users\dddog\hermes-windows\`（feat/windows-native 分支，已删除） |
| 备份仓 | `https://gitee.com/dddog535459/hermes-windows`（8 个 commit 的完整备份） |
| 旧生产（WSL） | `~/.hermes/hermes-agent/`（feat/windows-native，仍在） |
| 新官方安装（Windows） | `C:\Users\dddog\AppData\Local\hermes\.hermes\hermes-agent`（upstream/main，v0.14.0） |
| WSL hermes 配置 | `~/.hermes/`（WSL 路径，对应 Windows `C:\Users\dddog\.hermes\`） |
| Windows 官方配置 | `C:\Users\dddog\AppData\Local\hermes\`（**不是** `C:\Users\dddog\.hermes\`） |

> ⚠️ **路径陷阱**：Windows 官方 hermes 的 `HERMES_HOME` 默认展开为 `%LOCALAPPDATA%\hermes`（即 `C:\Users\dddog\AppData\Local\hermes\`），而 WSL hermes 的 `~/.hermes/` 在 Windows 下是 `C:\Users\dddog\.hermes\`。**两者完全不同**，各自独立，不能混用。

## Step 1: 官方版安装（WSL 环境）

### 背景限制
- `git clone` 因 Tailscale DNS 拦截 GitHub 返回 198.18.x.x 代理 IP，TLS 握手超时
- `curl` 用 OpenSSL，`git` 用 GnuTLS，行为不一致（curl 可访问 api.github.com，git 不行）
- `scripts/install.ps1` 在 WSL 中因 UNC 路径被拒绝

### 实测可用安装方法

```bash
install_dir="/mnt/c/Users/dddog/AppData/Local/hermes/.hermes/hermes-agent"
mkdir -p "$install_dir"

# 用 Python urllib 通过 GitHub API 下载 tarball（绕过 TLS 问题）
python3 -c "
import urllib.request, tarfile, io, os
url = 'https://api.github.com/repos/NousResearch/hermes-agent/tarball/main'
req = urllib.request.Request(url, headers={'User-Agent': 'hermes-install'})
with urllib.request.urlopen(req, timeout=120) as r:
    data = r.read()
with tarfile.open(fileobj=io.BytesIO(data), mode='r:*') as tf:
    for member in tf.getmembers():
        if member.name.startswith('./'):
            member.name = member.name[2:]
        parts = member.name.split('/', 1)
        if len(parts) > 1:
            member.name = parts[1]
        else:
            continue
        if member.name:
            tf.extract(member, '$install_dir')
"

# 创建 venv 并安装
cd "$install_dir"
uv venv .venv --python 3.11
source .venv/bin/activate
uv pip install -e ".[dev]"

# 验证
hermes --version
```

**注意**：安装路径是 `%LOCALAPPDATA%\hermes\.hermes\`（两级 .hermes），不是一级。

## Step 2: 旧目录备份到 Gitee

### 方案选择
- GitHub SSH：**不通**（超时）
- GitHub HTTPS：需要 PAT（`.netrc` 中没有）
- Gitee：可用（有 `~/.gitee_token`）

### 操作步骤

```bash
# 在旧目录添加 gitee remote 并 push
cd /mnt/c/Users/dddog/hermes-windows
git remote add gitee https://dddog535459:$(cat ~/.gitee_token)@gitee.com/dddog535459/hermes-windows.git
git push gitee feat/windows-native:feat/windows-native
```

### 如果遇到 shallow update not allowed（常见于 pack.depth=1 的浅克隆）

```bash
# 1. 在 /tmp 创建新仓库作为中介
mkdir /tmp/hw-push && cd /tmp/hw-push
git init
echo "hermes-windows backup" > README.md
git add README.md && git commit -m "chore: initial commit"
git remote add origin https://dddog535459:$(cat ~/.gitee_token)@gitee.com/dddog535459/hermes-windows.git
git push origin master:feat/windows-native

# 2. 把旧目录的文件 rsync 进去
rsync -a --exclude='.git' /mnt/c/Users/dddog/hermes-windows/ .
git add -A && git commit -m "chore: backup all files from hermes-windows"
git push origin master:feat/windows-native --force
```

## Step 3: 旧目录安全删除（进回收站）

```bash
gio trash /mnt/c/Users/dddog/hermes-windows \
        /mnt/c/Users/dddog/hermes-agent-windows \
        /mnt/c/Users/dddog/hermes-windows-objects \
        /mnt/c/Users/dddog/hermes-windows-win.bundle \
        /mnt/c/Users/dddog/hermes-windows.zip
```

**不要用 npm 的 `trash` 包**——在 PowerShell 无界面环境下会 hang 住无响应。`gio trash` 是最可靠的跨平台回收站方式。

## Step 4: 保留的独有补丁

需从旧 fork 迁移到新官方版的独有改动（已通过 gitee 备份）：

| 补丁 | 说明 | 优先级 |
|---|---|---|
| `gateway restart win32 分支` | `launch_detached_restart()` 的 `subprocess.Popen` + `CREATE_NEW_PROCESS_GROUP \| DETACHED_PROCESS` | P0 |
| watcher 竞态修复 | spawn 移到 lock 释放后 + 简化 watcher | P0 |
| watcher 漏传 `gateway run` 参数 | cmd 缺少 `["gateway", "run"]` | P0 |
| `_find_bash()` 排除 WSL bash | 上游已有类似逻辑，确认无冲突可跳过 | P2 |

**合并方式**：在 `~/.hermes/hermes-agent/`（新官方安装）手动 apply patch，或在 gitee 备份分支上 rebase 后 cherry-pick。

## Step 5: 验证新安装

```bash
cd /mnt/c/Users/dddog/AppData/Local/hermes/.hermes/hermes-agent
source .venv/bin/activate
hermes --version     # → Hermes Agent v0.14.0
hermes chat -q "hello"  # 测试 API 连通性
tail -n 50 ~/.hermes/logs/agent.log  # 检查加载状态
```

## 关键陷阱

### Tailscale DNS 拦截 GitHub
WSL 内 `/etc/resolv.conf` 用 `100.100.100.100`（Tailscale DNS），将 github.com 解析到 198.18.x.x（代理 IP），导致 git clone/git push SSH/HTTPS 均失败。解法：
- 查真实 IP：`python3 -c "import socket; print(socket.gethostbyname('github.com'))"` → `140.82.x.x`
- 静态绑定：`/etc/hosts` 加 `140.82.x.x github.com`
- 或用 GitHub API（`api.github.com` 可能通）下载 tarball

### 两个 hermes 安装共存
旧生产 `~/.hermes/hermes-agent/` 和新官方 `C:\AppData\Local\hermes\.hermes\hermes-agent` 完全独立，共用 `~/.hermes/` 配置。确认激活的是哪个：
```bash
which hermes  # 看路径
hermes --version  # 看版本
```

### Gitee push 时的 shallow repo 问题
从 GitHub fork 的浅克隆（`pack.depth=1`）无法 push 到空的 gitee 仓库（"shallow update not allowed"）。必须先在 gitee 建初始 commit，再用完整文件 push。

## 验证节点

- [ ] `hermes --version` 显示 v0.14.0
- [ ] `hermes chat -q "hello"` 正常响应
- [ ] ClawMem MCP 工具正常加载（logs 中有 `clawmem` 关键字）
- [ ] 旧目录已进回收站（`ls /mnt/c/Users/dddog/hermes-windows` → No such file）
- [ ] gitee 备份仓有完整文件
