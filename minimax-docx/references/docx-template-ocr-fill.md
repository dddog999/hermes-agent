# Docx Template Ocr Fill
> Archived `docx-template-ocr-fill` — demoted as verbatim reference from minimax-docx umbrella.

---


# Docx 模板 + 扫描 PDF OCR 批量填充

## 适用场景
- Excel + 扫描 PDF → 填充 docx 模板，批量生成 N 个文件
- 模板中有标记（如 `{{P1}}`, `{{P2}}`）需要替换为数据

## 标记规范（2026-04-20 更新）
**使用 `{{P?}}` 双花括号配对标记**。

| 标记 | 含义 | 模板写法 | 替换结果 |
|------|------|----------|----------|
| `{{P1}}` | 大序号 | `{{P1}}参考文字{{P1}}` | p1 值 |
| `{{P2}}` | 子序号 | `({{P2}}1-1{{P2}})` | (3-15) |
| `{{P3}}` | 内容 | `{{P3}}参考文字{{P3}}` | OCR 提取内容 |
| `{{P4}}` | 类别名 | `{{P4}}参考文字{{P4}}` | 类别名称 |

**为什么用双花括号（不用尖括号 `<P?>`）：**
- `{{}}` XML 安全，不会被转义为 `&lt;&gt;`
- `{` `}` 是单字符，Word 不会拆分到不同 run
- 配对标记中"参考文字"保留原始字体格式，脚本替换时继承第一个 run 的 rPr

**模板制作方法：**
1. 在 Word 中正常排版，选中要替换的文字
2. 在前后加标记：`{{P1}}这是参考文字{{P1}}`
3. 参考文字保留原始格式（字体/字号/加粗），脚本会继承

## 核心流程

### 1. 读取 Excel（xlrd / pandas）
```python
import xlrd
wb = xlrd.open_workbook(xls_path)
sheet = wb.sheet_by_index(0)
# 处理合并单元格：A列大序号只在第一行有值，需向前传播
```

### 2. 扫描 PDF → 图片 → OCR
```python
import fitz  # PyMuPDF
# 渲染指定页为图片
doc = fitz.open(pdf_path)
page = doc[page_num - 1]  # 0-indexed
pix = page.get_pixmap(dpi=150)
pix.save("/tmp/page.png")
```

**OCR 方案（按优先级）：**

#### 方案A: GLM-4V-flash（智谱AI，推荐）
```python
import base64, requests
API_KEY = "your_zhipu_api_key"
API_URL = "https://open.bigmodel.cn/api/paas/v4/chat/completions"

with open(img_path, "rb") as f:
    img_b64 = base64.b64encode(f.read()).decode()

payload = {
    "model": "glm-4v-flash",
    "messages": [{"role": "user", "content": [
        {"type": "image_url", "image_url": {"url": img_b64}},
        {"type": "text", "text": "完整提取这页所有中文文字，只输出文字，不要分析。"}
    ]}]
}
resp = requests.post(API_URL, json=payload, headers={
    "Authorization": f"Bearer {API_KEY}",
    "Content-Type": "application/json"
}, timeout=60)
text = resp.json()["choices"][0]["message"]["content"]
```

#### 方案B: PaddleOCR VL-1.5 API（百度，异步）
```python
# 异步提交 → 轮询结果 → 下载 JSONL
# 参考 hermes-sync/note/peddleOcrSimpleExample.md
JOB_URL = "https://paddleocr.aistudio-app.com/api/v2/ocr/jobs"
# 支持本地文件上传和 URL 模式
```

#### 方案C: 子代理 xiaomi/mimo-v2-omni 视觉能力

### 3. Docx 模板填充（关键：跨 run 标记替换）

#### ⚠️ 核心问题：标记可能被拆分到多个 XML run

Word 的格式化会导致标记文本跨多个 `<w:r>` 元素：
```xml
<!-- 你以为的 -->
<w:r><w:t><P3>内容<P3></w:t></w:r>
<!-- 实际的 -->
<w:r><w:t><P</w:t></w:r>
<w:r><w:t>3</w:t></w:r>
<w:r><w:t>>内容</w:t></w:r>
```

**解决方案：XML 级操作，合并所有 run 后替换**
```python
from docx import Document
from lxml import etree

W = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'

def replace_in_para_xml(para, old_text, new_text):
    """XML级文本替换，处理跨run的情况"""
    p = para._element
    full = para.text
    if old_text not in full:
        return False
    new_full = full.replace(old_text, new_text, 1)
    
    runs = p.findall(f'{{{W}}}r')
    if not runs:
        return False
    
    # 清除第一个run的所有t元素
    first = runs[0]
    for t in first.findall(f'{{{W}}}t'):
        first.remove(t)
    # 写入新文本
    t = etree.SubElement(first, f'{{{W}}}t')
    t.text = new_full
    t.set('{http://www.w3.org/XML/1998/namespace}space', 'preserve')
    # 删除其余run
    for r in runs[1:]:
        p.remove(r)
    return True
```

#### 处理只有开头标记（无闭合标记）的情况
```python
# 如果模板只有 <P3> 没有闭合 <P3>，直接删除标记并按位置填内容
if '<P3>' in para.text:
    clean = re.sub(r'<P3>', '', para.text).strip()
    if '【' in clean:
        replace_in_para_xml(para, full, f'【{p2} {p4}】')  # 标题
    else:
        replace_in_para_xml(para, full, p3_content)  # 内容
```

### 4. 批量生成
```python
import shutil
for item in items:
    out_file = f"output/{item['p2']}_{item['p4']}.docx"
    shutil.copy2(template, out_file)
    doc = Document(out_file)
    # ... 替换标记 ...
    doc.save(out_file)
```

## 踩坑记录

| 问题 | 原因 | 解决 |
|------|------|------|
| `run.text = ""` 后标记还在 | 只清了第一个 run，其余 run 还有文本 | XML 级删除其余 run |
| `<P3>` 标记替换失败 | 标记被拆成 `<P` `3` `>` 三个 run | 用正则 `<P\s*3\s*>` 匹配 |
| `para.text` 有内容但 run 找不到 | 段落结构可能有 hyperlink 等非 run 元素 | 用 `para._element.findall(w:r)` |
| 扫描 PDF 提取 0 字 | pdftotext/PyMuPDF 都不支持图像 OCR | 用视觉模型 API |
| 双括号 `(1-1)` → `((1-1))` | 模板已有括号，替换又加了括号 | 正则匹配包含括号的完整模式 `\\(<P2>.*?<P2>\\)` |
| P4标记未替换 | 文本框中的段落未被正确处理 | 检查 `<w:txbxContent>` 并处理 |
| 分页符位置不对 | 在当前段落添加分页符 | 在前一个段落末尾添加分页符 |
| PDF页码特例 | 某些PDF第2页是封面，内容在第3页 | 维护页码映射表 |

## 进阶技巧

### 1. 处理标记被拆分成多个字符
```python
# <P3> 可能被拆成 <P 3 > 三个部分
if re.search(r'<P\s*3\s*>', para.text):
    clean = re.sub(r'<P\s*3\s*>', '', para.text).strip()
```

### 2. 处理文本框中的段落
```python
# 检查段落是否在文本框中
xml = para._element.xml
if '<w:txbxContent>' in xml:
    # 文本框中的标记也需要替换
```

### 3. P4标记替换（处理文本框）
```python
if '<P4>' in para.text:
    full = para.text
    m = re.search(r'<P4>(.*?)<P4>', full, re.DOTALL)
    if m:
        replace_in_para_xml(para, m.group(0), p4)
    elif '<P4>' in full:  # 单独标记
        replace_in_para_xml(para, '<P4>', p4)
```

### 4. 分页符处理
```python
from docx.enum.text import WD_BREAK

# 在前一个段落末尾添加分页符
if i > 0:
    prev_para = doc.paragraphs[i-1]
    if '<w:br w:type="page"/>' not in prev_para._element.xml:
        run = prev_para.add_run()
        run.add_break(WD_BREAK.PAGE)
```

### 5. PDF页码特例
```python
page_num_map = {"2-7": 3}  # 特例映射
page_num = page_num_map.get(p2, 2)  # 默认第2页
```

## 依赖
```bash
pip install python-docx lxml pymupdf requests xlrd pandas
```
