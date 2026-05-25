# 新浪图床防盗链实测（2026-05-07）

## 背景
微博/小红书图片托管在 `*.sinaimg.cn`，有防盗链保护。

## 直接 curl 下载（失败）

```bash
# 带完整 Referer + UA 头，仍然失败
curl -s --max-time 15 \
  -H "Referer: https://weibo.com/" \
  -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
  "https://wx3.sinaimg.cn/orj360/006ikc1xgy1i1bphldkvxj30u013un60.jpg" \
  -o /tmp/test.jpg

# 结果：文件大小 36978 bytes（所有图片完全相同大小），非真实图片内容
file /tmp/test.jpg  # JPEG image data, 360x478
```

结论：新浪图床需要 **真实浏览器 cookie + 完整 Referer 链**，普通 curl 无法绕过。

## opencli Browser 提取（成功）

opencli 的 Browser Bridge Extension 使用真实 Windows Chrome，能获取真实图片 URL：

```javascript
// 在 opencli browser eval 中执行
var imgs = document.querySelectorAll('img');
var results = [];
imgs.forEach(function(img) {
  var src = img.src || img.getAttribute('data-src') || '';
  if (src.includes('sinaimg') && img.naturalWidth > 300) {
    results.push({src: src, w: img.naturalWidth, h: img.naturalHeight});
  }
});
return JSON.stringify(results);
```

**重要发现**：微博页面同时存在两种尺寸的图片：
- `orj360` → 360x478（缩略图）
- `mw690` → 640x640（大图，ww1.sinaimg.cn 域名）

应优先提取 `mw690` 版本用于 OCR。

## Vision 分析限制（2026-05-07 确认）

| 工具 | 结果 |
|------|------|
| MiniMax vision_analyze | 无法分析本地文件（"can't view images"） |
| OpenRouter vision | IP 地区限制（403 Forbidden） |
| PaddleOCR pip | 依赖 paddlepaddle（无 GPU 环境不可用） |
| Tesseract | WSL 无 root 权限无法 apt-get install |

## 备选方案

1. **opencli browser 截图**：在 Chrome 中打开页面后用 `browser screenshot` 截取歌词图片区域
2. **音频转写**：用 `faster-whisper`（medium 模型）转写音频，但背景音乐强时输出 garbled
3. **直接求助用户**：将图片发给用户手动转写
