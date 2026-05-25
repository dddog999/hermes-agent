---
name: paddleocr-api
description: PaddleOCR 完全指南 — 在线 API 进行 OCR 识别，智能验证 PDF 页面完整性，自动判断内容页 vs 封面页。支持图片和 PDF 文档文字提取。
---

# PaddleOCR 完全指南

使用 PaddleOCR 在线 API 进行 OCR 识别，支持图片和 PDF 文档的文字提取。

## API配置来源

API配置存储在用户环境的`.env`文件中（如`C:\\Users\\kangle\\Documents\\银行\\转账\\transfer\\.env`）。

## 多个API端点（重要发现）

PaddleOCR有**多个不同的API端点**，使用不同的认证格式：

### 1. PP-StructureV3 API（同步）

- URL: `https://of096elflbvcx5h1.aistudio-app.com/layout-parsing`
- 认证格式: `Authorization: token {TOKEN}`（注意是`token`不是`Bearer`）
- 请求格式: JSON，包含`file`（base64）和`fileType`（0=PDF, 1=图片）

```python
headers = {
    "Authorization": f"token {TOKEN}",  # 注意：token不是Bearer
    "Content-Type": "application/json"
}
payload = {
    "file": pdf_base64,
    "fileType": 0,  # 0=PDF
    "useDocOrientationClassify": False,
    "useDocUnwarping": False
}
```

### 2. 异步任务API

- URL: `https://paddleocr.aistudio-app.com/api/v2/ocr/jobs`
- 认证格式: `Authorization: bearer {TOKEN}`（注意是小写`bearer`）
- 请求格式: 本地文件用multipart/form-data，URL文件用JSON
- 需要轮询任务状态直到完成

```python
headers = {
    "Authorization": f"bearer {TOKEN}",  # 小写bearer
}
# 本地文件模式
with open(file_path, "rb") as f:
    files = {"file": f}
    data = {"model": MODEL, "optionalPayload": json.dumps(optional_payload)}
    response = requests.post(JOB_URL, headers=headers, data=data, files=files)
```

## 认证错误排查

如果收到401 Unauthorized错误：
1. 检查token是否完整（.env文件可能存储截断格式）
2. 检查Authorization头格式：`token` vs `bearer` vs `Bearer`
3. 不同API端点使用不同的认证格式

## OCR质量注意事项

1. **封面页vs内容页**: PDF第1页通常是封面，只有标题。需要提取**第2页**才有实际内容
2. **验证OCR结果**: 检查返回文本长度，封面页通常<50字符，内容页>100字符
3. **需要预处理**: 先将PDF渲染为图片，再进行OCR识别

## 智能页面选择（Smart Validation）

### ⚠️ Token 失效问题
- **问题**: token 可能已过期或有调用限制
- **症状**: API 返回 401 Unauthorized 错误
- **验证方法**: 
  ```bash
  curl -X POST "https://paddleocr.aistudio-app.com/api/v2/ocr/jobs" \
    -H "Authorization: bearer ***" \
    -F "model=PaddleOCR-VL-1.5" \
    -F "optionalPayload={}" \
    -F "file=@test.pdf"
  ```
- **解决方案**: 从 KeePass 获取新 token，或检查 PaddleOCR 官网

### 核心逻辑：先验证后降级

**错误做法**（不要这样做）：
```python
# 错误：假设简短内容一定在第3页
if p2 in short_items:
    page_num = 3  # 这种假设可能错误
```

**正确做法：验证后降级**：
```python
def process_with_validation(pdf_path, p2):
    """先识别第2页，验证完整性，不完整则降级到第3页"""
    
    # 特例：2-7 直接用第3页
    if p2 == "2-7":
        return ocr_page(pdf_path, 3)
    
    # 1. 先尝试第2页
    result_page2 = ocr_page(pdf_path, 2)
    
    # 2. 验证是否为完整内容
    if is_complete_content(result_page2):
        return result_page2
    
    # 3. 第2页不完整，降级到第3页
    result_page3 = ocr_page(pdf_path, 3)
    
    if is_complete_content(result_page3):
        return result_page3
    
    # 4. 都不完整，返回第2页结果（即使不完整）
    return result_page2
```

### 完整内容验证函数

```python
import re

def is_complete_content(text):
    """验证文本是否为完整内容格式"""
    if not text or len(text) < 100:
        return False
    
    # 检查特征模式
    patterns = [
        r'【\d+-\d+\s+.*?】',  # 【X-Y 类别】格式
        r'内容标准[：:]',      # 内容标准
        r'自评得分[：:]',      # 自评得分
        r'自评情况简述',       # 自评情况简述
    ]
    
    # 至少匹配2个特征
    matches = sum(1 for p in patterns if re.search(p, text))
    
    # 字符数检查（放宽范围）
    if 100 <= len(text) <= 500:
        matches += 1
    
    return matches >= 2
```

### ⚠️ 关键教训：任务前分析 PDF 类型

**正确做法（先分析后处理）：**
```python
def analyze_pdf_type(pdf_path):
    """分析 PDF 是扫描版还是文本版"""
    from PyPDF2 import PdfReader
    reader = PdfReader(pdf_path)
    
    for page_num in range(min(3, len(reader.pages))):
        text = reader.pages[page_num].extract_text()
        if text and text.strip() and text.strip() != '\f':
            return "text"  # 文本版 PDF
    return "scanned"  # 扫描版 PDF
```

**扫描版 PDF 处理策略：**
```python
def handle_scanned_pdf(pdf_path, page_num):
    """处理扫描版 PDF：必须提取图像再 OCR"""
    from pdf2image import convert_from_path
    import tempfile
    
    images = convert_from_path(pdf_path, first_page=page_num, last_page=page_num, dpi=200)
    if not images:
        return None
    
    with tempfile.NamedTemporaryFile(suffix='.pdf', delete=False) as f:
        images[0].save(f.name, 'PDF')
        temp_path = f.name
    
    result = ocr_with_paddle(temp_path)
    os.unlink(temp_path)
    return result
```

## PDF页面顺序特例

某些PDF可能有特殊的页面结构：
- **检查PDF页数**: 使用`pdfinfo`或`PyPDF2`检查PDF总页数
- **验证内容**: 如果第2页内容过短（<50字符），可能需要尝试第3页
- **用户确认**: 让用户确认应该识别哪一页

## OCR API限流处理

OCR API可能有限流，特别是批量处理时：
- **重试间隔**: 设置更长的重试间隔（建议5-10秒）
- **断点续传**: 保存中间结果，支持中断后继续
- **错误处理**: 记录失败的任务，单独重试

## 批量处理脚本模式

```python
def process_all_items(items, base_path, output_file, api_config):
    """批量处理所有条目"""
    ocr_results = {}
    
    for i, item in enumerate(items, 1):
        p2 = item["p2"]
        pdf_path = os.path.join(base_path, item["pdf_path"])
        
        print(f"[{i}/{len(items)}] 处理 {p2}")
        
        # 智能页面选择和 OCR
        result = process_with_validation(pdf_path, p2)
        
        if result:
            ocr_results[p2] = result
            
            # 定期保存
            if len(ocr_results) % 5 == 0:
                with open(output_file, "w") as f:
                    json.dump(ocr_results, f, ensure_ascii=False, indent=2)
        
        time.sleep(2)  # 避免限流
    
    with open(output_file, "w") as f:
        json.dump(ocr_results, f, ensure_ascii=False, indent=2)
    
    return ocr_results
```

## 异步 OCR 调用代码

```python
def ocr_with_paddle(file_path, job_url, token, model):
    """异步 OCR 处理"""
    headers = {"Authorization": f"bearer {token}"}
    data = {
        "model": model,
        "optionalPayload": json.dumps({
            "useDocOrientationClassify": False,
            "useDocUnwarping": False,
            "useChartRecognition": False,
        })
    }
    
    # 1. 提交作业
    with open(file_path, "rb") as f:
        response = requests.post(job_url, headers=headers, data=data, files={"file": f})
    
    if response.status_code != 200:
        return None
    
    jobId = response.json()["data"]["jobId"]
    
    # 2. 轮询结果
    for _ in range(60):  # 最多5分钟
        time.sleep(5)
        result_response = requests.get(f"{job_url}/{jobId}", headers=headers)
        state = result_response.json()["data"]["state"]
        
        if state == 'done':
            jsonl_url = result_response.json()['data']['resultUrl']['jsonUrl']
            jsonl_response = requests.get(jsonl_url)
            lines = jsonl_response.text.strip().split('\n')
            
            results = []
            for line in lines:
                if not line.strip():
                    continue
                result = json.loads(line)["result"]
                for res in result["layoutParsingResults"]:
                    results.append(res["markdown"]["text"])
            
            return "\n\n".join(results) if results else None
        elif state == "failed":
            return None
    return None
```

## 用户偏好

- **先审阅再注入**：用户偏好先保存 OCR 结果到 .md 文件，用户确认后再注入到 docx 模板
- **任务后验证**：用子代理（如 Qwen CLI）验证结果质量
- **记录到计划**：进度和发现记录到任务计划文档
- **主动分析**：发现问题主动分析原因，不要绕圈子

## 简单字符验证码 OCR 降级方案（2026-05-07 实测）

PaddleOCR VL 系列**不擅长**简单字符验证码（如登录 4 位图）：
- 250x100 PNG 白底黑字 4 位验证码
- PP-StructureV3 sync 端点返回 `{}`
- PP-StructureV3 async 端点返回空文本
- Tesseract 误识别为 "shwer"

**降级方案**：要求用户在聊天中输入验证码，不尝试全自动 OCR。

**推荐备选**：
- 天若OCR（KeePass: 天若OCR文字识别，账号 479781652@qq.com，密码 7DF9BC561F）
- 或使用 agent-browser 截图后发送给用户人工识别

## .xls文件处理

旧版Excel文件（.xls）需要`xlrd`库，`openpyxl`只支持.xlsx格式：
```bash
pip install pandas xlrd
```

## 常见问题与解决方案

| 问题 | 原因 | 解决方案 |
|------|------|----------|
| OCR 返回空结果 | PDF 是扫描版，无文本层 | 先用 pdf2image 提取图像，再 OCR |
| 第2页是封面 | PDF 结构不同 | 验证后降级到第3页 |
| 第3页是材料清单 | 自评内容在其他页面 | 尝试其他页面或标记为无完整内容 |
| 字符数过少 | PDF 内容本身简短 | 放宽验证标准或标记异常 |
| API 返回 401 | Token 过期或无效 | 检查 KeePass 或向用户请求新 token |

## 相关文档路径

- `C:\\Users\\kangle\\Nutstore\\1\\myNutstore (1)\\hermes-sync\\note\\PP-StructureV3_API.md`
- `C:\\Users\\kangle\\Nutstore\\1\\myNutstore (1)\\hermes-sync\\note\\peddleOcrSimpleExample.md`