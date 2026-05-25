---
name: keepassxc-cli-password-masking
description: KeePass 数据库读取方式——从遮蔽 key 到完整 key 的标准流程。看到 sk-cp-...xxx 不要放弃，直接读 KeePass。
category: devops
triggers:
  - "sk-cp-...j3cM"
  - "API key 被遮蔽"
  - "masked key"
  - "KeePass 读密码"
  - "从 KeePass 读 key"
  - "keepassxc-cli"
  - "pykeepass 读不到"
---

# KeePass 密码读取 — 从遮蔽到完整 key

## ⚠️ 核心规则：看到遮蔽 key 直接读 KeePass

当在 `.env`、`auth.json`、`config.yaml` 等文件中看到 `sk-cp-...j3cM`（带省略号的占位符），**不要在这些文本文件中搜索完整 key**——它们**永远只存遮蔽版本**。真实 key 在 KeePass 数据库中。

## KeePass 数据库

- **路径**: `C:\Users\dddog\Nutstore\1\keepass\Database.kdbx`
- **加密**: Windows DPAPI + 主密码 (`5201314`)
- **pykeepass 陷阱**: DPAPI 加密的数据库，pykeepass 无法直接读取（ProtectedUserKey.bin → DPAPI 不可跨进程）
- **唯一可靠方式**: `keepassxc-cli.EXE`

## keepassxc-cli 读取（正确方式）

`show -a Password` 返回**完整明文**，不被遮蔽：

```bash
KP_CLI="/c/Program Files/KeePassXC/keepassxc-cli.EXE"
KP_DB="/c/Users/dddog/Nutstore/1/keepass/Database.kdbx"
"$KP_CLI" show -a Password "$KP_DB" "/LLM-APIs/MiniMax-M2.7" <<< "5201314"
# 输出: sk-cp-xxxxxxxxxxxxxxxxxxxxxxxxj3cM（完整125字符）
```

**注意**：`show -s`（不带 `-a Password`）显示时会有遮蔽效果，提取具体字段用 `-a` 参数。

## Python 一键读取 + 注入环境变量

```python
api_key = subprocess.run(
    [kp_cli, 'show', '-a', 'Password', db, entry_path],
    capture_output=True, text=True,
    input=f'{master_password}\n', timeout=30
).stdout.strip()

# 直接注入 subprocess.Popen env，不打印，不落地文件
proc = subprocess.Popen(cmd, env={**os.environ, 'API_KEY': api_key})
```

## 常见 KeePass 条目速查

| 路径 | 内容 | 格式 |
|------|------|------|
| `/LLM-APIs/MiniMax-M2.7` | MiniMax API key | `sk-cp-...` (125 chars) |
| `/LLM-APIs/MiniMax` | MiniMax 旧条目 | `sk-cp-...` |
| `/注册 - MiniMax 开放平台` | MiniMax 平台登录密码 | — |

## 反模式（禁止）

❌ `search_files ... sk-cp-` → 浪费 5+ 次 tool call，永远找不到  
❌ 读 `auth.json` 期望完整 key → 遮蔽版  
❌ 读 `config.yaml.backup` 期望完整 key → 遮蔽版  
❌ 读 `Nutstore .env` 期望完整 key → 遮蔽版  
❌ 对用户说"key 被遮蔽了，我无法获取" → 读 KeePass 即可

## 正确流程

1. 看到 `sk-cp-...j3cM` → **立即跳转到 KeePass 读取**
2. `search` 定位条目 → `show -a Password` 提取
3. 注入环境变量启动服务，key 不落地不打印
