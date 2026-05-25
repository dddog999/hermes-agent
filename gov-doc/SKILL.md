---
name: gov-doc
description: "党政公文标准格式技能 — GB/T 9704-2012 公文规范。触发词：公文、党政公文、发文格式、公文标题"
version: "1.0"
source: "from OfficeChores/.codebuddy/skills/.bac/docx/"
---

# 党政公文标准格式 (gov-doc)

## 创建新文档（docx-js）

```javascript
const { Document, Packer, Paragraph, TextRun } = require('docx');
const doc = new Document({
  sections: [{
    properties: {},
    children: [
      new Paragraph({ children: [new TextRun("Hello World")] })
    ]
  }]
});
Packer.toBuffer(doc).then(buf => require('fs').writeFileSync('out.docx', buf));
```

**依赖**: `npm install -g docx`

---

## 公文格式（GB/T 9704-2012）

### 页面设置
- A4 (11906×16838 DXA)
- 上下边距: 3.7cm/3.5cm
- 左右边距: 2.8cm/2.6cm

```javascript
const PAGE = {
  width: 11906, height: 16838,
  margin: { top: 2103, bottom: 1984, left: 1587, right: 1474 }
};
```

### 字体规格
- 字体: 仿宋_GB2312
- 字号: 三号 (16pt = 32 half-points)
- 行距: 28磅（固定值，560 DXA）
- 首行缩进: 2字符

```javascript
const FONT_NAME = "仿宋_GB2312";
const FONT_SIZE = 32; // 三号
const LINE_SPACING = { value: 560, rule: "exact" }; // 28磅
const INDENT = { firstLine: 680 }; // 2字符
```

### 公文标题（居中，黑体二号）
```javascript
new Paragraph({
  alignment: AlignmentType.CENTER,
  spacing: { after: 200 },
  children: [new TextRun({ text: "标题", bold: true, size: 36, font: "黑体" })]
})
```

### 主送机关（左对齐）
```javascript
new Paragraph({
  alignment: AlignmentType.LEFT,
  spacing: { before: 200, after: 200 },
  children: [new TextRun({ text: "致：XXX", size: FONT_SIZE, font: FONT_NAME })]
})
```

### 正文段落
```javascript
new Paragraph({
  spacing: { line: LINE_SPACING.value, lineRule: "exact" },
  indent: INDENT,
  children: [new TextRun({ text: "正文内容...", size: FONT_SIZE, font: FONT_NAME })]
})
```

### 一级标题（黑体）
```javascript
new Paragraph({
  spacing: { before: 200, after: 100 },
  children: [new TextRun({ text: "一、标题", bold: true, size: FONT_SIZE, font: "黑体" })]
})
```

---

## 表格

### 公文表格样式
- 1磅黑色边框
- 标题行淡蓝底色 (#D5E8F0)

```javascript
new Table({
  width: { size: 9022, type: WidthType.DXA }, // 内容宽度
  columnWidths: [3000, 6022],
  rows: [
    new TableRow({
      tableHeader: true,
      children: [
        new TableCell({
          width: { size: 3000, type: WidthType.DXA },
          shading: { fill: "D5E8F0", type: ShadingType.CLEAR },
          margins: { top: 80, bottom: 80, left: 120, right: 120 },
          children: [new Paragraph({ children: [new TextRun({ text: "表头", bold: true, size: FONT_SIZE, font: FONT_NAME })] })]
        }),
        // 更多单元格...
      ]
    })
  ]
});
```

### 关键规则
- **必须用 WidthType.DXA**，不用 PERCENTAGE
- 表格宽度 = 所有 columnWidths 之和
- 每个单元格 width 必须对应 columnWidth
- 用 `ShadingType.CLEAR` 不用 SOLID

---

## 图片

```javascript
new Paragraph({
  children: [new ImageRun({
    type: "png", // 必须指定
    data: fs.readFileSync("image.png"),
    transformation: { width: 200, height: 150 },
    altText: { title: "Title", description: "Desc", name: "Name" }
  })]
})
```

---

## 分页符

```javascript
new Paragraph({ children: [new PageBreak()] })
```

---

## 编辑现有文档

### 1. 解包
```bash
python scripts/office/unpack.py document.docx unpacked/
```

### 2. 编辑XML
在 `unpacked/word/document.xml` 中编辑，用Edit工具直接替换。

**跟踪修订（插入）**:
```xml
<w:ins w:id="1" w:author="Claude" w:date="2025-01-01T00:00:00Z">
  <w:r><w:t>新文本</w:t></w:r>
</w:ins>
```

**跟踪修订（删除）**:
```xml
<w:del w:id="2" w:author="Claude" w:date="2025-01-01T00:00:00Z">
  <w:r><w:delText>被删除的文本</w:delText></w:r>
</w:del>
```

**批注**:
```bash
python scripts/comment.py unpacked/ 0 "批注内容"
```
然后在 document.xml 添加标记（见SKILL.md完整版）

### 3. 打包
```bash
python scripts/office/pack.py unpacked/ output.docx --original document.docx
```

---

## 辅助脚本

### gov_doc.js - 公文生成器
```bash
node memory/scripts/gov_doc.js
```
输出: `memory/output/情况说明_板尾园经济社_公文格式.docx`

修改 `docConfig` 对象自定义内容。

---

## 关键规则

1. **永远用 WidthType.DXA** - 不用 PERCENTAGE
2. **永远用单独的 Paragraph** - 不用 `\n` 换行
3. **PageBreak 必须在 Paragraph 内**
4. **ImageRun 必须指定 type**
5. **表格需要双重宽度** - columnWidths 数组 + 每个单元格 width
6. **单元格 margin 是内边距** - 不增加单元格宽度

---

## 依赖

- **pandoc**: 文本提取
- **docx**: `npm install -g docx`
- **LibreOffice**: PDF转换
- **Poppler**: `pdftoppm`
