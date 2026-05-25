# PaddleOCR 选型与降级链速查

## PP-OCRv5 vs PP-StructureV3

| 维度 | PP-OCRv5 | PP-StructureV3 |
|------|----------|----------------|
| 输出 | `rec_texts` 纯文本列表 | 结构化 Markdown |
| 版面信息 | ❌ 无 | ✅ block_label + bbox |
| 复杂表格 | ❌ 差 | ✅ SLANeXt |
| 适用场景 | 纯文字图片 OCR | 文档理解、版式还原 |

## PDF OCR 降级链

PDF → pdfplumber → 有文字 ✅
→ 无文字 → PaddleOCR 本地 → 简单版式 ✅
→ 复杂版式 → PP-StructureV3 在线 API → 结构化 Markdown ✅
→ 失败 → Tesseract 备选

## 在线 API 速查

### 同步端点（逐页，推荐）
- URL: `https://of096elflbvcx5h1.aistudio-app.com/layout-parsing`
- Auth: `token {TOKEN}`（不是 Bearer）
- 输入: base64 图片，fileType=1
- 超时: 120s

### 异步端点（整份 PDF）
- URL: `https://paddleocr.aistudio-app.com/api/v2/ocr/jobs`
- Auth: `bearer {TOKEN}`（小写）
- 输入: multipart/form-data file=PDF

### Token
`3516e7cbe97701b729ac0aca4136db2213ac8148` (KeePass: PaddleOCR)
