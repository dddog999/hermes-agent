# PP-StructureV3 在线 API Fallback 模式

> 2026-05-09 实测记录：保障房 12 页 PDF OCR

## 背景

本地 PaddleOCR（transformers 引擎）对复杂版式（表格、多栏、银行流水扫描件）识别率低，且 PP-OCRv5 只返回 `rec_texts` 纯文本列表，无版面结构信息。PP-StructureV3 在线 API 作为 fallback 可保留文档结构。

## API 端点

### 同步端点（推荐，逐页 OCR）

- URL: `https://of096elflbvcx5h1.aistudio-app.com/layout-parsing`
- 认证: `Authorization: token {TOKEN}`（注意是 `token` 不是 `Bearer`）
- 内容类型: `application/json`
- 超时建议: 120s（大图可能较慢）

### 异步端点（可直传 PDF）

- URL: `https://paddleocr.aistudio-app.com/api/v2/ocr/jobs`
- 认证: `Authorization: bearer {TOKEN}`（注意是小写 `bearer`）
- 输入: multipart/form-data，file=PDF 文件
- 需轮询任务状态直到 `state == 'done'`

## 调用流程

### 同步模式（PDF → 图片 → API）

```python
import base64, time, requests
from pdf2image import convert_from_path

TOKEN = "3516e7cbe97701b729ac0aca4136db2213ac8148"
API_URL = "https://of096elflbvcx5h1.aistudio-app.com/layout-parsing"

def ocr_page(pdf_path, page_num, dpi=150):
    """OCR PDF 的指定页面"""
    # 1. PDF → PNG
    images = convert_from_path(pdf_path, first_page=page_num, last_page=page_num, dpi=dpi)
    img_path = f"/tmp/page_{page_num}.png"
    images[0].save(img_path, "PNG")
    
    # 2. PNG → base64
    with open(img_path, "rb") as f:
        b64 = base64.b64encode(f.read()).decode("utf-8")
    
    # 3. API 调用
    headers = {"Authorization": f"token {TOKEN}", "Content-Type": "application/json"}
    payload = {
        "file": b64,
        "fileType": 1,  # 图片
        "useDocOrientationClassify": False,
        "useDocUnwarping": False
    }
    resp = requests.post(API_URL, headers=headers, json=payload, timeout=120)
    
    if resp.status_code != 200:
        print(f"API错误: {resp.status_code} {resp.text[:200]}")
        return None
    
    return resp.json()

# 批量处理
for page in range(1, 13):
    print(f"[{page}/12] OCR...")
    result = ocr_page(pdf_path, page)
    time.sleep(2)  # 避免限流
```

## 返回结构

```python
# result 结构:
{
  "logId": "...",
  "errorCode": 0,
  "errorMsg": "Success",
  "result": {
    "layoutParsingResults": [{
      "prunedResult": {
        "parsing_res_list": [
          {
            "block_label": "doc_title",  # 或 table, text, figure, etc.
            "block_content": "中国农业银行账户活期交易明细清单",
            "block_bbox": [465, 114, 803, 140],
            "block_id": 0,
            "block_order": 1,
            "group_id": 0
          },
          # ...更多区块
        ]
      }
    }]
  }
}
```

## 实测结果

| 维度 | 数据 |
|------|------|
| 测试场景 | 12 页银行流水扫描件（含表格） |
| 方法 | 同步 API 逐页 OCR |
| 每页耗时 | 2-4 秒 |
| 成功率 | 12/12 |
| 错误率 | 0%（无超时、无 401） |
| 限流 | 未触发（间隔 1-2s） |

## 注意事项

1. **同步 API 不支持直传 PDF**：必须先 `pdf2image` 转图片，`fileType=1`
2. **Token 可能过期**：长时间未用需验证，备用方案从天若OCR或KeePass获取
3. **限流处理**：批量逐页请求时建议 `time.sleep(1-2)`
4. **空页面判断**：返回字符数 < 50 的可能为空内容页
5. **认证格式差异**：同步 API 用 `token`，异步 API 用 `bearer`
