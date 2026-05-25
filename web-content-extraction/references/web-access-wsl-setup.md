# web-access-wsl-setup

> Absorbed from `web-access-wsl-setup` during web-content-extraction umbrella consolidation.

---

# Web-Access Skill WSL 适配指南

在 WSL 中使用 web-access skill 连接 Windows Chrome，需解决 WSL2 网络隔离问题。

## 核心问题

WSL2 运行在独立 VM 中，`127.0.0.1` 是 WSL 自己的回环，不是 Windows 的。Chrome 绑定在 `127.0.0.1:9222`，WSL 默认无法访问。

## 安装步骤

### 1. 复制 skill 文件

```bash
SKILL_DIR=~/.hermes/skills/web-access
git clone --depth 1 https://github.com/eze-is/web-access /tmp/web-access
mkdir -p $SKILL_DIR/scripts $SKILL_DIR/references/site-patterns
cp /tmp/web-access/scripts/*.mjs $SKILL_DIR/scripts/
cp /tmp/web-access/references/cdp-api.md $SKILL_DIR/references/
```

### 2. 适配脚本（关键）

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

### 3. 解决 WSL2 localhost 隔离

**创建 `C:\Users\<用户名>\.wslconfig`：**

```ini
[wsl2]
localhostForwarding=true
```

**必须执行 `wsl --shutdown` 后重启 WSL 才生效。**

### 4. Chrome 远程调试

用户在 Windows Chrome 中：
1. `chrome://inspect/#remote-debugging`
2. 勾选 "Allow remote debugging for this browser instance"
3. 重启 Chrome

### 5. 验证

```bash
node ~/.hermes/skills/web-access/scripts/check-deps.mjs
```

预期：`node: ok`, `chrome: ok (port 9222)`, `proxy: ready`

## 故障排查

| 症状 | 原因 | 解决 |
|------|------|------|
| `chrome: not connected` | Chrome 未开调试 | chrome://inspect 勾选 Allow |
| `curl localhost:9222` 超时 | WSL2 localhost 隔离 | 加 `.wslconfig` 的 `localhostForwarding=true` |
| DevToolsActivePort 找不到 | WSL 看不到 Windows 文件 | 设 `CHROME_DEVTOOLS_PORT_FILE` 环境变量 |
| proxy 反复报 `non-101 status code` | WSL Chrome + Windows Chrome 同用 9222，UUID 冲突 | 见下方修复 |

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
const match = (await resp.json()).webSocketDebuggerUrl?.match(/ws:\/\/[^/]+(\/.+)/);
return { port, wsPath: match ? match[1] : null };
```

### WSL 内装 Google Chrome（snap chromium 失败时）

```bash
cd /tmp && wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O chrome.deb
sudo dpkg -i chrome.deb && sudo apt-get -f -y install
google-chrome --remote-debugging-port=9222 --remote-allow-origins=* --no-sandbox --disable-gpu --user-data-dir=/tmp/chrome-debug &disown
# 中文字体
sudo apt-get install -y --no-install-recommends fonts-noto-cjk fonts-wqy-zenhei
```

## 与 Hermes 原生工具的分工

| 场景 | 工具 |
|------|------|
| 搜索 | web_search |
| 公开网页提取 | jina_reader / curl |
| 简单浏览（无登录） | browser_navigate + browser_snapshot |
| **登录态/反爬/交互** | **CDP Proxy (localhost:3456)** |
