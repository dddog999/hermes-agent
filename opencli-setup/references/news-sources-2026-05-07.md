# OpenCLI 新闻/资讯平台 — 2026-05-07 新增

## 已验证可用的新闻命令

| 平台 | 命令 | 格式建议 | 登录 |
|------|------|---------|------|
| Hacker News | `opencli hackernews top --limit 5 --format md` | md/table | 否 |
| Google News | `opencli google news --limit 8 --format md` | md/table | 否 |
| 36氪 | `opencli 36kr news --limit 5 --format md` | md/table | 否 |
| 雪球 | `opencli xueqiu hot` | json | 否 |
| 微博 | `opencli weibo hot` | json | Chrome已登录 |

## 快速用法

```bash
# 汇总多个新闻源
opencli hackernews top --limit 5 --format md
opencli google news --limit 8 --format md
opencli 36kr news --limit 5 --format md
```

## 发现途径
- `opencli list | grep -iE 'news|hacker|36kr'` 快速筛选新闻类命令
- opencli 支持 57+ 平台的搜索/热门/订阅源
