# Docx Textbox Preservation
> Archived `docx-textbox-preservation` — demoted as verbatim reference from minimax-docx umbrella.

---


# DOCX文本框/图片框保留方案

## 问题
python-docx（`Document()` + `save()`）会破坏 DOCX 中的 DrawingML 结构，特别是 `mc:AlternateContent`（WPS/Word文本框、浮动图片等）。保存后文本框内容会变成普通段落。

## 根本原因
python-docx 在保存时重新序列化 XML，丢失了以下元素的结构：
- `mc:AlternateContent`（兼容性标记块）
- `wps:txbx`（WordprocessingShape文本框）
- `wp:anchor`（浮动定位）
- `v:textbox`（VML文本框）

同时 lxml 的 `findall('{NS}element')` 也无法匹配到 `mc:AlternateContent` 深层嵌套的元素（`iter()` 可以）。

## 正确方案：纯字符串替换

直接对 zip 中的 `document.xml` 原始字节做字符串替换，完全绕过 python-docx 的序列化：

```python
from zipfile import ZipFile, ZIP_DEFLATED
import os, re

def fill_template(template_path, out_path, marker_map: dict):
    """
    marker_map: {'{{P1}}': '替换值1', '{{P2}}': '替换值2', ...}
    """
    tmp = out_path + '.tmp'
    with ZipFile(template_path, 'r') as zin, ZipFile(tmp, 'w', ZIP_DEFLATED) as zout:
        for item in zin.infolist():
            data = zin.read(item.filename)
            if item.filename == 'word/document.xml':
                text = data.decode('utf-8')
                for old, new in marker_map.items():
                    text = text.replace(old, new)
                # 兜底清理残留标记
                text = re.sub(r'\{\{P\d+(?:_\w+)?\}\}', '', text)
                data = text.encode('utf-8')
            zout.writestr(item, data)
    os.replace(tmp, out_path)
```

此方案**原样保留**所有 DrawingML 结构（文本框、图片、浮动元素等）。

## 何时用此方案

需要修改 DOCX 且满足以下任一条件时：
- 模板中包含文本框（wps:txbx / v:textbox）
- 有浮动图片或浮动元素（wp:anchor）
- 有 `mc:AlternateContent` 结构（WPS/JiMu等国产Office兼容格式）
- 需要精确保留页面的视觉布局

## 调试技巧

用原始字节查找：
```python
with ZipFile(docx_path, 'r') as z:
    raw = z.read('word/document.xml').decode('utf-8')
# 找特定文本或标记的位置
idx = raw.find('{{P2}}')
print(raw[idx-200:idx+100])
```

用 zipfile + lxml 联合分析：
```python
from lxml import etree
W = '{http://schemas.openxmlformats.org/wordprocessingml/2006/main}'
WPS = '{http://schemas.microsoft.com/office/word/2010/wordprocessingShape}'
# iter() 能找到 findall() 漏掉的深层嵌套元素
for elem in root.iter():
    if elem.tag == f'{WPS}txbx':
        t = elem.find(f'{W}txbxContent/{W}p/{W}r/{W}t')
```

## 适用场景
- 批量生成含文本框的 DOCX（证书、模板填充）
- 保留 WPS 特殊格式的文档
- 需要精确控制页面布局的自动化文档生成