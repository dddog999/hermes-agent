---
name: browser-harness
description: browser-harness (github.com/browser-use/browser-harness) 浏览器自动化工具。使用Chrome远程调试连接Windows Chrome，复用已登录session。适用于需要完整浏览器交互的财务系统自动化等任务。
---

# browser-harness

browser-harness 是一个通过 CDP (Chrome DevTools Protocol) 连接 Chrome 的轻量级工具，与 agent-browser 是不同的工具。

## 安装位置
- GitHub: https://github.com/browser-use/browser-harness.git
- WSL 安装: `git clone && cd browser-harness && uv tool install -e .`
- 命令: `browser-harness` (不是 `agent-browser`)

## 连接已登录的 Chrome (Windows)

### 步骤1: Windows 上启动 Chrome
```powershell
chrome.exe --remote-debugging-port=9222
```

或手动打开 `chrome://inspect/#remote-debugging`，勾选 "Allow remote debugging for this browser instance"。

### 步骤2: 验证连接
```bash
browser-harness --doctor
```

### 步骤3: 使用 browser-harness
```bash
browser-harness -c 'print(page_info())'
browser-harness -c 'goto("https://www.zsszpt.cn/tdlz_ht/ncgl.do?sysno=11")'
```

## Session 持久化
登录成功后保存 session：
```bash
browser-harness state save <session_name>
```
后续直接加载：
```bash
browser-harness state load <session_name>
```

## 故障排除
- `browser-harness --doctor` 查看 daemon 和 Chrome 状态
- Chrome 144+ 每次 attach 首次会弹出 "Allow remote debugging" 确认框
- Windows Chrome 默认路径在 `%LOCALAPPDATA%\Google\Chrome\User Data`

## WSL 2 环境特别说明

**关键陷阱：WSL 2 网络隔离**
- WSL 2 使用虚拟化网络，**无法直接访问 Windows localhost:9222**
- Windows → WSL 方向可以（localhost 转发），但 WSL → Windows 不行
- `curl http://127.0.0.1:9222/json/version` 在 WSL 中会连接失败

**正确的 Chrome 启动方式（在 WSL 中用 pwsh）：**
```bash
# 1. 完全关闭 Chrome（已有实例会忽略启动参数）
powershell.exe "Stop-Process -Name chrome -Force"

# 2. 用完整路径启动（Chrome 可能不在 PATH 中）
powershell.exe "Start-Process 'C:\Program Files\Google\Chrome\Application\chrome.exe' -ArgumentList '--remote-debugging-port=9222','--user-data-dir=C:\temp\chrome-debug'"
```

**网络连通解决方案（选一种）：**

方案A：netsh 端口转发（需要 Windows 管理员权限，一次性设置）
```powershell
# 在 Windows 管理员 PowerShell 中运行
netsh interface portproxy add v4tov4 listenport=9222 listenaddress=0.0.0.0 connectport=9222 connectaddress=127.0.0.1
```
之后在 WSL 中用 Tailscale IP 连接：
```bash
export WINDOWS_IP=$(powershell.exe "tailscale ip -4" | tr -d '\r')
curl http://$WINDOWS_IP:9222/json/version
```

方案B：SSH 隧道（需要 Tailscale SSH）
```bash
ssh -N -f -L 9223:localhost:9222 kangle@$WINDOWS_IP
export BU_CDP_WS="ws://localhost:9223/devtools/browser/..."
```

**验证步骤：**
```bash
# 在 WSL 中，先确认 Windows Chrome 已启动
powershell.exe "netstat -an | Select-String ':9222'"

# 再测试连通性（需要方案A或B已配置）
curl -s http://$WINDOWS_IP:9222/json/version
```

## 与 agent-browser 的区别
| 工具 | 来源 | 用途 |
|------|------|------|
| agent-browser | npm 包 | Playwright-based CLI |
| browser-harness | GitHub repo | CDP-based，连接真实 Chrome |
