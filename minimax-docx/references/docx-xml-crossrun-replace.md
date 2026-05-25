# Docx Xml Crossrun Replace
> Archived `docx-xml-crossrun-replace` — demoted as verbatim reference from minimax-docx umbrella.

---


# DOCX XML 跨 Run 标记替换

## 问题
python-docx 的 `paragraph.text` 替换对跨 run 的标记无效。Word 经常把 `<P1>` 这样的标记拆成多个 XML `<w:t>` 节点。

## 解决方案

直接操作 XML：

```python
from docx import Document
from lxml import etree

def replace_xml_markers(filepath, output_path, replacements):
    """替换 docx 中跨 run 的标记。replacements: dict 如 {"<P1>": "内容", "<P2>": "编号"}"""
    doc = Document(filepath)
    
    for para in doc.paragraphs:
        # 收集段落所有 run 的 XML
        full_xml = etree.tostring(para._p, encoding='unicode')
        
        for marker, value in replacements.items():
            if marker not in full_xml:
                continue
            
            # 1. 清理所有 run 的样式干扰
            for run in para.runs:
                rpr = run._element.find(qn('w:rPr'))
                if rpr is not None:
                    for child in list(rpr):
                        if child.tag not in (qn('w:rFonts'), qn('w:sz'), qn('w:b'), qn('w:i')):
                            rpr.remove(child)
            
            # 2. 清理空 run
            for run in para.runs:
                if not run.text.strip():
                    run._element.getparent().remove(run._element)
            
            # 3. 找到包含标记开头的 run
            target_run = None
            for run in para.runs:
                if marker[:2] in run.text:  # 用前2个字符匹配
                    target_run = run
                    break
            
            if target_run:
                # 4. 删除标记，只留替换值
                for run in para.runs:
                    if run is not target_run:
                        run.text = run.text.replace(marker, '')
                target_run.text = target_run.text.replace(marker, value)
    
    doc.save(output_path)
```

## 关键点
1. **标记定位**：用 `marker[:2]`（如 `<P`）在各 run 中查找，因为标记可能被拆分
2. **样式清理**：清除可能干扰替换的 run 样式（保留字体、字号、加粗、斜体）
3. **空 run 清理**：删除空 run 避免干扰
4. **保留格式**：在目标 run 中替换，保留原有样式

## 常见标记模式
- `<P1>` - 长段落内容
- `<P2>` - 编号
- `<P3>` - 标题+内容（可能被拆成 `<P` `3` `>` 三个 run）

## 测试验证
替换后检查 XML 中不再包含标记原文：
```python
for para in doc.paragraphs:
    xml = etree.tostring(para._p, encoding='unicode')
    for marker in ['<P1>', '<P2>', '<P3>']:
        assert marker not in xml, f"标记 {marker} 未替换！"
```
