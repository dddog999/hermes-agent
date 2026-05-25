# Web Access
> Absorbed from archived skill `web-access` during 2026-05-22 consolidation pass.

---


# web-access Skill (Hermes 适配版)

## 前置检查

在开始联网操作前，先检查 CDP 模式可用性：

```bash
node ~/.hermes/skills/web-access/scripts/check-deps.mjs
```

未通过时引导用户完成设置：
- **Node.js 22+**：已满足（WSL 环境）
- **Chrome remote-debugging**：在 Chrome 地址栏打开 `chrome://inspect/#remote-debugging`，勾选 **"Allow remote debugging for this browser instance"**，然后重启 Chrome

检查通过后并必须在回复中向用户直接展示以下须知，再启动 CDP Proxy 执行操作：

```
温馨提示：部分站点对浏览器自动化操作检测严格，存在账号封禁风险。已内置防护措施但无法完全避免，Agent 继续操作即视为接受。
```

## Windows Chrome 控制方案选择（优先级顺序）

遇到需要 Windows Chrome 登录态的任务时，按以下顺序尝试：

### ① OpenCLI Browser Bridge Extension（最优先）
OpenCLI 扩展已在 Windows Chrome 中运行，通过 daemon `localhost:19825` 与 WSL 通信。
```bash
# 检查状态
opencli doctor
# 期望输出：Extension: connected, Daemon: running

# 打开页面
opencli browser open "https://music.163.com/#/song?id=xxx"
# 获取页面状态（渲染后 HTML 结构）
opencli browser state
# 执行 JS 并获取返回值
opencli browser eval "document.title"
# 滚动触发懒加载
opencli browser scroll down
# 截图
opencli browser screenshot /tmp/shot.png
```

**优势**：无需开启 Chrome remote debugging port，天然携带 Windows Chrome 登录态，已安装即用。
**局限**：不是真实 CDP，只能读写 DOM，不能拦截请求/响应。

### ② CDP Proxy via Chrome Remote Debugging（次选）
通过 Chrome remote debugging port (9222) 连接 Windows Chrome，提供完整 CDP 能力。
- 需要 Windows Chrome 开启 `--remote-debugging-port=9222`
- WSL 通过 `http://100.117.8.69:9222`（Windows 主机 IP）连接
- 见下方「CDP Proxy 模式」章节

### ③ WSL 独立 Chrome（兜底）
WSL 内运行独立 Chrome 实例，登录态在 `/tmp/chrome-debug/`（重启丢失）。
- 见下方「方案 A：WSL 内运行 Chrome」

**判断规则**：先试 ①，失败或不满足需求再试 ②，② 也不可用再试 ③。

## 浏览哲学

**像人一样思考，兼顾高效与适应性的完成任务。**

执行任务时不会过度依赖固有印象所规划的步骤，而是带着目标进入，边看边判断，遇到阻碍就解决，发现内容不够就深入——全程围绕「我要达成什么」做决策。这个 skill 的所有行为都应遵循这个逻辑。

**① 拿到请求** — 先明确用户要做什么，定义成功标准：什么算完成了？需要获取什么信息、执行什么操作、达到什么结果？这是后续所有判断的锚点。

**② 选择起点** — 根据任务性质、平台特征、达成条件，选一个最可能直达的方式作为第一步去验证。一次成功当然最好；不成功则在③中调整。比如，需要操作页面、需要登录态、已知静态方式不可达的平台（小红书、微信公众号等）→ 直接 CDP

**③ 过程校验** — 每一步的结果都是证据，不只是成功或失败的二元信号。用结果对照①的成功标准，更新你对目标的判断：路径在推进吗？结果的整体面貌（质量、相关度、量级）是否指向目标可达？发现方向错了立即调整，不在同一个方式上反复重试——搜索没命中不等于"还没找对方法"，也可能是"目标不存在"；API 报错、页面缺少预期元素、重试无改善，都是在告诉你该重新评估方向。遇到弹窗、登录墙等障碍，判断它是否真的挡住了目标：挡住了就处理，没挡住就绕过——内容可能已在页面 DOM 中，交互只是展示手段。

**④ 完成判断** — 对照定义的任务成功标准，确认任务完成后才停止，但也不要过度操作，不为了"完整"而浪费代价。

## 联网工具选择

- **确保信息的真实性，一手信息优于二手信息**：搜索引擎和聚合平台是信息发现入口。当多次搜索尝试后没有质的改进时，升级到更根本的获取方式：定位一手来源（官网、官方平台、原始页面）。

| 场景 | Hermes 工具 |
|------|------------|
| 搜索摘要或关键词结果，发现信息来源 | **web_search** |
| URL 已知，需要从页面定向提取特定信息 | **terminal** + `curl` 或 **jina_reader**（将网页转 Markdown，省 token） |
| URL 已知，需要原始 HTML 源码（meta、JSON-LD 等结构化字段） | **terminal** + `curl -s URL` |
| 非公开内容，或已知静态层无效的平台（小红书、微信公众号等公开内容也被反爬限制） | **CDP Proxy**（直接浏览器，跳过静态层） |
| 需要登录态、交互操作，或需要像人一样在浏览器内自由导航探索 | **CDP Proxy** |
| 简单页面浏览、不需要登录态 | **browser_navigate** + **browser_snapshot**（Browserbase 云浏览器） |

CDP Proxy 不要求 URL 已知——可从任意入口出发，通过页面内搜索、点击、跳转等方式找到目标内容。web_search、curl、jina_reader 均不处理登录态。

**Firecrawl**（网页搜索与提取）：官方 API endpoint `https://api.firecrawl.dev/v1/search`，认证 `Authorization: Bearer {key}`。
- 请求体格式（2026-05 实测）：`{"query": "搜索词"}`，不支持 `pageOptions` 等额外字段
- 响应格式：`{"success": true, "data": [...]}`，data 直接是结果列表，每项含 `url`, `title`, `description`
- 适用场景：需要从目标网站全文内容时先用 `/v1/search` 发现 URL，再对每个 URL 发 `/v1/scrape` 提取正文

**Jina**（可选预处理层，可与 curl 组合使用）：第三方网络服务，可将网页转为 Markdown，大幅节省 token 但可能有信息损耗。调用方式为 `curl -s "https://r.jina.ai/example.com"`（URL 前加前缀 r.jina.ai/，不保留原网址 http 前缀），限 20 RPM。适合文章、博客、文档、PDF 等以正文为核心的页面；对数据面板、商品页等非文章结构页面可能提取到错误区块。

## CDP Proxy 模式

通过 CDP Proxy 直连用户 Windows Chrome，天然携带登录态，无需启动独立浏览器。
若无用户明确要求，不操作用户已有 tab，所有操作都在自己创建的后台 tab 中进行，保持对用户环境的最小侵入。不关闭用户 tab 的前提下，完成任务后关闭自己创建的 tab，保持环境整洁。

### 启动 Proxy

```bash
node ~/.hermes/skills/web-access/scripts/check-deps.mjs
```

脚本会依次检查 Node.js、Chrome 端口，并确保 Proxy 已连接（未运行则自动启动并等待）。Proxy 启动后持续运行。

### 通过 terminal 工具调用 Proxy API

CDP Proxy 运行在 `localhost:3456`，通过 **terminal** 工具用 curl 调用：

```bash
# 列出用户已打开的 tab
curl -s http://localhost:3456/targets

# 创建新后台 tab（自动等待加载）
curl -s "http://localhost:3456/new?url=https://example.com"

# 页面信息
curl -s "http://localhost:3456/info?target=ID"

# 执行任意 JS：可读写 DOM、提取数据、操控元素、触发状态变更、提交表单、调用内部方法
curl -s -X POST "http://localhost:3456/eval?target=ID" -d 'document.title'

# 捕获页面渲染状态（含视频当前帧）
curl -s "http://localhost:3456/screenshot?target=ID&file=/tmp/shot.png"

# 导航、后退
curl -s "http://localhost:3456/navigate?target=ID&url=URL"
curl -s "http://localhost:3456/back?target=ID"

# 点击（POST body 为 CSS 选择器）— JS el.click()，简单快速，覆盖大多数场景
curl -s -X POST "http://localhost:3456/click?target=ID" -d 'button.submit'

# 真实鼠标点击 — CDP Input.dispatchMouseEvent，算用户手势，能触发文件对话框
curl -s -X POST "http://localhost:3456/clickAt?target=ID" -d 'button.upload'

# 文件上传 — 直接设置 file input 的本地文件路径，绕过文件对话框
curl -s -X POST "http://localhost:3456/setFiles?target=ID" -d '{"selector":"input[type=file]","files":["/path/to/file.png"]}'

# 滚动（触发懒加载）
curl -s "http://localhost:3456/scroll?target=ID&y=3000"
curl -s "http://localhost:3456/scroll?target=ID&direction=bottom"

# 关闭 tab
curl -s "http://localhost:3456/close?target=ID"
```

### 页面内导航

两种方式打开页面内的链接：

- **`/click`**：在当前 tab 内直接点击用户视角中的可交互单元，简单直接，串行处理。适合需要在同一页面内连续操作的场景，如点击展开、翻页、进入详情等。
- **`/new` + 完整 URL**：使用目标链接的完整地址（包含所有URL参数），在新 tab 中打开。适合需要同时访问多个页面的场景。

很多网站的链接包含会话相关的参数（如 token），这些参数是正常访问所必需的。提取 URL 时应保留完整地址，不要裁剪或省略参数。

### 媒体资源提取

判断内容在图片里时，用 `/eval` 从 DOM 直接拿图片 URL，再定向读取——比全页截图精准得多。

### 技术事实
- 页面中存在大量已加载但未展示的内容——轮播中非当前帧的图片、折叠区块的文字、懒加载占位元素等，它们存在于 DOM 中但对用户不可见。以数据结构（容器、属性、节点关系）为单位思考，可以直接触达这些内容。
- DOM 中存在选择器不可跨越的边界（Shadow DOM 的 `shadowRoot`、iframe 的 `contentDocument`等）。eval 递归遍历可一次穿透所有层级，返回带标签的结构化内容，适合快速了解未知页面的完整结构。
- `/scroll` 到底部会触发懒加载，使未进入视口的图片完成加载。提取图片 URL 前若未滚动，部分图片可能尚未加载。
- 拿到媒体资源 URL 后，公开资源可直接下载到本地后用读取；需要登录态才可获取的资源才需要在浏览器内 navigate + screenshot。
- 短时间内密集打开大量页面（如批量 `/new`）可能触发网站的反爬风控。
- 平台返回的"内容不存在""页面不见了"等提示不一定反映真实状态，也可能是访问方式的问题（如 URL 缺失必要参数、触发反爬）而非内容本身的问题。

### 视频内容获取

用户 Chrome 真实渲染，截图可捕获当前视频帧。核心能力：通过 `/eval` 操控 `<video>` 元素（获取时长、seek 到任意时间点、播放/暂停/全屏），配合 `/screenshot` 采帧，可对视频内容进行离散采样分析。

### 登录判断

用户日常 Chrome 天然携带登录态，大多数常用网站已登录。

登录判断的核心问题只有一个：**目标内容拿到了吗？**

打开页面后先尝试获取目标内容。只有当确认**目标内容无法获取**且判断登录能解决时，才告知用户：
> "当前页面在未登录状态下无法获取[具体内容]，请在你的 Chrome 中登录 [网站名]，完成后告诉我继续。"

登录完成后无需重启任何东西，直接刷新页面继续。

### 任务结束

用 `/close` 关闭自己创建的 tab，必须保留用户原有的 tab 不受影响。

Proxy 持续运行，不建议主动停止——重启后需要在 Chrome 中重新授权 CDP 连接。

## 并行调研：子 Agent 分治策略

任务包含多个**独立**调研目标时（如同时调研 N 个项目、N 个来源），鼓励合理分治给子 Agent 并行执行，而非主 Agent 串行处理。

**好处：**
- **速度**：多子 Agent 并行，总耗时约等于单个子任务时长
- **上下文保护**：抓取内容不进入主 Agent 上下文，主 Agent 只接收摘要，节省 token

**并行 CDP 操作**：每个子 Agent 在当前用户浏览器实例中，自行创建所需的后台 tab（`/new`），自行操作，任务结束自行关闭（`/close`）。所有子 Agent 共享一个 Chrome、一个 Proxy，通过不同 targetId 操作不同 tab，无竞态风险。

**子 Agent Prompt 写法：目标导向，而非步骤指令**
- 必须在子 Agent prompt 中写 `必须加载 web-access skill 并遵循指引` ，子 Agent 会自动加载 skill，无需在 prompt 中复制 skill 内容或指定路径。
- 子 Agent 有自主判断能力。主 Agent 的职责是说清楚**要什么**，仅在必要与确信时限定**怎么做**。过度指定步骤会剥夺子 Agent 的判断空间，反而引入主 Agent 的假设错误。**避免 prompt 用词对子 Agent 行为的暗示**：「搜索xx」会把子 Agent 锚定到 WebSearch，而实际上有些反爬站点需要 CDP 直接访问主站才能有效获取内容。主 Agent 写 prompt 时应描述目标（「获取」「调研」「了解」），避免用暗示具体手段的动词（「搜索」「抓取」「爬取」）。

**分治判断标准：**

| 适合分治 | 不适合分治 |
|----------|-----------|
| 目标相互独立，结果互不依赖 | 目标有依赖关系，下一个需要上一个的结果 |
| 每个子任务量足够大（多页抓取、多轮搜索） | 简单单页查询，分治开销大于收益 |
| 需要 CDP 浏览器或长时间运行的任务 | 几次 web_search / curl 就能完成的轻量查询 |

## 信息核实类任务

核实的目标是**一手来源**，而非更多的二手报道。多个媒体引用同一个错误会造成循环印证假象。

搜索引擎和聚合平台是信息发现入口，是**定位**信息的工具，不可用于直接**证明**真伪。找到来源后，直接访问读取原文。同一原则适用于工具能力/用法的调研——官方文档是一手来源，不确定时先查文档或源码，不猜测。

| 信息类型 | 一手来源 |
|----------|---------|
| 政策/法规 | 发布机构官网 |
| 企业公告 | 公司官方新闻页 |
| 学术声明 | 原始论文/机构官网 |
| 工具能力/用法 | 官方文档、源码 |

**找不到官网时**：权威媒体的原创报道（非转载）可作为次级依据，但需向用户说明："未找到官方原文，以下核实来自[媒体名]报道，存在转述误差可能。"单一来源时同样向用户声明。

## 站点经验

操作中积累的特定网站经验，按域名存储在 `~/.hermes/skills/web-access/references/site-patterns/` 下。

确定目标网站后，如果前置检查输出的 site-patterns 列表中有匹配的站点，必须读取对应文件获取先验知识（平台特征、有效模式、已知陷阱）。经验内容标注了发现日期，当作可能有效的提示而非保证——如果按经验操作失败，回退通用模式并更新经验文件。

CDP 操作成功完成后，如果发现了有必要记录经验的新站点或新模式（URL 结构、平台特征、操作策略），主动写入对应的站点经验文件。只写经过验证的事实，不写未确认的猜测。

文件格式：
```markdown
---
domain: example.com
aliases: [示例, Example]
updated: 2026-04-15
---
## 平台特征
架构、反爬行为、登录需求、内容加载方式等事实

## 有效模式
已验证的 URL 模式、操作策略、选择器

## 已知陷阱
什么会失败以及为什么
```
经验/陷阱内容标注发现日期，当作"可能有效的提示"而非"保证正确的事实"。

## WSL 环境说明

Hermes 运行在 WSL 中，Chrome 可以运行在 Windows 上（复用登录态）或 WSL 内（独立实例）。

### 方案 A：WSL 内运行 Chrome（推荐，不干扰 Windows Chrome）

**安装 Google Chrome .deb**（snap chromium 在 WSL 中不可靠）：

```bash
# 删掉坏的 PPA（如果有）
sudo rm /etc/apt/sources.list.d/saiarcot895-ubuntu-chromium-beta-*.sources

# 下载安装
cd /tmp
wget -q --timeout=30 https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O chrome.deb
sudo dpkg -i chrome.deb
sudo apt-get -f -y install  # 补装依赖
```

**安装中文字体**（中文页面显示方块时）：
```bash
sudo apt-get install -y --no-install-recommends fonts-noto-cjk fonts-wqy-zenhei
```

**启动 Chrome**：
```bash
google-chrome --remote-debugging-port=9222 --remote-allow-origins=* --no-sandbox --disable-gpu --user-data-dir=/tmp/chrome-debug &disown
```

**验证**：
```bash
curl -s http://127.0.0.1:9222/json/version
```

**关键参数说明**：
- `--remote-allow-origins=*`：跳过 WebSocket 授权弹窗
- `--no-sandbox`：WSL 内必须
- `--user-data-dir=/tmp/chrome-debug`：隔离用户数据，不影响其他 Chrome 实例

### 方案 B：连接 Windows Chrome（复用登录态）

1. 打开 `chrome://inspect/#remote-debugging`
2. 勾选 "Allow remote debugging for this browser instance"
3. 重启 Chrome

### 环境变量（可选）

如果自动检测不到 Chrome，可设置：
```bash
export CHROME_DEVTOOLS_PORT_FILE="/mnt/c/Users/<Windows用户名>/AppData/Local/Google/Chrome/User Data/DevToolsActivePort"
```

### CDP Proxy DevToolsActivePort 冲突 Bug（WSL Chrome + Windows Chrome 同时运行）

**症状**：`cdp-proxy.log` 反复输出 `连接错误: Received network error or non-101 status code`

**原因**：WSL 内和 Windows 上的 Chrome 都用了 9222 端口。CDP Proxy 的 `discoverChromePort()` 读到 `/mnt/c/Users/{user}/AppData/.../DevToolsActivePort`（Windows Chrome 的文件），用 Windows Chrome 的 UUID 作为 wsPath 去连 WSL Chrome 的 9222 端口，UUID 不匹配导致连接失败。

**修复**（已应用到 `scripts/cdp-proxy.mjs`）：
1. DevToolsActivePort 路径的 wsPath 使用前先验证连接，失败则 `continue` 跳到下一个文件
2. 扫描常用端口时从 `/json/version` 获取正确的 `webSocketDebuggerUrl` 而非硬编码路径

如果重新安装 web-access skill 需要重新应用此修复。

### 验证连接
```bash
# 检查完整流程
node ~/.hermes/skills/web-access/scripts/check-deps.mjs
# 应输出: node: ok, chrome: ok, proxy: ready
```

## References 索引

| 文件 | 何时加载 |
|------|---------|
| `references/cdp-api.md` | 需要 CDP API 详细参考、JS 提取模式、错误处理时 |
| `references/site-patterns/{domain}.md` | 确定目标网站后，读取对应站点经验 |
