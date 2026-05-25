---
name: docx-template-fill
description: DOCX 模板填充完全指南 — 保留 DrawingML 文本框、跨 run 标记替换、OCR 批量生成。适用于 python-docx/lxml 会破坏文本框、VML 等复杂对象的情况。
category: productivity
---

# DOCX 模板填充完全指南

## 何时使用
用 JSON/Excel 数据填充带 `{{MARKER}}` 标记的 DOCX 模板时使用。

## 核心问题
python-docx 的 `doc.save()` 会破坏 DrawingML 结构（如文本框 `mc:AlternateContent`、VML 图片等）。lxml 解析+序列化也会导致命名空间匹配异常，造成文本框内容丢失或字体属性变化。

## 正确方案：纯字符串替换

不通过 python-docx / lxml 操作 XML，直接对 zip 中的 `document.xml` 做字符串替换：

```python
import zipfile, re, os
from zipfile import ZipFile, ZIP_DEFLATED

MARKER_ANY = re.compile(r'\{\{P[1-4](_TITLE|_CONTENT|_SCORE|_DESC)?\}\}')

def fill_docx(template_path, out_path, marker_map):
    """
    marker_map: dict, e.g. {'{{P1}}': '值1', '{{P2}}': '值2'}
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
                text = MARKER_ANY.sub('', text)
                data = text.encode('utf-8')
            zout.writestr(item, data)
    os.replace(tmp, out_path)
```

## 标记规范

**使用 `{{P?}}` 双花括号配对标记**。

| 标记 | 含义 | 模板写法 | 替换结果 |
|------|------|----------|----------|
| `{{P1}}` | 大序号 | `{{P1}}参考文字{{P1}}` | p1 值 |
| `{{P2}}` | 子序号 | `({{P2}}1-1{{P2}})` | (3-15) |
| `{{P3}}` | 内容 | `{{P3}}参考文字{{P3}}` | OCR 提取内容 |
| `{{P4}}` | 类别名 | `{{P4}}参考文字{{P4}}` | 类别名称 |
| `{{P3_TITLE}}` | P3标题 | `{{P3_TITLE}}` | 【X-Y 类别】 |
| `{{P3_CONTENT}}` | P3内容标准 | `{{P3_CONTENT}}` | 内容标准... |
| `{{P3_SCORE}}` | P3得分 | `{{P3_SCORE}}` | 8 |
| `{{P3_DESC}}` | P3自评简述 | `{{P3_DESC}}` | 村中实行... |

**为什么用双花括号（不用尖括号 `<P?>`）：**
- `{{}}` XML 安全，不会被转义为 `&lt;&gt;`
- `{` `}` 是单字符，Word 不会拆分到不同 run
- 配对标记中"参考文字"保留原始字体格式，脚本替换时继承第一个 run 的 rPr

**模板制作方法：**
1. 在 Word 中正常排版，选中要替换的文字
2. 在前后加标记：`{{P1}}这是参考文字{{P1}}`
3. 参考文字保留原始格式（字体/字号/加粗），脚本会继承

## 已知问题

### 1. mc:AlternateContent 破坏（文本框丢失）
- **现象**：python-docx 保存后文本框变为空或位置跑掉
- **原因**：python-docx 的 `save()` 调用 lxml 序列化时，AlternateContent 内的命名空间处理异常
- **解决**：用纯字符串替换，绕过长节点树操作

### 2. lxml findall 漏掉深层嵌套 t 元素
- **现象**：`para.findall('{NS}t')` 找不到文本框内的 `w:t`，但 `iter()` 能找到
- **原因**：AlternateContent 的 Choice/Fallback 结构导致命名空间路径不连续
- **解决**：用字符串替换，不需要遍历节点

### 3. 标记被拆到多个 XML run
Word 的格式化会导致标记文本跨多个 `<w:r>` 元素：
```xml
<!-- 你以为的 -->
<w:r><w:t>{{P3}}内容{{P3}}</w:t></w:r>
<!-- 实际的 -->
<w:r><w:t>{{</w:t></w:r>
<w:r><w:t>P3</w:t></w:r>
<w:r><w:t>}}内容</w:t></w:r>
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

### 4. P2 双括号问题
**问题**：模板已有 `(` `)`，`((bid))` 出现。
**解决**：替换 `{{P2}}` 为 `bid`，不要再加括号。

### 5. P3 字段解析（典型村项目）
p3 原始数据格式：
```
## 【1-1 环境整治】

内容标准：...。(8分)

自评得分：8 分

## 自评情况简述

村中实行...
```
需要分别提取 title/score/content/desc：
```python
def parse_p3(p3_str):
    title = re.search(r'##\s*【([^】]+)】', p3_str).group(1).strip()
    score = re.search(r'自评得分[：:]\\s*(\\d+)', p3_str).group(1)
    cs = p3_str.find('内容标准：')
    ss = p3_str.find('自评得分：')
    content = p3_str[cs+5:ss].strip()
    content = re.sub(r'[（(]\\d+分[))]', '', content).strip()
    ds = p3_str.rfind('自评情况简述')
    desc = p3_str[ds+7:].strip()
    return title, score, content, desc
```

## 模板字体修改（直接改 XML）
如果需要修改某个标记的字体/字号，用字符串替换对应的 rPr 块：
```python
with zipfile.ZipFile(template_path, 'r') as zin:
    raw = zin.read('word/document.xml').decode('utf-8')

idx = raw.find('{{P4}}')
r_open = raw.rfind('<w:r>', 0, idx)
rpr = raw.find('<w:rPr>', r_open, idx)
rpr_end = raw.find('</w:rPr>', rpr) + 8  # 找到结束位置
# ...字符串替换 rpr 块内的字体属性 ...
```
不要用 python-docx 修改字体，会破坏其他结构。

## 批量生成流程（典型村项目）

### 脚本结构

| 脚本 | 用途 |
|------|------|
| `build_tpl_v*.py` | 复制源模板，修复双标记、中括号等问题，输出干净模板 |
| `fill_v*.py` | 加载 all_data.json，逐条替换标记，输出批量文件 |
| `verify_v*.py` | 三级验证：数据级/XML级/内容级 |

### 批量生成代码
```python
import shutil
for item in items:
    out_file = f"output/{item['p2']}_{item['p4']}.docx"
    shutil.copy2(template, out_file)
    doc = Document(out_file)
    # ... 替换标记 ...
    doc.save(out_file)
```

### 验证清单
生成后必查：
1. `re.findall(r'<w:t[^>]*>([^<]+)</w:t>', raw)` 查看所有文本节点
2. 确认 `mc:AlternateContent` 仍存在（文本框关键）
3. 检查字体 rPr：`re.findall(r'w:ascii="([^"]+)"', raw[:rpr_end])`
4. 残留标记：`re.findall(r'\{\{P\d+\}\}', ''.join(all_texts))`

## 调试技巧

用原始字节查找：
```python
with ZipFile(docx_path, 'r') as z:
    raw = z.read('word/document.xml').decode('utf-8')
idx = raw.find('{{P2}}')
print(raw[idx-200:idx+100])
```

用 zipfile + lxml 联合分析：
```python
from lxml import etree
W = '{http://schemas.openxmlformats.org/wordprocessingml/2006/main}'
WPS = '{http://schemas.microsoft.com/office/word/2010/wordprocessingShape}'
for elem in root.iter():
    if elem.tag == f'{WPS}txbx':
        t = elem.find(f'{W}txbxContent/{W}p/{W}r/{W}t')
```

## zipfile 备用方案（lxml 不可用时）

当 python-docx 因 lxml 安装问题无法导入时，直接用 zipfile 操作：

```python
import zipfile, shutil

shutil.copy(template_path, output_path)

with zipfile.ZipFile(output_path, 'a') as docx_zip:
    with docx_zip.open('word/document.xml') as f:
        xml_content = f.read().decode('utf-8')
    
    for marker, value in replacements.items():
        value_escaped = value.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')
        xml_content = xml_content.replace(marker, value_escaped)
    
    docx_zip.writestr('word/document.xml', xml_content)
```

**Pitfalls：**
- 替换文本中的 `&`, `<`, `>` 必须转义
- 此方法不处理跨 run 问题，适合标记在单个 run 中的情况
