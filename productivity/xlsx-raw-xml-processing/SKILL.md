---
name: xlsx-raw-xml-processing
description: XLSX 文件原始XML操作技能 — 解包→修改→打包，保持原格式（样式、列宽、合并单元格等）。适用于需要格式保真度的xlsx编辑，以及openpyxl等库无法处理的复杂格式场景。
category: productivity
---

# XLSX 原始XML处理

## 核心原则：格式保真

xlsx 本质是 ZIP 包，内部包含 XML 文件。**必须用解包→修改XML→重新打包的方式，才能百分百保留原格式**。不要用 openpyxl、pandas、xlwings 等库改写，它们会重建文件导致丢格式（列宽、字体、边框、合并单元格等）。

## 工作流

```
解包原文件 → 修改 sheet1.xml / sharedStrings.xml → 更新 dimension → 重新打包
```

### 步骤1：解包

```python
import zipfile, shutil, os

work_dir = input_path + '.unpack'
if os.path.exists(work_dir):
    shutil.rmtree(work_dir)
with zipfile.ZipFile(input_path, 'r') as z:
    z.extractall(work_dir)
```

### 步骤2：读取 shared strings

```python
ss_path = os.path.join(work_dir, 'xl', 'sharedStrings.xml')
with open(ss_path, 'r', encoding='utf-8') as f:
    ss_xml = f.read()

items = re.findall(r'<si>(.*?)</si>', ss_xml, re.DOTALL)
ss_map = {}
for i, item in enumerate(items):
    t = re.search(r'<t[^>]*>(.*?)</t>', item, re.DOTALL)
    ss_map[i] = t.group(1).strip() if t else ''
```

### 步骤3：修改 sheet1.xml

```python
sheet_path = os.path.join(work_dir, 'xl', 'worksheets', 'sheet1.xml')
with open(sheet_path, 'r', encoding='utf-8') as f:
    xml = f.read()

# 获取命名空间前缀（ns0: / ns1: 等）
m = re.search(r'<(ns\d+:?)row', xml)
ns = m.group(1) if m else ''

# 提取 sheetData 区域
sd_open = '<%ssheetData>' % ns
sd_close = '</%ssheetData>' % ns
sd_start = xml.find(sd_open)
sd_end = xml.find(sd_close) + len(sd_close)
before_sd = xml[:sd_start]
after_sd = xml[sd_end:]

# 提取/修改行
row_re = re.compile(
    r'<%srow r="(\d+)"[^>]*>(.*?)</%srow>' % (re.escape(ns), re.escape(ns)),
    re.DOTALL
)
```

### 步骤4：更新 dimension

```python
last_row = max_row_after_changes
new_dim = 'A1:E%d' % last_row
before_sd = re.sub(
    r'<dimension ref="[^"]+"/>',
    '<dimension ref="%s"/>' % new_dim,
    before_sd, count=1
)
```

### 步骤5：重新打包

```python
if os.path.exists(out_path):
    os.remove(out_path)
with zipfile.ZipFile(out_path, 'w', zipfile.ZIP_DEFLATED) as zout:
    for folder, _, files in os.walk(work_dir):
        for fname in files:
            fp = os.path.join(folder, fname)
            zout.write(fp, os.path.relpath(fp, work_dir))
shutil.rmtree(work_dir)
```

## 常见操作模式

### A. 读取D列（或其他列）的 shared string 值

```python
# D列cell: <ns0:c r="D5" t="s"><ns0:v>40</ns0:v></ns0:c>
d_cell_re = re.compile(
    r'<(\\w+:c) r="D%d"[^>]*t="s"[^>]*>(.*?)</\\1c>' % rnum, re.DOTALL
)
dm = d_cell_re.search(row_xml)
if dm:
    vm = re.search(r'<(\\w+:v)>(\\d+)</\\1v>', dm.group(2))
    if vm:
        val = ss_map.get(int(vm.group(2)), '')
```

### B. 重新编排行号

```python
def renumber(old_rnum, new_rnum, row_xml):
    # 改行标签
    old_open = r'(<%srow r=")%d(")' % (ns, old_rnum)
    row_xml = re.sub(old_open, r'\\g<1>%d\\g<2>' % new_rnum, row_xml)
    # 改cell引用
    def fix_ref(m, _old=old_rnum, _new=new_rnum):
        col, r, rest = m.group(1), m.group(2), m.group(3)
        if r == str(_old):
            return '%s%d%s' % (col, _new, rest)
        return m.group(0)
    row_xml = re.sub(r'([A-Z]+)(\\d+)(["\\s/=>])', fix_ref, row_xml)
    return row_xml
```

### C. 合并两个xlsx（核心难点：sharedString索引重映射）

合并两个xlsx时需重新建立共享字符串索引表：
- 收集文件A和B用到的所有shared string索引
- 构建新索引表：先A的字符串，再B的字符串
- 两个映射字典：`idx_a->new` 和 `idx_b->new`
- 遍历所有行，用 `remap_ss_indices()` 替换旧索引为新索引

```python
def remap_ss_indices(row_xml, ns, old2new_map):
    """将row XML中的sharedString索引按映射表重写"""
    c_pattern = re.compile(r'<(\\w+:c) r="[^"]*"[^>]*t="s"[^>]*>.*?</\\1>', re.DOTALL)
    v_re = re.compile(r'<(\\w+:v)>(\\d+)</\\1v>')
    
    result = row_xml
    for cm in c_pattern.finditer(row_xml):
        cell_xml = cm.group(0)
        def replacer(m):
            prefix, idx, suffix = m.group(1), m.group(2), m.group(3)
            return '%s%d%s' % (prefix, old2new_map.get(int(idx), int(idx)), suffix)
        new_cell = v_re.sub(replacer, cell_xml)
        result = result.replace(cell_xml, new_cell)
    return result
```

### D. 写新 sharedStrings.xml

```python
def write_ss_xml(new_ss_texts):
    items = []
    for text in new_ss_texts:
        escaped = text.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')
        items.append('  <si><t>%s</t></si>' % escaped)
    header = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\\n'
    header += '<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="%d" uniqueCount="%d">\\n' % (count, count)
    return header + '\\n'.join(items) + '\\n</sst>'
```

## 已知陷阱

| 陷阱 | 说明 |
|------|------|
| **命名空间前缀** | 不同xlsx文件可能不同（ns0: / ns1: / 空前缀），不能用硬编码 |
| **shared string 索引** | 所有 `t="s"` 的 cell 中的 `<v>` 值指向 sharedStrings.xml 的索引，合并时必须重映射 |
| **行号引用** | cell 引用如 `C5`、`D5` 中的数字也会改变，需重写所有 `A-Z+数字` 引用 |
| **dimension** | 修改行数后必须更新 `<dimension ref="...">` 标签 |
| **t="s" vs 内联值** | 只有 `t="s"` 的 cell 才需要查 sharedStrings；其他 cell（数字、日期）直接读 `<v>` |
| **⚠️ t="s" 属性位置陷阱** | `t="s"` 属性在 cell 标签的 attrs 里（如 `<ns0:c r="D5" t="s">`），**不在** cell 内部内容（`<ns0:v>44</ns0:v>`）里。如果解析函数只接收 cell 内部内容，`'t="s"' in cell_xml` 永远为 False，导致 shared string 索引号被当作实际值返回。典型 bug：D 列值返回 `"44"`、`"121"` 等数字字符串而非实际文本。**修复**：将 attrs 也传给解析函数，或从 cell 完整 XML 中判断。 |
| **空行/隐藏行** | 部分xlsx含空行或隐藏行（如行2=标题，行3=空，行4=数据），操作时需明确data起始行 |
| **文件编码** | 始终用 utf-8，Windows 平台的 xlsx 可能有 BOM |

## 什么时候用原始XML vs openpyxl

| 场景 | 推荐方式 |
|------|----------|
| **格式必须完全保留**（列宽、颜色、边框、合并单元格、条件格式） | ✅ 原始XML |
| **新建xlsx，不依赖现有格式** | openpyxl 即可 |
| **只改数据不改格式** | ✅ 原始XML |
| **需要公式、图表** | openpyxl（但会丢部分格式）|
| 批量处理（100+文件） | ✅ 原始XML（无openpyxl依赖） |
| 调试和分析 xlsx 内容 | openpyxl（只读模式） |

## 参考案例

- `references/financial-accounting-phase5.md` — 财务网出纳帐Phase5工作流（两表合并、D列过滤、格式保真），含具体运行顺序和数据结构说明
