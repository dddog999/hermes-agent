---
name: opencli
description: |
  操作任意网站+写可复用adapter的end-to-end工具。用Chrome扩展桥接驱动真实浏览器，
  支持登录态、自动化操作、页面提取。daemon运行在19825端口，session名"my"。
  当任务涉及：操作登录态网站/填写表单/批量提取数据/绕过CSP-POST时使用。
category: browser-automation
---

# OpenCLI 完全手册

> 来源：jackwener/opencli GitHub + 5个skills + browser-cli.md + 2026-04实测
> 更新：2026-05-23

## 核心架构

```
用户请求 → opencli daemon (19825) → Chrome扩展桥接 → 真实Chrome浏览器
CLI工具(node main.js) → 调用daemon API → 操作浏览器
```

**两种使用方式**：
1. **Hermes web工具**：直接用web_scan/web_execute_js（已集成daemon）
2. **Terminal CLI**：`node main.js <cmd>` 或 `npx opencli <cmd>`（需PATH）

### 当前环境状态
- daemon在线 ✅，session="my"，版本v1.7.22
- Chrome已打开，扩展已连接
- Node v25.8.1：CLI静默退出（CSPRNG断言），但daemon+浏览器操作正常

---

## 一、浏览器命令（web工具）

### 核心命令
| 命令 | 说明 |
|------|------|
| `open <url>` | 打开URL |
| `click <selector>` | 点击元素（先find定位） |
| `type <selector> <text>` | 输入文本 |
| `fill <form>` | 填表单 |
| `select <selector> <value>` | 下拉选择 |
| `keys <keys>` | 发送快捷键 |
| `wait <ms/selector>` | 等待 |
| `get <selector>` | 获取文本/属性 |
| `find <selector>` | 查找元素 |

### 高级命令
| 命令 | 说明 |
|------|------|
| `extract <selector>` | 批量提取数据 |
| `eval <js>` | 执行JS（WSL下不可用） |
| `network` | 捕获网络请求 |
| `screenshot` | 截图 |
| `scroll` | 滚动 |
| `back` | 后退 |
| `frames` | iframe操作 |
| `verify <selector>` | 验证元素存在 |

### 标签页命令
```
tab list     - 列出所有标签
tab new      - 新建标签
tab select <id> - 切换标签
tab close    - 关闭当前标签
```

### 使用示例
```javascript
// 打开网站
open https://example.com
// 等待页面加载
wait 2000
// 点击按钮
click button.submit
// 输入文本
type input[name="email"] user@example.com
// 提取数据
extract tr.item > td
// 截图
screenshot
```

---

## 二、CLI命令（Terminal）

### 基础命令
```bash
opencli --version          # 查看版本
opencli doctor             # 检查扩展连接状态
opencli list               # 列出所有可用平台
opencli list | grep search # 查看搜索命令
```

### 平台命令
```bash
opencli <platform> <cmd>   # 通用格式
opencli <platform> --help  # 查看平台具体帮助
```

### 输出格式
```bash
--format table   # 表格（默认）
--format json    # JSON（脚本处理首选）
--format yaml    # YAML
--format plain   # 纯文本
--format md      # Markdown
```

### 搜索命令（57+平台）
```bash
# 通用搜索
opencli google search "关键词" --limit 10 --lang zh
opencli wikipedia search "Python" --limit 5

# 中文平台
opencli zhihu search "问题" --limit 5
opencli bilibili search "视频" --limit 5
opencli xiaohongshu search "笔记" --limit 5
opencli douban search "电影" --limit 5

# 社交/新闻
opencli hackernews show --limit 20
opencli twitter search "关键词"
opencli reddit search "programming" --limit 5

# 购物/生活
opencli taobao search "商品名"
opencli jd search "商品名"
opencli gitee search "项目名"
# 注意：opencli 没有 github 命令，用 gitee search 替代 GitHub 项目搜索
opencli stackoverflow search "python error" --limit 5

# 学术
opencli arxiv search "关键词" --limit 3
opencli arxiv recent cs.CL --limit 10  # 按分类浏览最新论文
```

---

## 三、Adapter（可复用脚本）

### 基本结构
```javascript
// adapter 文件放在 adapters/ 目录
module.exports = {
  title: 'MyAdapter',
  description: 'What it does',
  intent: 'user intent description',
  parameters: [
    { name: 'query', type: 'string', required: true }
  ],
  // adapter 函数
  async execute(params, context) {
    // params.query 等参数
    // context.open() context.click() context.type() 等API
    return { result: 'data' }
  }
}
```

### Adapter示例（知乎搜索）
```javascript
module.exports = {
  title: 'zhihu-search',
  intent: 'Search Zhihu for topics',
  parameters: [
    { name: 'keyword', type: 'string', required: true },
    { name: 'limit', type: 'number', default: 10 }
  ],
  async execute({ keyword, limit }, { open, click, type, wait, extract }) {
    await open('https://www.zhihu.com')
    await wait(1000)
    await type('.Searchbox-input', keyword)
    await click('.Searchbox-searchButton')
    await wait(2000)
    const results = await extract('.List-item', {
      title: '.RichText',
      link: 'a::href'
    })
    return results.slice(0, limit)
  }
}
```

### 运行Adapter
```bash
opencli run adapters/zhihu-search.js --keyword "AI"
```

---

## 四、故障排查

### 扩展未连接
```bash
opencli doctor
# 检查Chrome开着+扩展启用+重启Chrome
```

### 批量验证登录平台流程
1. `opencli doctor` 确认连接
2. 每批3个站点测试（Chrome中）
3. 先测`hot/list`（可能不需登录），再测`search`
4. 全部可用后开下一批

### 首次调用异常（Twitter/Facebook/Reddit）
首次超时或返回空 → 用户确认Chrome已登录 → 重试
= Chrome扩展桥接session同步延迟，非登录故障

### 知乎搜索已知问题
部分单中文词（如"新能源"）返回空，组合词或英文词正常
= 站内搜索索引问题，非登录故障

### WSL不要用Playwright navigate
opencli cookie命令依赖Chrome扩展桥接，不是Playwright
WSL中用：`/mnt/c/Program Files/Google/Chrome/Application/chrome.exe "https://example.com"`

### 即刻超时
1. 确认Chrome页面加载完成
2. `opencli doctor` 确认扩展连接
3. `OPENCLI_DIAGNOSTIC=1 opencli jike feed` 诊断
4. 可能是WebSocket与Chrome扩展不兼容

### linux-do 429限流
hot/feed不受影响，search易触发
间隔30s+再试，或用`opencli linux-do feed --view top --period daily`替代

---

## 五、平台实测状态（2026-04-15）

### 资讯/新闻 ✅
| 平台 | 热门/list | 搜索 | 备注 |
|------|-----------|------|------|
| 雪球 | ✅ | ✅ | 无需登录 |
| 微博 | ✅ | ✅ | |
| 知乎 | ✅ | ⚠️ | 单中文词索引问题 |
| B站 | ✅ | ✅ | |
| 路透社 | — | ✅ | 仅搜索 |
| Medium | — | ✅ | 仅搜索 |
| linux-do | ✅ | ⚠️ | 搜索触发429 |
| 贴吧 | ✅ | ✅ | |
| 新浪财经 | ✅ | — | 无需登录 |

### 社交媒体
| 平台 | 热门/list | 搜索 | 备注 |
|------|-----------|------|------|
| Twitter | — | ✅ | 需登录，首次可能超时 |
| Facebook | — | ✅ | 需登录，首次可能空 |
| Reddit | — | ✅ | 需登录，首次可能空 |

### 购物/生活
| 平台 | 热门/list | 搜索 | 备注 |
|------|-----------|------|------|
| 小红书 | — | ✅ | 需登录，AUTH_REQUIRED需cookie |
| 什么值得买 | — | ✅ | 无需登录 |
| 豆瓣 | — | ✅ | 无需登录 |

### AI对话平台
| 平台 | 说明 |
|------|------|
| 豆包 | 中文互联网、生态、生活方式 |
| 元宝 | 中文热点、泛中文问答 |
| Gemini | 全球网页、英文资料 |

---

## 六、每日数据收集工作流（Automated Collection）

用于定时任务（cron job）中的自动化数据采集，输出 ClawMem 兼容的 markdown 文件。

### 核心模式

```bash
# 每条命令设 14-20s 超时，JSON 输出便于脚本处理
opencli <platform> <cmd> [args] --limit N -f json
```

参考脚本：`/home/dddog/.hermes/scripts/daily-rag-memory-collect.py`

### 已验证的数据源命令

| 源 | 命令 | 速度 | 需登录 | 备注 |
|----|------|------|-------|------|
| arXiv 近期 | `arxiv recent cs.CL/AI/LG/IR --limit 25 -f json` | ⚡ | 否 | 按分类浏览 |
| arXiv 搜索 | `arxiv search "关键词" --limit 20 -f json` | ⚡ | 否 | 补全用 |
| Gitee 项目 | `gitee search "关键词" --limit 8 -f json` | ⚡ | 否 | 替代 GitHub 搜索 |
| DuckDuckGo 新闻 | `duckduckgo search "关键词" --limit 10 -f json` | ⚡ | 否 | 含 title/url/snippet |
| Hacker News | `hackernews show --limit 60 -f json` | ⚡ | 否 | 非 search/top |
| 知乎搜索 | `zhihu search "关键词" --limit 3 -f json` | 🐌 | 是 | 需登录否则超时 |

### 注意：不存在这些命令
- ~~`hackernews search`~~ / ~~`hackernews top`~~ → 用 `hackernews show`
- ~~`github search`~~ → 用 `gitee search` 或 gh CLI
- ~~`google news`~~ → 用 `duckduckgo search`

### 输出格式（ClawMem 兼容）

```yaml
---
title: 完整标题
date: 2026-05-23
source: arXiv
type: paper
tags:
  - rag
  - arxiv
url: https://arxiv.org/abs/xxxx.xxxxx
l2_sources: hermes:daily-rag-collect
---
```

### 去重策略
1. 同线程：`SEEN set` 按 url（去尾部 `/`）或 title 去重
2. 同分类：arXiv 跨分类用 arxiv_id 构造的 url 去重
3. 跨天：文件名含日期，天然不覆盖

### 超时策略
每条命令设 14s subprocess timeout，整体脚本总 timeout 建议 180s。
arXiv/Gitee/DDG 一般 5-10s 返回；知乎超时风险高。

### 过滤策略
- **arXiv**：按 title 关键词过滤（不查 abstract）
- **Gitee**：星星数 < 1 且 desc 不含 rag/memory/agent/llm 的项目跳过
- **HN**：title 含关键词，Show HN 中仅少量相关
- **DDG**：每查询最多取 6 条，URL 本地去重

### 注意事项
- arXiv `recent` 按 arXiv 首页分组排列，非严格时间排序
- HN `show` 批量取多条时部分 fetch 报 `fetch failed` 但 JSON 完整
- Gitee 主要面向国内开源，GitHub 原生项目覆盖率低
- `l2_sources` 固定为 `hermes:daily-rag-collect`
- 知乎需要 Chrome 已登录+扩展已连接，否则稳定超时

---

## 七、快速参考

### 常用命令速查
```bash
# 检查连接
opencli doctor

# 查看所有平台
opencli list

# 搜索示例
opencli google search "问题" --limit 5
opencli zhihu search "AI发展" --limit 10

# 数据收集（参见「每日数据收集工作流」）
opencli arxiv recent cs.CL --limit 10 -f json
opencli hackernews show --limit 20 -f json
opencli duckduckgo search "RAG" --limit 5 -f json
opencli gitee search "RAG" --limit 5 -f json

# 运行adapter
opencli run adapters/my-adapter.js --param value
```

### 浏览器操作示例
```javascript
// 完整流程
open https://zhihu.com
wait 2000
click .zu-top-search-input
type .zu-top-search-input "人工智能"
keys Enter
wait 3000
extract .List-item > .item-link
```

### AI查询词建议
构造成"主题 + 目标 + 限定条件"：
- 主题：用户真正要查的对象、产品、技术
- 目标：需要什么信息
- 限定条件：时间、地区、语言等

---

## Notes

- **推荐优先使用**：用户偏好直接用opencli查询问题
- **登录态**：保存在浏览器profile中，Chrome重启后保持
- **daemon端口**：19825
- **CLI vs web工具**：daemon稳定，CLI在Node v25.8.1有CSPRNG断言问题但不影响web工具
- **Chrome扩展**：必须安装并保持连接状态才能使用browser bridge
