# Docx Xml Replace
> Archived `docx-xml-replace` — demoted as verbatim reference from minimax-docx umbrella.

---


# docx XML 跨 Run 文本替换

## 方法1: python-docx + lxml（推荐）

python-docx 中标记可能被拆到多个 run（如 `<P3>` 拆为三个 run）。用 lxml 直接操作 XML 解决：

```python
from docx import Document

doc = Document(template_path)
nsmap = {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}

for para in doc.paragraphs:
    if '<P1>' in para.text:
        elem = para._element
        runs = elem.findall('.//w:r', nsmap)
        
        # 合并文本
        full_text = ''.join(
            t.text or '' for run in runs 
            if (t := run.find('w:t', nsmap)) is not None
        )
        
        # 替换
        new_text = full_text.replace('<P1>', value).replace('<P1>', '')
        
        # 清空所有run，在第一个写入
        for run in runs:
            if (t := run.find('w:t', nsmap)) is not None:
                t.text = ''
        if runs:
            t = runs[0].find('w:t', nsmap)
            t.text = new_text
            t.set('{http://www.w3.org/XML/1998/namespace}space', 'preserve')
```

## 方法2: zipfile 直接操作（lxml 不可用时的备用方案）

当 python-docx 因 lxml 安装问题无法导入时，**直接用 zipfile 操作 docx 的 XML**：

```python
import zipfile
import shutil

# 复制模板
shutil.copy(template_path, output_path)

with zipfile.ZipFile(output_path, 'a') as docx_zip:
    with docx_zip.open('word/document.xml') as f:
        xml_content = f.read().decode('utf-8')
    
    # 执行替换（注意转义XML特殊字符）
    for marker, value in replacements.items():
        value_escaped = value.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')
        xml_content = xml_content.replace(marker, value_escaped)
    
    docx_zip.writestr('word/document.xml', xml_content)
```

**Pitfalls:**
- docx 实际是 zip 文件，可直接用 zipfile 打开
- 替换文本中的 `&`, `<`, `>` 必须转义为 `&amp;`, `&lt;`, `&gt;`
- 此方法不处理跨 run 问题，适合标记在单个 run 中的情况
- 如果标记被拆到多个 run，标记本身会被 XML 标签隔开导致替换失败

---

# 飞书发文件完整流程

## 1. 获取 tenant_access_token

```python
import requests

r = requests.post(
    "https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal",
    json={"app_id": APP_ID, "app_secret": APP_SECRET}
)
token = r.json()["tenant_access_token"]
```

## 2. 上传文件

```python
with open(file_path, "rb") as f:
    upload_r = requests.post(
        "https://open.feishu.cn/open-apis/im/v1/files",
        headers={"Authorization": f"Bearer {token}"},
        data={"file_type": "stream", "file_name": file_name},
        files={"file": (file_name, f, "application/octet-stream")}
    )
file_key = upload_r.json()["data"]["file_key"]
```

## 3. 发送文件消息

```python
send_r = requests.post(
    "https://open.feishu.cn/open-apis/im/v1/messages",
    params={"receive_id_type": "chat_id"},  # 群聊用 chat_id，私聊用 open_id
    headers={
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json; charset=utf-8"
    },
    json={
        "receive_id": chat_id,  # oc_xxx 格式
        "msg_type": "file",
        "content": json.dumps({"file_key": file_key})
    }
)
```

**Pitfalls:**
- `file_type` 用 `stream`（普通文件），不是 `opus`（音频）
- `receive_id_type` 要匹配：群聊 `chat_id`(oc_xxx)，私聊 `open_id`(ou_xxx)
- App Secret 从 KeePass 获取，需完整值（.env 可能截断显示）
- Token 约2小时过期，发送失败时重新获取

---

# OCR 识别扫描版 PDF

## Tesseract OCR（推荐备用方案）

当云 OCR API 不可用时，用 Tesseract 作为本地方案：

```bash
# 安装
sudo apt install tesseract-ocr tesseract-ocr-chi-sim

# 提取PDF页面为PNG
pdftoppm -png -f 5 -l 5 -r 200 input.pdf output_page

# OCR识别
tesseract output_page-05.png output_text -l chi_sim
```

## 批量识别多页寻找内容

扫描版 PDF 的自评内容位置不固定，需尝试多页：

```python
for page in range(1, 6):
    # 提取页面
    subprocess.run(["pdftoppm", "-png", "-f", str(page), "-l", str(page), 
                     "-r", "200", pdf_path, output_prefix])
    # OCR
    subprocess.run(["tesseract", img_path, txt_path, "-l", "chi_sim"])
    # 检查是否符合格式
    if is_complete_content(text):
        return text
```

**验证标准（自评内容）：**
- 长度 >= 80 字符
- 包含 `【X-Y 类别】` 格式
- 包含 `内容标准`
- 包含 `自评得分`
- 包含 `自评情况`

---

# PDF 类型判断

```python
from PyPDF2 import PdfReader

reader = PdfReader(pdf_path)
text = reader.pages[0].extract_text()
is_scanned = not text or len(text.strip()) < 100
```
