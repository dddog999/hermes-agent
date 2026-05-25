---
name: bilibili-lyric-extraction
description: B站视频歌词/字幕提取实战 — OCR降级链、工作流规则、已知限制（2026-05-08实测）
category: media
---

# B站字幕/歌词OCR提取实战

## ⚠️ 最重要工作流规则

**先展示，后写入**：OCR提取结果必须先展示给用户审阅，用户确认后再写入歌词文件。原有歌词文件中的内容是相对正确的基准，**禁止在未经验证的情况下覆盖**。

---

## 完整降级顺序（2026-05-08 实测）

| 优先级 | 工具 | 状态 | 说明 |
|--------|------|------|------|
| 1 | yt-dlp下载字幕 | ✅最优先 | B站视频常有字幕文件，直接下载可用 |
| 2 | PaddleOCR API | ❌Token失效(401) | 两个端点均返回401；Token存KeePass（kp_db.kdbx） |
| 3 | tesseract + chi_sim | ❌低分辨率失效 | apt install成功，但852×480视频帧OCR率≈0 |
| 4 | vision_analyze工具 | ❌本地文件bug | file://和HTTP本地URL均不可用（工具bug） |
| 5 | browser_vision | ❌图片识别不可用 | 只能分析DOM结构，无法识别渲染img内容 |
| 6 | opencli browser截图 | ⚠️需人工 | 可截图，但后续vision分析链路不通 |
| 7 | 天若OCR | ⚠️需手动 | KeePass有账号（479781652@qq.com/7DF9BC561F）|
| 8 | Whisper音频转写 | ⚠️参考用 | 对歌曲garbled，仅作结构参考 |
| 9 | 直接求助用户 | ✅最终方案 | 所有自动化失败时人工听写 |

---

## 方案1: yt-dlp下载字幕（B站首选）

```bash
# 查看可用字幕
yt-dlp --list-subs "https://www.bilibili.com/video/BVxxxxx"

# 下载字幕
yt-dlp --write-subs --sub-lang zh-Hans \
  -o "/tmp/sub.%s" \
  "https://www.bilibili.com/video/BVxxxxx"

# 下载最高质量帧用于OCR
yt-dlp --write-frames all \
  -o "/tmp/frame_%08d.jpg" \
  "https://www.bilibili.com/video/BVxxxxx"

# 或指定时间段截图
ffmpeg -i $(yt-dlp --get-url "URL") -ss 100 -vframes 1 /tmp/frame_100s.jpg
```

---

## 方案2: PaddleOCR API

**Token位置**：KeePass `~/.hermes/kp_db.kdbx`（主密码: 5201314），搜索"paddle"

**两个已知端点（2026-05-08 均返回401）：**
```python
# 同步端点
SYNC_URL = "https://of096elflbvcx5h1.aistudio-app.com/layout-parsing"
headers = {"Authorization": f"token {TOKEN}"}

# 异步端点
JOB_URL = "https://paddleocr.aistudio-app.com/api/v2/ocr/jobs"
headers = {"Authorization": f"bearer {TOKEN}"}
```

**若Token更新可用**，参考 `paddleocr-api` skill。

---

## 方案3: tesseract（低分辨率失效）

```bash
# 安装（WSL需sudo）
sudo apt-get install -y tesseract-ocr tesseract-ocr-chi-sim

# 测试
tesseract /tmp/frame.jpg stdout -l chi_sim
```

**已知问题**：B站截图典型分辨率 852×480，字幕字体极小（<12px），OCR率≈0。需获取更高分辨率截图（至少1920×1080）才有可能识别。

---

## 方案4: Whisper音频转写（参考用）

```python
from faster_whisper import WhisperModel

model = WhisperModel("medium", device="cpu", compute_type="int8")
segments, info = model.transcribe(
    "/tmp/audio.m4a",
    language="zh",
    condition_on_previous_text=False
)
for seg in segments:
    print(f"[{seg.start:.1f}-{seg.end:.1f}] {seg.text}")
```

**注意**：背景音乐强的歌曲，Whisper输出是garbled，仅作歌词结构参考，不能作为最终歌词。

---

## B站关键帧提取实测记录（日月-第12季）

| 时间 | 文件 | 分辨率 | tesseract结果 |
|------|------|--------|--------------|
| 100s | riyue_frame_100s.jpg | 852×480 | 空 |
| 105s | riyue_frame_105s.jpg | 852×480 | 「由术在3站」(garbled) |
| 115s | riyue_frame_115s.jpg | 852×480 | 「小棕在B站/者R御/好阳儿驴和光」(garbled) |
| 120s | riyue_frame_120s.jpg | 852×480 | 「汉家衬乱季驳/赤案入稳重允」(garbled) |

**结论**：852×480分辨率太低，字幕无法准确OCR。需要yt-dlp下载高分辨率帧或字幕文件。

---

## 常见问题

| 问题 | 原因 | 解决 |
|------|------|------|
| vision_analyze返回"can't view images" | MiniMax工具不接受本地文件路径 | 这是工具bug，换用yt-dlp下载字幕或截图上传到图床 |
| PaddleOCR返回401 | Token过期 | 从KeePass获取新token或申请新账号 |
| Whisper歌曲转写garbled | 背景音乐干扰 | 正常现象，对歌曲转写质量差，需人工核对 |
| B站字幕下载失败 | 视频无字幕/需要登录 | 尝试yt-dlp --cookies-from-browser chrome |
