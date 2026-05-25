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

#### DuckDuckGo
- Use `https://html.duckduckgo.com/html/?q={keyword}` (HTML version)
- Add `&kl=cn` for Chinese queries
- Minimum delay: 2-3 seconds
- Risk: Medium for general search, High for advanced operators

#### Google
- Currently blocked in most regions
- Use `Google HK` as fallback
- Risk: Very High (avoid automated requests)

#### Bing
- Good balance of results and accessibility
- Use `Bing CN` for Chinese content
- Risk: Low to Medium

#### Brave
- Independent index, no Google dependency
- Supports time filters: `&tf=pw`, `&tf=pm`
- Privacy-focused, less aggressive bot detection
- Risk: Low

#### Startpage
- Returns Google results via proxy
- Privacy engine, no tracking
- Risk: Medium

#### Qwant
- EU-based, GDPR compliant
- Clean results, EU content bias
- Risk: Low

### 6. Fallback Strategy

Implement a multi-engine fallback strategy:

```javascript
const SEARCH_ENGINES = [
  { name: 'Baidu', url: base => `https://www.baidu.com/s?wd=${encodeURIComponent(base)}`, risk: 'low' },
  { name: 'Bing CN', url: base => `https://cn.bing.com/search?q=${encodeURIComponent(base)}`, risk: 'low' },
  { name: 'Brave', url: base => `https://search.brave.com/search?q=${encodeURIComponent(base)}`, risk: 'low' },
  { name: 'DuckDuckGo', url: base => `https://html.duckduckgo.com/html/?q=${encodeURIComponent(base)}&kl=cn`, risk: 'medium' },
  { name: '360', url: base => `https://www.so.com/s?q=${encodeURIComponent(base)}`, risk: 'low' },
];

async function robustSearch(keyword, maxResults = 3) {
  const results = [];
  for (const engine of SEARCH_ENGINES) {
    try {
      const url = engine.url(keyword);
      const result = await searchWithDelay(engine.name, url);
      if (result && isValidSearchResult(result)) {
        results.push({engine: engine.name, result});
        if (results.length >= maxResults) break;
      }
    } catch (error) {
      console.log(`⚠️ ${engine.name} failed:`, error.message);
      continue;
    }
  }
  return results;
}

function isValidSearchResult(content) {
  const CAPTCHA_PATTERNS = [
    /verify you are human/i,
    /captcha/i,
    /robot verification/i,
    /too many requests/i,
    /rate limit/i,
    /access denied/i,
    /checking your browser/i,
  ];
  const text = content.toString().toLowerCase();
  return !CAPTCHA_PATTERNS.some(pattern => pattern.test(text));
}
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

### Summary: Best Practices Checklist

✅ **Always:**
- Use rotating User-Agent strings
- Add random delays (2-5s minimum for DDG)
- Use the most specific search engine
- Detect CAPTCHA patterns in responses
- Have fallback engines ready

❌ **Avoid:**
- Burst requests (< 1 second apart)
- Using advanced operators on privacy engines
- Pure English queries (use Chinese engines)
- Ignoring rate limits

🔄 **Recommended Flow:**
1. Try Baidu/Bing CN for Chinese queries
2. Use Brave for international queries
3. Fallback to DuckDuckGo only if needed
4. Switch to browser automation if web_fetch fails 3 times

---

## Documentation

- `references/advanced-search.md` - Domestic search guide
- `references/international-search.md` - International search guide
- `CHANGELOG.md` - Version history

## License

MIT
