---
name: image-ocr-lyric-extraction
description: 图片OCR降级链 + 歌词提取完整方案（适用于微博/小红书手写歌词、B站字幕等场景）
category: media
---

# 图片 OCR 降级链 & 歌词提取实战

## 完整降级顺序

| 优先级 | 工具 | 状态 | 说明 |
|--------|------|------|------|
| 1 | PaddleOCR API | ❓需token | 检查 `~/.hermes/.env` 是否有 PaddleOCR token |
| 2 | opencli browser + vision_analyze | ⚠️部分可用 | MiniMax不支持vision（返回"can't view images"） |
| 3 | Whisper 音频转写 | ⚠️参考用 | small/medium 模型对歌曲转写garbled，仅作参考 |
| 4 | 直接求助用户 | ✅最终方案 | 微博手写图片OCR失败时，让用户手动转写 |

## 工具1: PaddleOCR API

见 `paddleocr-api` skill。检查 token：`grep -i paddle ~/.hermes/.env`

## 工具2: opencli Browser + Vision 分析

### Weibo 图片发现
```bash
opencli browser open "https://weibo.com/xxxxx"
sleep 6
opencli browser eval "
(function() {
  var imgs = document.querySelectorAll('img');
  var results = [];
  imgs.forEach(function(img) {
    var src = img.src || img.getAttribute('data-src') || '';
    if (src.includes('sinaimg') && img.naturalWidth > 300) {
      results.push({src: src, w: img.naturalWidth, h: img.naturalHeight});
    }
  });
  return JSON.stringify(results);
})()
"
```

关键发现：
- 路径含 `orj360` = 360p 缩略图，`mw690` = 690p 大图
- 新浪图床防盗链：直接 curl 返回 403，需 `Referer: https://weibo.com/`
- 实测：即使带 Referer 仍返回小文件（36978 bytes），需真实浏览器 cookie
- vision_analyze 对 MiniMax 完全不可用（返回 "can't view images"）

## 工具3: Whisper 音频转写（歌词验证）

### 完整流程
```python
from faster_whisper import WhisperModel

# 下载音频（B站：yt-dlp）
yt-dlp --cookies-from-browser chrome -f "30280" \
  -o "/tmp/audio.m4a" \
  "https://www.bilibili.com/video/BVxxxxx"

# 检查时长
ffprobe -v error -show_entries format=duration -of csv=p=0 /tmp/audio.m4a

# 转写（small 快，medium 准）
model = WhisperModel("small", device="cpu", compute_type="int8")
# model = WhisperModel("medium", device="cpu", compute_type="int8")

segments, info = model.transcribe("/tmp/audio.m4a", language="zh",
                                   condition_on_previous_text=False)
for seg in segments:
    print(f"[{seg.start:.1f}-{seg.end:.1f}] {seg.text}")
```

### 音量/静默检测（判断是否有人声）
```bash
for start in $(seq 0 5 220); do
  ffmpeg -y -ss $start -t 5 -i /tmp/audio.m4a \
    -af volumedetect -f null - 2>&1 | grep -E 'mean_volume|max_volume'
done
```

### Whisper 注意事项
- `condition_on_previous_text=False` 减少连续错误传播
- 对背景音乐强的歌曲，输出仍是 garbled（乱码），需人工核对
- 模型缓存位置：`~/.cache/huggingface/hub/models--Systran--faster-whisper-*`

## 工具4: 直接求助用户（最终降级）

当上述方法全部失败时（微博手写图片、新浪图床防盗链、vision不可用）：
→ 把图片或链接发给用户，让用户手动转写。这是最实用的方案。

## 已知限制（2026-05-07 确认）

| 限制 | 详情 |
|------|------|
| MiniMax vision | 不支持图片分析，返回 "can't view images" |
| OpenRouter vision | IP 地区限制，403 Forbidden |
| Tesseract | WSL 无 root 无法 apt-get install |
| PaddleOCR pip | 需要 paddlepaddle（无 GPU/PyTorch 环境不可用） |
| 新浪图床 | 带 Referer 头仍返回小文件（防盗链需真实浏览器 cookie） |
| Whisper 歌曲转写 | 背景音乐强时输出 garbled，仅作参考 |
