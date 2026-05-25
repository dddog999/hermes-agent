# PaddleOCR API 实测结果（2026-05-08）

## Token 状态
✅ **有效**：`3516e7cbe97701b729ac0aca4136db2213ac8148`

两个端点均正常工作：

| 端点 | URL | Auth 格式 | 适用场景 |
|------|-----|-----------|---------|
| 同步 | `https://of096elflbvcx5h1.aistudio-app.com/layout-parsing` | `token {TOKEN}`（不是 Bearer） | 单张图片，即时返回 |
| 异步 | `https://paddleocr.aistudio-app.com/api/v2/ocr/jobs` | `bearer {TOKEN}`（小写） | 批量任务，需轮询 job 状态 |

## 同步调用示例（视频帧 OCR）

```python
import base64, requests

API_URL = "https://of096elflbvcx5h1.aistudio-app.com/layout-parsing"
TOKEN = "3516e7cbe97701b729ac0aca4136db2213ac8148"

with open("/tmp/frame.jpg", "rb") as f:
    file_data = base64.b64encode(f.read()).decode("ascii")

headers = {"Authorization": f"token {TOKEN}", "Content-Type": "application/json"}
payload = {
    "file": file_data,
    "fileType": 1,
    "useDocOrientationClassify": False,
    "useDocUnwarping": False,
}
r = requests.post(API_URL, json=payload, headers=headers, timeout=60)
data = r.json()
blocks = data["result"]["layoutParsingResults"][0]["prunedResult"]["parsing_res_list"]
for b in blocks:
    if b.get("block_content"):
        print(f"[{b['block_label']}] {b['block_content']}")
```

## 关键参数

- `use_ocr_for_image_block`: 默认为 `false`（只返回图片块，不对块内文字做 OCR）。**视频歌词截图需设为 `true`** 才能识别歌词艺术字。

## 对视频艺术字的识别能力

- PP-StructureV3 sync 对装饰性艺术字歌词**有部分识别能力**
- 对手写体（如微博手写歌词）识别效果较好
- 对高饱和度视频截图（852×480）识别率有限，建议配合 Whisper 时间戳交叉验证

## 微博手写歌词 OCR 实测（2026-05-08）

手写字识别效果良好，成功提取《长恨》歌词。但注意：微博帖子歌词可能是不同季的内容（需核对），且图片可能有水印/签名干扰。
