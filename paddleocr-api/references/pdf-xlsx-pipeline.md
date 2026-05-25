# PaddleOCR PDF→xlsx Pipeline 参考（2026-05-06 实测）

## 完整流程

### 1. Token 获取
```bash
python3 -c "
with open('/mnt/c/Users/kangle/Documents/银行/转账/transfer/.env') as f:
    content = f.read()
import re
m = re.search(r'\"token\":\s*\"([^\"]+)\"', content)
print(m.group(1)) if m else print('未找到')
"
# 结果: 3516e7cbe97701b729ac0aca4136db2213ac8148
```

### 2. PDF → xlsx 完整脚本
```python
import os, json, base64, time, requests
from pdf2image import convert_from_path
from openpyxl import Workbook

TOKEN = "3516e7cbe97701b729ac0aca4136db2213ac8148"
API_URL = "https://of096elflbvcx5h1.aistudio-app.com/layout-parsing"
PDF_PATH = "/path/to/input.pdf"
OUT_XLSX = "/path/to/output.xlsx"
IMG_DIR = "/tmp/pdf_pages"
os.makedirs(IMG_DIR, exist_ok=True)

def ocr_image(path):
    with open(path, "rb") as f:
        b64 = base64.b64encode(f.read()).decode()
    r = requests.post(API_URL,
        headers={"Authorization": f"token {TOKEN}", "Content-Type": "application/json"},
        json={"file": b64, "fileType": 1, "useDocOrientationClassify": False, "useDocUnwarping": False},
        timeout=120)
    return r.json() if r.status_code == 200 else None

# 转换全部页面
images = convert_from_path(PDF_PATH, dpi=150)
results = []
for i, img in enumerate(images):
    p = i + 1
    img_path = f"{IMG_DIR}/page_{p}.png"
    img.save(img_path, "PNG")
    result = ocr_image(img_path)
    results.append({"page": p, "result": result})
    # ⚠️ 每页保存（断点续传）
    with open(f"{IMG_DIR}/ocr_results.json", "w", encoding="utf-8") as f:
        json.dump(results, f, ensure_ascii=False, indent=2)
    time.sleep(1)

# 解析并生成 xlsx（根据实际表格结构修改）
wb = Workbook()
ws = wb.active
ws.title = "OCR内容"
# ... 填充逻辑 ...
wb.save(OUT_XLSX)
```

## 关键教训

1. **每页 OCR 后立即保存** — 不然中间超时全部重来（实测第10页超时，流程重跑）
2. **timeout 至少 120 秒** — 60s 不够大页面
3. **子代理处理复杂任务** — PDF→xlsx 多步骤任务直接 delegate_task 委派
4. **execute_code f-string 陷阱** — 含换行/嵌套引号会报 SyntaxError，改用 write_file + terminal
