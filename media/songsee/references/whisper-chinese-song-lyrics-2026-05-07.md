# Whisper 中文歌词转写 — 经验总结 2026-05-07

## 背景
任务：验证《如果历史是一群喵》第12季OP《日月》歌词是否完整（现有20行 vs B站视频3:38长度）

## 工具链

| 工具 | 用途 | 状态 |
|------|------|------|
| `faster-whisper` (hermes venv) | 音频转文字 | ✅ 可用 |
| `ffmpeg volumedetect` | 音量分析各时间段 | ✅ 快速判断有人声/空白 |
| yt-dlp + `--cookies-from-browser chrome` | 下载B站音频/视频 | ✅ 成功 |
| B站字幕API (`api.bilibili.com/x/web-interface/subtitle`) | 官方字幕 | ❌ 需登录 |

## Whisper 模型对比（中文歌曲转写）

| 模型 | 质量 | 耗时 | 适用场景 |
|------|------|------|---------|
| base | ❌ garbled，连读完全错 | ~26s | 不推荐 |
| small | ⚠️ 较差，大量错漏 | ~32s | 最低可用 |
| **medium** | ⚠️ 仍有错，但可辨认轮廓 | ~70s | **推荐中文歌曲** |

## 关键发现

### 1. Whisper medium 对这首歌仍然garbled
- 《日月》语速快、连读多、背景音乐强，即使 medium 模型也无法完整准确转写
- **教训**：Whisper 对"歌词快歌"的转写质量有限，需结合其他方法验证

### 2. 音量分析是好的中间步骤
```bash
# 每5秒一个片段检测音量，快速判断哪些时间段有人声
for start in $(seq 0 5 220); do
  ffmpeg -y -ss $start -t 5 -i audio.m4a \
    -af volumedetect -f null - 2>&1 | grep mean_volume
done
```

### 3. B站字幕需要登录
```bash
yt-dlp --cookies-from-browser chrome --write-subs ... 
# → "Subtitles are only available when logged in"
# → `subtitle.list` API 返回空数组
```

## 替代验证方案（用于歌词补充）

1. **打开B站字幕视频让人工确认** — 最可靠
2. **截图 + OCR** — 需截取歌词画面，但 vision 工具有地区限制
3. **小红书/微博图片** — 文字在图片里，Jina Reader 无法提取
4. **Whisper** — 仅作参考，不能作为唯一依据

## 文件
- 音频：`/tmp/riyue_audio.m4a` (3:38, 5MB, 已下载)
- 视频段1：`/tmp/riyue_section1.mp4` (0-3:38, 已下载)
- Whisper结果：medium 模型约45个片段，但大量garbled
