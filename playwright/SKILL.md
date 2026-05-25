---
name: playwright
description: Browser automation via Playwright MCP for testing, screenshots, web scraping, and form filling. Use when users need to navigate websites, extract data, test web apps, or automate browser workflows.
license: MIT
compatibility: Requires npx and Playwright MCP server
metadata:
  author: oh-my-opencode-team
  version: "1.0.0"
  category: browser-automation
---

# Playwright Browser Automation

## When to use this skill

Use this skill when the user asks to:
- Navigate to a website or URL
- Take screenshots of web pages
- Extract data from websites
- Fill out forms on web pages
- Test web application functionality
- Automate browser workflows
- Scrape information from the web

## Capabilities

This skill provides browser automation via the Playwright MCP server:
- Page navigation and interaction
- Screenshot capture (full page or element)
- Data extraction from web pages
- Form filling and submission
- Element clicking and interaction
- Network request interception
- Mobile device emulation

## Setup

The Playwright MCP server is required:

```bash
npx @playwright/mcp@latest
```

## Usage Examples

### Navigate to a website
```
Navigate to https://example.com and take a screenshot
```

### Extract data
```
Extract all product titles from https://shop.example.com/products
```

### Fill a form
```
Fill out the contact form on https://example.com/contact with name "John" and email "john@example.com"
```

### Test functionality
```
Test the login functionality on https://app.example.com/login
```

## Best Practices

1. **Wait for page load**: Always ensure pages are fully loaded before interacting
2. **Use selectors wisely**: Prefer data-testid or aria-label over CSS classes
3. **Handle dynamic content**: Wait for elements to appear before interacting
4. **Clean up**: Close browser contexts when done
5. **Respect rate limits**: Add delays between requests when scraping

## Error Handling

Common issues and solutions:
- **Timeout**: Increase wait time for slow-loading pages
- **Element not found**: Check if element is in iframe or shadow DOM
- **Navigation failed**: Verify URL and network connectivity
