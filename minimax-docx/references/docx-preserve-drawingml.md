# Docx Preserve Drawingml
> Archived `docx-preserve-drawingml` — demoted as verbatim reference from minimax-docx umbrella.

---


# DOCX 模板填充：保留 DrawingML 文本框

## 触发场景
用 Python 填充包含 `{{P?}}` 标记的 docx 模板时，必须保留文本框、mc:AlternateContent 等 DrawingML 结构，不能用 `python-docx` 的 `Document` + `save()`，否则这些结构会被破坏。

## 核心问题
`python-docx` 保存时会重新解析 XML，导致：
- `mc:AlternateContent`（WPS 文本框等）被破坏
- DrawingML 中的文本框内容丢失或移位
- 文本框的固定位置（锚点）失效

## 正确方案：纯字符串替换

直接操作 zip 中的 `document.xml` 原始字节，不走 python-docx 解析层：

```python
from zipfile import ZipFile, ZIP_DEFLATED
import re, os

MARKER_ANY = re.compile(r'\{\{P[1-4](_TITLE|_CONTENT|_SCORE|_DESC)?\}\}')

def fill_docx(template_path, out_path, marker_map):
    """marker_map: {'{{P1}}': '替换值', ...}"""
    tmp = out_path + '.tmp'
    with ZipFile(template_path, 'r') as zin, ZipFile(tmp, 'w', ZIP_DEFLATED) as zout:
        for item in zin.infolist():
            data = zin.read(item.filename)
            if item.filename == 'word/document.xml':
                text = data.decode('utf-8')
                for old, new in marker_map.items():
                    text = text.replace(old, new)
                # 兜底清理残留标记
                text = MARKER_ANY.sub('', text)
                data = text.encode('utf-8')
            zout.writestr(item, data)
    os.replace(tmp, out_path)
```

## 关键注意事项

1. **命名空间陷阱**：lxml 的 `findall('{NS}t')` 无法匹配 mc:AlternateContent 深层嵌套的 `w:t` 元素——用字符串操作完全避免命名空间解析问题。

2. **模板结构确认**：先用 `zipfile` 读取 `document.xml`，确认标记的精确位置和嵌套关系。

3. **WPS 文本框结构**：
   - 标记通常在 `<wps:txbx><w:txbxContent><w:p><w:r><w:t>{{P2}}</w:t>` 内
   - 位置可能：`{{P2}}` 同时出现在文本框内（固定位置）和普通段落流（随文字动）
   - 用字符串搜索定位准确位置后再替换

4. **mc:AlternateContent 完整结构**：
   ```
   <mc:AlternateContent>
     <mc:Choice Requires="wps">
       <w:drawing>
         <wp:anchor ...>
           <wp:inline ...>
             <a:graphic>
               <a:graphicData>
                 <wps:wsp>
                   <wps:txbx><w:txbxContent><w:p><w:r><w:t>文本</w:t>
   ```

## 典型村项目实际案例
- 模板：`典型村精细模板_v8.docx`（WPS 文本框结构）
- 脚本：`/mnt/c/Users/kangle/OfficeChores/data/典型村/extracted/src/fill_template.py`
- 标记：`{{P1}}` `{{P2}}` `{{P3_TITLE}}` `{{P3_CONTENT}}` `{{P3_SCORE}}` `{{P3_DESC}}` `{{P4}}`
