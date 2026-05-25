---
name: wsl
description: WSL（Windows Subsystem for Linux）完全指南 — Windows 工具互通、CDP 浏览器自动化、Python 包安装。包括 Tailscale、Chrome、OpenCLI、CDP Proxy 等配置。
tags: [wsl, windows, tailscale, chrome, snap]
---

# WSL 与 Windows 工具互通

## Tailscale（Windows 安装，WSL 调用）

Windows 已安装 Tailscale 时，WSL 无需重复安装，直接调用：

```bash
# 查看状态
/mnt/c/Program\ Files/Tailscale/tailscale.exe status

# 获取本机 IP
/mnt/c/Program\ Files/Tailscale/tailscale.exe ip -4
```

路径：`/mnt/c/Program Files/Tailscale/tailscale.exe`

## Chrome/Chromium

### 问题：WSL 中 Google Chrome GPG 密钥下载失败
症状：`curl: (35) OpenSSL SSL_connect: SSL_ERROR_SYSCALL in connection to dl.google.com:443`

原因：WSL 网络代理/防火墙问题，无法直连 Google。

### 问题：Chromium snap 安装不完整
症状：`cannot find installed snap "chromium" at revision XXXX: missing file /snap/chromium/XXXX/meta/snap.yaml`

原因：snap 安装过程中断或 WSL 兼容性问题。

**解决**：
```bash
sudo snap remove chromium
sudo snap install chromium
# 如果仍失败，使用 Windows Chrome 替代
```

### Windows Chrome 路径
```bash
/mnt/c/Program Files/Google/Chrome/Application/chrome.exe
```

### WSL 内安装 Google Chrome（snap chromium 失败时的替代方案）
updated: 2026-04-16

snap chromium 在 WSL 中经常失败（`Content snap command-chain ... not found: ensure slot is connected`），即使重装也难修复。直接装 Google Chrome .deb 更可靠：

```bash
# 1. 删掉坏的 PPA（如果有）
sudo rm /etc/apt/sources.list.d/saiarcot895-ubuntu-chromium-beta-*.sources

# 2. 下载并安装 Chrome
cd /tmp
wget -q --timeout=30 https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O chrome.deb
sudo dpkg -i chrome.deb
sudo apt-get -f -y install  # 补装依赖
```

启动（带远程调试 + WSL 兼容参数）：
```bash
google-chrome --remote-debugging-port=9222 --remote-allow-origins=* --no-sandbox --disable-gpu --user-data-dir=/tmp/chrome-debug &disown
```

验证：
```bash
curl -s http://127.0.0.1:9222/json/version
```

### 中文字体支持（WSL Chrome 渲染中文必需）
updated: 2026-04-16

WSL 内装的 Chrome 默认没有中文字体，中文页面会显示方块/乱码。安装：

```bash
sudo apt-get install -y --no-install-recommends fonts-noto-cjk fonts-wqy-zenhei
```

验证：`fc-list :lang=zh | head -3` 应输出 Noto CJK 或文泉驿字体。

### 推荐方案
- 开发/自动化：使用 Windows Chrome + OpenCLI Browser Bridge 扩展
- headless 场景：WSL 内装 Google Chrome .deb（见上方）
- 仅需截图/playwright：playwright 自带 Chromium（不依赖系统 Chrome）

## OpenCLI 安装（从源码）

```bash
cd /tmp
git clone https://github.com/jackwener/opencli.git
cd opencli
npm install  # 自动 build
sudo ln -sf /tmp/opencli/dist/src/main.js /usr/local/bin/opencli
opencli --version
```

要求：Node.js >= 21.0.0

### Browser Bridge 扩展安装
源码在 `/tmp/opencli/extension/`，复制到 Windows 桌面后手动加载：
1. Chrome → `chrome://extensions/` → 开启开发者模式
2. 「加载已解压的扩展程序」→ 选择 extension 文件夹
3. `opencli doctor` 验证连接

## Chrome 远程调试（WSL 访问 Windows Chrome）

### 问题：WSL2 无法访问 Chrome 调试端口
Chrome 在 Windows 上开启远程调试（`chrome://inspect/#remote-debugging`，端口 9222），但从 WSL2 内 `curl http://127.0.0.1:9222/json/version` 连接超时。

**根本原因**：WSL2 运行在独立 VM 中，有自己的网络命名空间。Chrome 绑定在 Windows 的 `127.0.0.1:9222`，WSL2 的 `127.0.0.1` 是 WSL 自己，不是 Windows。

**解决**：在 Windows 创建 `C:\Users\{user}\.wslconfig`：

```ini
[wsl2]
localhostForwarding=true
```

然后在 Windows PowerShell 执行 `wsl --shutdown`，重启 WSL 生效。

重启后 WSL 内 `127.0.0.1:9222` 即可访问 Windows Chrome。

### CDP Proxy 在 WSL 中的架构

Web-access skill（https://github.com/eze-is/web-access ）通过 CDP Proxy 桥接 WSL 与 Windows Chrome：

```
Hermes (WSL) → terminal + curl → CDP Proxy (WSL, port 3456) → WebSocket → Chrome (Windows, port 9222)
```

**WSL 适配要点：**

1. `cdp-proxy.mjs` 和 `check-deps.mjs` 需要 patch，为 `platform === 'linux'` 添加 WSL Chrome 路径：
   ```javascript
   const custom = process.env.CHROME_DEVTOOLS_PORT_FILE;
   if (custom) possiblePaths.push(custom);
   // 自动扫描 /mnt/c/Users/*/AppData/Local/Google/Chrome/User Data/DevToolsActivePort
   ```

2. SKILL.md 需要将 Claude Code 工具名映射为 Hermes 工具名（WebSearch→web_search, WebFetch→curl/jina_reader）。

3. Chrome DevToolsActivePort 文件路径（WSL）：
   ```bash
   /mnt/c/Users/{user}/AppData/Local/Google/Chrome/User Data/DevToolsActivePort
   ```

### 验证连接
```bash
# WSL 内测试
curl -s http://127.0.0.1:9222/json/version
# 应返回 Chrome 版本信息
```

### CDP Proxy DevToolsActivePort 冲突 Bug（WSL Chrome + Windows Chrome 同时运行）
updated: 2026-04-16

**症状**：`cdp-proxy.log` 反复输出 `连接错误: Received network error or non-101 status code`

**原因**：WSL 内和 Windows 上的 Chrome 都用了 9222 端口。CDP Proxy 的 `discoverChromePort()` 先扫描 `~/.config/google-chrome/DevToolsActivePort`，再扫描 `/mnt/c/Users/{user}/AppData/Local/Google/Chrome/User Data/DevToolsActivePort`（Windows Chrome 的文件）。如果先读到 Windows 的文件，会用 Windows Chrome 的 UUID 作为 wsPath 去连 WSL Chrome 的 9222 端口，UUID 不匹配导致连接失败。

**修复**：修改 `~/.hermes/skills/web-access/scripts/cdp-proxy.mjs`，在使用 DevToolsActivePort 的 wsPath 之前先验证连接，失败则跳过继续扫描：

```javascript
// 在 return { port, wsPath }; 之前，wsPath 非空时添加验证
if (wsPath) {
  try {
    const testWs = new WS(getWebSocketUrl(port, wsPath));
    await new Promise((resolve, reject) => {
      const timer = setTimeout(() => { testWs.close?.(); reject(new Error('timeout')); }, 3000);
      if (testWs.on) {
        testWs.on('open', () => { clearTimeout(timer); testWs.close(); resolve(); });
        testWs.on('error', (e) => { clearTimeout(timer); reject(e); });
      } else {
        testWs.addEventListener('open', () => { clearTimeout(timer); testWs.close(); resolve(); });
        testWs.addEventListener('error', (e) => { clearTimeout(timer); reject(e); });
      }
    });
  } catch (e) {
    console.log(`DevToolsActivePort wsPath 验证失败 (${p}): ${e.message}，回退到端口扫描`);
    continue; // 跳过此文件，继续下一个
  }
}
```

同时，扫描常用端口时也应从 `/json/version` 获取正确的 wsPath（而非硬编码 `/devtools/browser`）：

```javascript
// commonPorts 扫描部分，成功后获取 wsPath
const resp = await fetch(`http://127.0.0.1:${port}/json/version`);
if (resp.ok) {
  const data = await resp.json();
  const wsUrl = data.webSocketDebuggerUrl;
  if (wsUrl) {
    const match = wsUrl.match(/ws:\/\/[^/]+(\/.+)/);
    const wsPath = match ? match[1] : null;
    return { port, wsPath };
  }
}
```

## WSL 中启动 Hermes Gateway（systemctl --user 失败）
updated: 2026-04-19

**症状**：`hermes gateway start` 报 `Failed to connect to bus: No such file or directory`

**原因**：WSL 的 systemd 用户会话没有 D-Bus session bus，`systemctl --user` 不可用。

**解决**：跳过 systemd，用 nohup 直接运行：
```bash
nohup ~/.hermes/hermes-agent/venv/bin/python -m hermes_cli.main gateway run &disown
```

验证：`ps aux | grep "gateway run" | grep -v grep`

## WSL Python 包安装

WSL（尤其 Ubuntu 24.04）默认的 Python 环境可能缺少 pip，导致无法安装第三方包。

### 环境特征

| 环境 | pip | 说明 |
|------|-----|------|
| WSL 系统 Python (`/usr/bin/python3`) | ❌ 默认无 | 需手动安装 |
| WSL venv | ❌ 可能无 | `ensurepip` 可能也不可用 |
| Ubuntu 24.04 | PEP 668 | 需要 `--break-system-packages` |

### 最佳安装路径（3步）

#### 1. 先装 pip（快，小包）

```bash
sudo apt install -y python3-pip
```

#### 2. 用 pip 装目标包（快，直接下载 wheel）

```bash
/usr/bin/python3 -m pip install --break-system-packages pandas xlrd requests
```

**关键参数：**
- `--break-system-packages` — Ubuntu 24.04 (PEP 668) 必须加，否则报 externally-managed-environment
- 指定 `/usr/bin/python3` 而不是 `python3` — 避免用到 venv 的 Python

#### 3. 验证

```bash
/usr/bin/python3 -c "import pandas, xlrd, requests; print('OK')"
```

> ⚠️ pandas 导入较慢（~5-10s），验证命令建议 timeout ≥ 15s

### 踩坑记录

- ❌ **直接 apt install python3-pandas 太慢**：依赖链极长，经常超时
- ❌ **venv 中无 pip**：`python3 -m ensurepip` → No module named ensurepip。解决：不在 venv 里装，用系统 Python
- ❌ **sudo 密码交互问题**：`echo "PASSWORD" | sudo -S apt install ...`
- ⚠️ **pip install 也可能超时**：设 timeout ≥ 180s

### 核心依赖速查

| 包 | 大小 | 用途 |
|---|---|---|
| pandas | ~11MB wheel | 数据分析/Excel 读取 |
| xlrd | ~97KB wheel | 读取 .xls（旧版 Excel） |
| requests | ~50KB | HTTP 请求 |
| openpyxl | ~200KB | 读取 .xlsx（新版 Excel） |
| python-docx | ~400KB | Word 文档处理 |

## Web-Access WSL 适配（CDP 浏览器自动化）

在 WSL 中使用 web-access skill 连接 Windows Chrome，需解决 WSL2 网络隔离问题。

### 核心问题

WSL2 运行在独立 VM 中，`127.0.0.1` 是 WSL 自己的回环，不是 Windows 的。Chrome 绑定在 `127.0.0.1:9222`，WSL 默认无法访问。

### 安装步骤

#### 1. 复制 skill 文件

```bash
SKILL_DIR=~/.hermes/skills/web-access
git clone --depth 1 https://github.com/eze-is/web-access /tmp/web-access
mkdir -p $SKILL_DIR/scripts $SKILL_DIR/references/site-patterns
cp /tmp/web-access/scripts/*.mjs $SKILL_DIR/scripts/
cp /tmp/web-access/references/cdp-api.md $SKILL_DIR/references/
```

#### 2. 适配脚本（关键）

在 `check-deps.mjs` 和 `cdp-proxy.mjs` 的 `discoverChromePort()` / `activePortFiles()` 中，linux 分支加 WSL 路径扫描：

```javascript
} else if (platform === 'linux') {
  // 原有 Linux 路径...

  // WSL: 从 Windows 挂载点读取
  const custom = process.env.CHROME_DEVTOOLS_PORT_FILE;
  if (custom) possiblePaths.push(custom);

  try {
    const mntC = '/mnt/c/Users';
    if (fs.existsSync(mntC)) {
      for (const user of fs.readdirSync(mntC)) {
        const p = path.join(mntC, user, 'AppData/Local/Google/Chrome/User Data/DevToolsActivePort');
        if (fs.existsSync(p)) { possiblePaths.push(p); break; }
      }
    }
  } catch {}
}
```

#### 3. 解决 WSL2 localhost 隔离

**创建 `C:\Users\<用户名>\.wslconfig`：**

```ini
[wsl2]
localhostForwarding=true
```

**必须执行 `wsl --shutdown` 后重启 WSL 才生效。**

#### 4. Chrome 远程调试

用户在 Windows Chrome 中：
1. `chrome://inspect/#remote-debugging`
2. 勾选 "Allow remote debugging for this browser instance"
3. 重启 Chrome

#### 5. 验证

```bash
node ~/.hermes/skills/web-access/scripts/check-deps.mjs
```

预期：`node: ok`, `chrome: ok (port 9222)`, `proxy: ready`

### 故障排查

| 症状 | 原因 | 解决 |
|------|------|------|
| `chrome: not connected` | Chrome 未开调试 | chrome://inspect 勾选 Allow |
| `curl localhost:9222` 超时 | WSL2 localhost 隔离 | 加 `.wslconfig` 的 `localhostForwarding=true` |
| DevToolsActivePort 找不到 | WSL 看不到 Windows 文件 | 设 `CHROME_DEVTOOLS_PORT_FILE` 环境变量 |
| proxy 反复报 `non-101 status code` | WSL Chrome + Windows Chrome 同用 9222，UUID 冲突 | 见 CDP Proxy DevToolsActivePort 冲突修复章节 |

### DevToolsActivePort UUID 冲突修复（WSL 内装 Chrome 时）

WSL 内 Chrome 和 Windows Chrome 都监听 9222 时，CDP Proxy 从 Windows 的 DevToolsActivePort 读到错误的 wsPath UUID。

**修复 `cdp-proxy.mjs`**：验证 wsPath 可用再使用：

```javascript
if (wsPath) {
  try {
    const testWs = new WS(getWebSocketUrl(port, wsPath));
    await new Promise((resolve, reject) => {
      const timer = setTimeout(() => { testWs.close?.(); reject(new Error('timeout')); }, 3000);
      testWs.on('open', () => { clearTimeout(timer); testWs.close(); resolve(); });
      testWs.on('error', (e) => { clearTimeout(timer); reject(e); });
    });
  } catch (e) {
    console.log(`wsPath 验证失败 (${p}): ${e.message}，回退到端口扫描`);
    continue;
  }
}
```

同时扫描端口时从 `/json/version` 获取正确 wsPath：

```javascript
const resp = await fetch(`http://127.0.0.1:${port}/json/version`);
const match = (await resp.json()).webSocketDebuggerUrl?.match(/ws:\/\/[^\/]+(\/.+)/);
return { port, wsPath: match ? match[1] : null };
```

### 与 Hermes 原生工具的分工

| 场景 | 工具 |
|------|------|
| 搜索 | web_search |
| 公开网页提取 | jina_reader / curl |
| 简单浏览（无登录） | browser_navigate + browser_snapshot |
| **登录态/反爬/交互** | **CDP Proxy (localhost:3456)** |

## 常见 WSL 路径映射

| Windows | WSL |
|---------|-----|
| `C:\Users\{user}\` | `/mnt/c/Users/{user}/` |
| Chrome | `/mnt/c/Program Files/Google/Chrome/Application/chrome.exe` |
| Tailscale | `/mnt/c/Program Files/Tailscale/tailscale.exe` |

## SSH 密钥认证（WSL 到远程主机）
updated: 2026-04-21

从 WSL 远程管理其他机器时，密码认证不方便（ssh-askpass 缺失），Tailscale SSH 需要浏览器交互。最佳方案是 ed25519 密钥认证。

### 部署公钥到远程 Windows（管理员用户）

Windows OpenSSH 管理员用户的 authorized_keys 位置不同于普通用户。管理员要写到 C:\ProgramData\ssh\administrators_authorized_keys 而非用户 .ssh 目录。原因：sshd_config 中 Match Group administrators 覆盖了默认路径。

### 部署公钥到远程 WSL

通过 Windows SSH 中转 WSL 命令，用 wsl -e bash -c 执行。

### Tailscale SSH 的限制

Tailscale SSH 使用浏览器认证，不支持密码认证和 sshpass。密钥部署成功后可绕过。

## Python 从 UNC 路径运行的坑
updated: 2026-04-21

从 WSL 的 UNC 路径运行 Python+Pygame 时，pygame.font.SysFont 会因字体枚举异常崩溃（TypeError: expected str, bytes or os.PathLike object, not int）。解决：用 pygame.font.Font 直接加载字体文件（如 C:\Windows\Fonts\msyh.ttc），绕过 SysFont。
