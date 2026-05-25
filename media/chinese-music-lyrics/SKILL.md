---
name: chinese-music-lyrics
description: Retrieve full lyrics from Chinese music platforms (网易云音乐/QQ音乐/酷狗) via API when browser UI fails. Includes known song ID references.
tags: [lyrics, chinese-music, netease, api, scraping]
version: 1.0.0
---

# Chinese Music Lyrics Retrieval

Retrieve full lyrics from Chinese music platforms (网易云音乐/QQ音乐/酷狗) when browser UI only shows metadata or truncated content.

## Trigger

Use when:
- Browser shows "很抱歉，未能找到相关搜索结果" or partial metadata for Chinese songs
- User wants lyrics for Chinese anime/game/ost songs
- Search results on the platform itself are incomplete or require login

## Core Technique: Netease Cloud Music API

When the web UI fails, use the Netease Cloud Music internal API directly:

```bash
curl -s "https://music.163.com/api/song/lyric?id={SONG_ID}&lv=1&kv=1&tv=1" \
  -H "Referer: https://music.163.com"
```

The response is JSON with `lrc.lyric` containing the full lyrics with timestamp tags like `[00:12.34]`.

### Parsing (Python one-liner):

```bash
curl -s "https://music.163.com/api/song/lyric?id=2013399069&lv=1&kv=1&tv=1" \
  -H "Referer: https://music.163.com" \
  | python3 -c "
import sys, json, re
data = json.load(sys.stdin)
lyrics = data.get('lrc', {}).get('lyric', '')
for line in lyrics.split('\n'):
    text = re.sub(r'\[.*?\]', '', line).strip()
    if text:
        print(text)
"
```

Or save to file:
```bash
curl -s "https://music.163.com/api/song/lyric?id=2013399069&lv=1&kv=1&tv=1" \
  -H "Referer: https://music.163.com" \
  -o lyrics_raw.json
```

### Finding Song IDs

When ID is unknown, search via API:

```bash
curl -s "https://music.163.com/api/search/get" \
  -d "s={QUERY}&type=1&limit=10" \
  -H "Referer: https://music.163.com" \
  | python3 -c "
import sys, json
data = json.load(sys.stdin)
for song in data.get('result', {}).get('songs', [])[:10]:
    artists = [a.get('name') for a in song.get('artists', [])]
    print(f\"ID: {song.get('id')}, Name: {song.get('name')}, Artist: {artists}\")
"
```

## Song ID Reference

Known IDs for 《如果历史是一群喵》OSTs:

| Song | Season | ID | Notes |
|------|--------|-----|-------|
| 纷扰 | 第3季 | 1859368226 | 三国篇 |
| 主宰 | 第6季 | 1859368227 | 两晋南北朝 |
| 惊鸿 | 第7季 | 2013399685 | |
| 长恨 | 第8季 | 2013399069 | 需要API才能获取完整歌词 |
| 无悔 | 第9季 | 2013399683 | |
| 梦华 | 第10季 | 2101734175 | |
| 天骄 | 第11季 | 2716028823 | |
| 日月 | 第12季 | 2728511539 | Carmen卡萌酱版本；TV版2727768230暂无歌词 |

## Platform Quirks

### 网易云音乐 (Netease Cloud Music)
- Web player often requires login to see full lyrics
- API endpoint works without auth: `/api/song/lyric?id={id}&lv=1&kv=1&tv=1`
- `lv=1` = with translation (if available), `tv=1` = unescaped
- Works for most songs, but some newer releases have no lyrics in API

### QQ音乐 / 酷狗
- Less reliable APIs; prefer Netease when both available
- Try browser network tab inspection for direct lyric URLs

## Documentation Format

For anime/game OST documentation (参考《如果历史是一群喵》格式):

```
# 《歌名》— 诗词注释

> - **歌名：** 
> - **原唱：** RS纾律
> - **作词：** 冥凰
> - **作曲：** litterzy
> - **备注：** 所属季/篇信息

---

## 完整歌词

> (歌词正文，每段用 > 引用块)

---

## 诗词典故详解

| 歌词 | 诗词/典故引用 | 出处/解释 |
|------|--------------|----------|
...

## 主题分析

(历史背景、典故解读、歌曲主题)
```

## Common Pitfalls

1. **Browser shows no lyrics**: Don't waste time with the web UI → use API immediately
2. **API returns empty lrc**: Song may have no submitted lyrics, or uses different ID
3. **Wrong song ID**: Some IDs return wrong songs → verify with song name in search API
4. **lyric field missing entirely**: Try adding `tv=1` parameter, or the song has no lyrics data

## Verification

After getting lyrics, verify:
- [ ] Song title matches expected ID
- [ ] Lyrics are complete (not truncated mid-song)
- [ ] Timestamps `[mm:ss.xx]` are present (can strip them)

## Sources

- Netease Cloud Music API: reverse-engineered from web player network traffic
- Song IDs verified via search API and song detail endpoints
