---
name: web-content-extraction
description: Web access orchestration and content extraction. Covers tool selection, anti-bot bypass patterns, CDP proxy, retrieval cascades, social media scraping, and paywall/captcha handling. Load when you need to decide which web-access tool to use, navigate browser-automation, or implement extraction code.
user-invocable: true
---

# Web Content Extraction

This umbrella covers two complementary skill areas:

| Concern | Sibling skill | Load when |
|---------|--------------|-----------|
| **Web access orchestration** | `web-access` | Choosing whether to use CDP proxy, `browser_navigate`, curl, jina-reader, or another path; browser automation and CDP Proxy usage |
| **Scraping patterns & anti-bot cascade** | `web-scraping` | Picking a technique for the current URL, or writing extraction code: trafilatura, BeautifulSoup, Playwright+stealth, yt-dlp, instaloader |

---

## 1. Web Access Orchestration

> Absorbed from `web-access` (2025-05). Full reference content: `references/web-access.md`.

### Tool Choice

| Goal | Recommended path |
|------|-----------------|
| Simple URL → page text | `curl URL` or `jina_reader` |
| JS-rendered, no login | `browser_navigate` + `browser_snapshot` |
| JS-rendered + login state | CDP Proxy (`localhost:3456`) |
| Multi-step / multi-tab interaction | CDP Proxy or Playwright script |
| Social media / video | `yt-dlp`, `instaloader` |
| Undocumented API endpoint | DevTools → cURL → curlconverter |
| Raw HTML (meta, JSON-LD) | `curl -s URL` |

### CDP Proxy Reference (reference-only)

| Command | Purpose |
|---------|---------|
| `GET /health` | Health check |
| `GET /targets` | List open tabs (targetId + title + url) |
| `GET /new?url=URL` | Create formatted new tab, auto-wait load |
| `GET /navigate?target=ID&url=URL` | Navigate tab |
| `GET /eval?target=ID` | Evaluate JS |
| `POST /eval?target=ID` | JS stdin |
| `GET /click?target=ID&selector=CSS` | Simple JS `el.click()` |
| `POST /clickAt?target=ID` | True mouse event |
| `GET /screenshot?target=ID` | Render current frame |
| `GET /info?target=ID` | Page metadata (title, URL, readyState) |
| `GET /har?target=ID` | Network HAR |
| `GET /getFrames?target=ID` | Flatten all frames |
| `GET /setFiles?target=ID` | File input upload bypass |
| `GET /scroll?target=ID&y=px` | Scroll and trigger lazy-load |

### Windows Chrome Access Priority

Always prefer OpenCLI bridge (localhost:19825) for Windows Chrome login-state pass-through, then CDP Proxy, then WSL Chrome.

### Sub-Agent Delegation

Delegate only to sub-agents when:
- Goals are **independent** (no data dependency between sub-tasks)
- Each sub-task is **large enough** to justify parallel dispatch
- The task **needs a browser** or is otherwise long-running

Write goal-oriented, not step-by-step, prompts. Execute concurrent tasks via full context + structured output from each branch.

### Web Data Audit

Before deploying a new agent into production, run a snapshot audit on the target — count extracted items per domain (Total, Visible, Parseable, Visible/Total Ratio). Document domains <50% coverage or with near-20% no-targets and replace missing instruction instead.

### Session Failures and Recovery

Common failure patterns to watch for:
- "No valid screenshot targetId found" or "getRuntimeError: Error evaluating JS" → session corrupted; restart session and try again; use `chrome-reload-async rough` or `sessionresumed`
- "Strategy does not work without a reliable success check" → the strategy cannot determine success reliably; re-check option completeness after each checkpoint
- "Empty optional chain read when targetId is missing" → session likely closed; verify target exists before executing commands

---

## 2. Scraping Patterns & Anti-Bot Cascade

> Absorbed from `web-scraping`. Full reference content: `references/web-scraping.md`.

### Scraping Cascade Architecture

```python
class ScrapingCascade:
    def __init__(self):
        self.scrapers = [
            TrafilaturaScraper(),          # Fast, lightweight, HTTP-only
            RequestsScraper(),             # HTTP + BS4, rotating UAs
            PlaywrightScraper(),           # Full JS rendering + stealth
        ]
    def fetch(self, url):
        for s in self.scrapers:
            result = s.fetch(url)
            if result: return result
        return None
```

### Scraper Types

| Scraper | When to use |
|---------|-------------|
| **Trafilatura** | Standard article pages; keep focused, fast, lightweight (output: `text` or `json` format) |
| **Requests + BeautifulSoup** | No-JS sites; HTML parsing; rotating UAs + polite delays |
| **Playwright + playwright_stealth** | JS-heavy, anti-bot protected, paywalled, lazy-rendered content |
| **Async Playwright** | Jupyter notebooks, concurrent collections via `asyncio.gather` |
| **yt-dlp** | YouTube / TikTok / Instagram (native, mediated extraction) |
| **instaloader** | Instagram profiles, hashtags, reels |

### Anti-Bot Evasion

| Technique | Purpose |
|-----------|---------|
| Rotating User-Agent | Reduce fingerprinting |
| Rate limiting `sleep(1–3s)` between same-domain requests | Prevent triggering rate limits / bans |
| playwright-stealth.stealth_sync | Bypass headless browser detection |
| CapSolver / S2S for complex anti-bot challenges | Solve complex challenges with managed services |
| Lazy-load triggering (`/page.scroll`) before extraction | Get lazy-loaded media that won't appear auto |

### Poison Pill Detection

```python
class PoisonPillResult:
    detected: bool
    type: PoisonPillType  # PAYWALL | CAPTCHA | RATE_LIMIT | CLOUDFLARE | LOGIN_REQUIRED | NOT_FOUND
    confidence: float
```

Detect paywalls per-domain (nytimes.com, wsj.com, washingtonpost.com, ft.com, bloomberg.com), classify by: `status_code` (429/403/404 first), then `PAYWALL_DOMAINS` list, then regex matching on content. classify as partial / poisons / neutral result in cascading re-scrape.

### YT-DLP and Instaloader Integration

```python
# YouTube transcript extraction, preferred media format
import yt_dlp
ydl_opts = {
    'skip_download': True, 'quiet': True,
    'writesubtitles': True, 'writeautomaticsub': True,
    'subtitleslangs': ['zh-CN', 'en'],
}

# Instagram profile scraping
import instaloader
L = instaloader.Instaloader(download_videos=True, save_metadata=True)
profile = instaloader.Profile.from_username(L.context, username)
for post in profile.get_posts():       # iterate_posts() with limit
```

---

## 3. Choosing the Right Path

```
Goal?
│
├─ Need a real browser (login, JS-rendered, anti-bot hard)
│  └─ CDP Proxy (localhost:3456) or browser_navigate + browser_snapshot
│     ├─ Windows login-state available → OpenCLI ①, fallback CDP Proxy ②, fallback WSL Chrome ③
│     └─ Stateless page → trafilatura / requests + BS4
│
├─ Simple page, no JS needed
│  └─ curl / jina-reader
│
├─ Social media / video
│  └─ yt-dlp / instaloader
│
├─ Large / multi-page collection
│  └─ Trafilatura cascade (trafilatura → BS4 → Playwright)
│
└─ Undocumented API
   └─ DevTools cURL → curlconverter → strip cookies → implement minimal request
```

## Absorbed Reference Files

| 文件 | 来源 Skill | 主题 |
|------|-----------|------|
| `references/cdp-api.md` | `browser-use` (archived) | Chrome DevTools Protocol 完整 API |
| `references/web-access.md` | `web-access` (archived) | lw world-rule engine, curl/Bash, carriage-return injection, WSL↔Windows bridge |
| `references/web-scraping.md` | `web-scraping` (archived) | BeautifulSoup/trafilatura/Playwright/Scrapy 逐元素选型 |
| `references/jina-reader.md` | `jina-reader` (archived) | Jina AI Reader API (read/search/ground), CSS extraction, proxy, WSL pitfall |
| `references/scrapling-official.md` | `scrapling-official` (archived) | Scrapling Python 库 (anti-bot, stealthy, spider framework, JSON extraction) |

