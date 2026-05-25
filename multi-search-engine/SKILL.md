---
name: "multi-search-engine"
description: "Multi search engine integration with 17 engines (8 CN + 9 Global). Supports advanced search operators, time filters, site search, privacy engines, and WolframAlpha knowledge queries. No API keys required."
---

# Multi Search Engine v2.0.1

Integration of 17 search engines for web crawling without API keys.

## Search Engines

### Domestic (8)
- **Baidu**: `https://www.baidu.com/s?wd={keyword}`
- **Bing CN**: `https://cn.bing.com/search?q={keyword}&ensearch=0`
- **Bing INT**: `https://cn.bing.com/search?q={keyword}&ensearch=1`
- **360**: `https://www.so.com/s?q={keyword}`
- **Sogou**: `https://sogou.com/web?query={keyword}`
- **WeChat**: `https://wx.sogou.com/weixin?type=2&query={keyword}`
- **Toutiao**: `https://so.toutiao.com/search?keyword={keyword}`
- **Jisilu**: `https://www.jisilu.cn/explore/?keyword={keyword}`

### International (9)
- **Google**: `https://www.google.com/search?q={keyword}`
- **Google HK**: `https://www.google.com.hk/search?q={keyword}`
- **DuckDuckGo**: `https://html.duckduckgo.com/html/?q={keyword}`
- **Yahoo**: `https://search.yahoo.com/search?p={keyword}`
- **Startpage**: `https://www.startpage.com/sp/search?query={keyword}`
- **Brave**: `https://search.brave.com/search?q={keyword}`
- **Ecosia**: `https://www.ecosia.org/search?q={keyword}`
- **Qwant**: `https://www.qwant.com/?q={keyword}`
- **WolframAlpha**: `https://www.wolframalpha.com/input?i={keyword}`

## Quick Examples

```javascript
// Basic search
web_fetch({"url": "https://www.google.com/search?q=python+tutorial"})

// Site-specific
web_fetch({"url": "https://www.google.com/search?q=site:github.com+react"})

// File type
web_fetch({"url": "https://www.google.com/search?q=machine+learning+filetype:pdf"})

// Time filter (past week)
web_fetch({"url": "https://www.google.com/search?q=ai+news&tbs=qdr:w"})

// Privacy search
web_fetch({"url": "https://html.duckduckgo.com/html/?q=privacy+tools"})

// DuckDuckGo Bangs
web_fetch({"url": "https://html.duckduckgo.com/html/?q=!gh+tensorflow"})

// Knowledge calculation
web_fetch({"url": "https://www.wolframalpha.com/input?i=100+USD+to+CNY"})
```

## Advanced Operators

| Operator | Example | Description |
|----------|---------|-------------|
| `site:` | `site:github.com python` | Search within site |
| `filetype:` | `filetype:pdf report` | Specific file type |
| `""` | `"machine learning"` | Exact match |
| `-` | `python -snake` | Exclude term |
| `OR` | `cat OR dog` | Either term |

## Time Filters

| Parameter | Description |
|-----------|-------------|
| `tbs=qdr:h` | Past hour |
| `tbs=qdr:d` | Past day |
| `tbs=qdr:w` | Past week |
| `tbs=qdr:m` | Past month |
| `tbs=qdr:y` | Past year |

## Privacy Engines

- **DuckDuckGo**: No tracking
- **Startpage**: Google results + privacy
- **Brave**: Independent index
- **Qwant**: EU GDPR compliant

## Bangs Shortcuts (DuckDuckGo)

| Bang | Destination |
|------|-------------|
| `!g` | Google |
| `!gh` | GitHub |
| `!so` | Stack Overflow |
| `!w` | Wikipedia |
| `!yt` | YouTube |

## WolframAlpha Queries

- Math: `integrate x^2 dx`
- Conversion: `100 USD to CNY`
- Stocks: `AAPL stock`
- Weather: `weather in Beijing`

---

## 🔧 Search Optimization Techniques

Search engines can detect automated requests and trigger CAPTCHA verification. This section provides best practices to minimize blocking and improve success rates.

### Why CAPTCHA Triggers Occur

| Trigger | Description | Risk Level |
|---------|-------------|------------|
| High request frequency | Too many requests from same IP | High |
| Advanced operators | Using `site:`, `filetype:`, etc. | Medium |
| Cross-region queries | IP mismatch with search language | Medium |
| Missing browser headers | Default tool headers | Medium |
| Headless browsing | Detable headless patterns | High |

### 1. Rotating User Agents

Use real browser User-Agent strings and rotate them randomly:

```javascript
const USER_AGENTS = [
  // Chrome Windows
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
  // Chrome macOS
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
  // Firefox Windows
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:132.0) Gecko/20100101 Firefox/132.0',
  // Safari macos
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15',
];

function getRandomUA() {
  return USER_AGENTS[Math.floor(Math.random() * USER_AGENTS.length)];
}
```

### 2. Request Delays

Add random delays between requests (especially for DuckDuckGo):

```javascript
function delay(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function searchWithDelay(engineName, url) {
  // Random delay between 2-5 seconds for DuckDuckGo
  const delayMs = engineName === 'DuckDuckGo'
    ? Math.random() * 3000 + 2000
    : Math.random() * 1000 + 500;

  await delay(delayMs);
  return web_fetch({url});
}

// Batch search with staggered delays
async function batchSearch(urls) {
  const results = [];
  for (let i = 0; i < urls.length; i++) {
    const {engine, url} = urls[i];
    const result = await searchWithDelay(engine, url);
    results.push({engine, result});
    // Extra delay between different engines
    if (i < urls.length - 1) {
      await delay(1000);
    }
  }
  return results;
}
```

### 3. Realistic Headers

Simulate real browser requests with complete headers:

```javascript
function getSearchHeaders() {
  return {
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.5',
    'Accept-Encoding': 'gzip, deflate, br',
    'DNT': '1',
    'Connection': 'keep-alive',
    'Upgrade-Insecure-Requests': '1',
    'Sec-Fetch-Dest': 'document',
    'Sec-Fetch-Mode': 'navigate',
    'Sec-Fetch-Site': 'none',
    'Sec-Fetch-User': '?1',
    'Cache-Control': 'max-age=0',
  };
}
```

**Note**: The `web_fetch` tool may not support custom headers. Check your CodeBuddy version for header support. If not supported, consider using the `browser-use` or `agent-browser` skills.

### 4. Avoid CAPTCHA Hotspots

The following search patterns are more likely to trigger CAPTCHA on DuckDuckGo:

| Pattern | Example | Recommendation |
|---------|---------|----------------|
| Currency conversion | `10 USD to CNY` | Use WolframAlpha |
| Site-specific searches | `site:github.com python` | Use Google/Bing |
| Pure English queries | `machine learning` | Add language context |
| Bangs shortcuts | `!gh tensorflow` | Use direct URLs |
| Math calculations | `derivative of x^2` | Use WolframAlpha |

### 5. Engine-Specific Guidelines

**⚠️ 2026-04实测：国内搜索引擎（Baidu/Sogou/360）curl 全量 CAPTCHA 拦截，Bing CN 仅在 Browserbase 云浏览器下可用。**

#### Baidu / Sogou / 360
- curl/终端访问 → 强制 CAPTCHA 验证，**不可用**
- 中文查询唯一可用途径：Browserbase 云浏览器（browser_navigate）
- Risk: **High** (curl blocked, browser required)

#### Bing CN
- curl 直接访问 → 大概率返回空结果或重定向到首页
- Browserbase 云浏览器 → **可用**，对中文查询友好，搜索结果丰富
- Risk: **Medium** (needs cloud browser)

#### DuckDuckGo
- `https://html.duckduckgo.com/html/?q={keyword}` (HTML version)
- `&kl=cn` 中文查询可能触发 CAPTCHA 或超时
- 间歇性可用，不做为主要依赖
- Risk: Medium-High

#### Google / Google HK
- 目前大部分地区被拦截
- Risk: Very High (避免自动化请求)

#### Brave
- 独立索引，不依赖 Google
- 中文内容覆盖有限
- Risk: Low-Medium

#### Startpage
- 返回 Google 结果（通过代理）
- 中文内容有限
- Risk: Medium

#### Qwant
- EU-based, GDPR compliant
- 中文内容极少
- Risk: Low

### 6. Fallback Strategy

**2026-04 实测结论：中文搜索 curl 全面不可用，Browserbase 云浏览器是唯一可靠途径。**

```javascript
// ⚠️ 中文查询实际可用引擎（curl 全部阵亡）
const CN_SEARCH_REALITY = {
  'Baidu':     { curl: 'BLOCKED', browser: 'BLOCKED (CAPTCHA)', usable: false },
  'Sogou':     { curl: 'BLOCKED', browser: '?', usable: false },
  '360':       { curl: 'BLOCKED', browser: '?', usable: false },
  'Bing CN':   { curl: 'EMPTY_REDIRECT', browser: 'OK (Browserbase)', usable: true },
  'DuckDuckGo':{ curl: 'TIMEOUT/CAPTCHA', browser: '?', usable: false },
  'Brave':     { curl: '67chars empty', usable: false },
};

// 中文查询推荐流程：
// 1. browser_navigate → cn.bing.com → type + Enter → snapshot（首选）
// 2. 如 Bing 返回无关结果，换关键词重试
// 3. 如仍不可用，依赖模型训练知识 + Bing 摘要交叉验证
```

### 7. Detect and Handle CAPTCHA

```javascript
function detectCAPTCHA(content) {
  const patterns = [
    /captcha/i,
    /verify you are human/i,
    /prove you're not a robot/i,
    /请验证 you are human/i,
    /人机验证/i,
    /too many requests/i,
    /rate limit exceeded/i,
  ];

  const text = content.toString().toLowerCase();
  for (const pattern of patterns) {
    if (pattern.test(text)) {
      return { detected: true, type: 'CAPTCHA', pattern };
    }
  }
  return {detected: false};
}

async function safeSearch(engine, url, maxRetries = 3) {
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    const result = await searchWithDelay(engine, url);
    const captcha = detectCAPTCHA(result);

    if (captcha.detected) {
      if (attempt < maxRetries) {
        const waitTime = attempt * 5;  // 5s, 10s, 15s
        console.log(`⚠️ CAPTCHA detected on ${engine}, waiting ${waitTime}s before retry...`);
        await delay(waitTime * 1000);
        continue;
      } else {
        throw new Error(`CAPTCHA after ${maxRetries} attempts. Try different engine or browser automation.`);
      }
    }

    return result;
  }
}
```

### 8. When to Use Browser Automation

If `web_fetch` fails consistently, switch to real browser automation:

- **agent-browser**: CLI-based browser control
- **browser-use**: AI agent browser automation
- **playwright**: Programmatic control

Example using `agent-browser`:

```bash
agent-browser --headed open about:blank
agent-browser open "https://html.duckduckgo.com/html/?q=python+tutorial"
agent-browser wait --load networkidle
agent-browser get text body > results.txt
agent-browser close
```

### Summary: Best Practices Checklist（2026-04 实测）

✅ **Always:**
- 中文搜索优先用 Browserbase 云浏览器（browser_navigate → cn.bing.com）
- 英文搜索用 Brave 或 DuckDuckGo HTML
- 识别响应的 CAPTCHA 特征码并立即切换策略
- 考虑模型训练知识是否已足够回答，避免无谓搜索

❌ **Avoid:**
- curl 访问 Baidu/Sogou/360（全量 CAPTCHA，100% 失败）
- 短时间内多次搜索同一引擎
- 在中文信息检索上花费超过 5 次工具调用仍无结果时继续死磕
- 忽略模型自身训练知识——对常识/公开信息可直接回答，无需搜索验证

🔄 **Recommended Flow（2026-04 实测更新）:**

**中文查询：**
1. **首选**：Browserbase 云浏览器 → `cn.bing.com` → 输入关键词搜索 → snapshot 提取结果
2. **备选**：如 Bing 无相关结果 → 依赖模型训练知识回答 + 声明信息来源
3. **不推荐**：curl 访问任何国内搜索引擎（Baidu/Sogou/360 全量 CAPTCHA）

**英文查询：**
1. Brave Search → 独立索引，反爬宽松
2. DuckDuckGo HTML → 间歇性可用
3. Browserbase Google 作为最后手段

---

## Documentation

- `references/advanced-search.md` - Domestic search guide
- `references/international-search.md` - International search guide
- `CHANGELOG.md` - Version history

## License

MIT
