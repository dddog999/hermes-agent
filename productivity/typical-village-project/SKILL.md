---
name: typical-village-project
description: 典型村项目工作规范。处理 OfficeChores/data/典型村 相关任务时自动加载。
license: MIT
metadata:
  version: "1.3"
  category: productivity
---

# 典型村项目

## 项目路径
`C:\Users\kangle\OfficeChores\data\典型村\`

## 核心文件
| 文件 | 说明 |
|------|------|
| `计划进度.md` | **必须维护** — 任务计划与进度追踪 |
| `extracted/all_data.json` | 30 条数据源 |
| `extracted/ocr_results.json` | OCR 结果 |
| `extracted/src/fill_template.py` | 填充脚本（使用 `{{P?}}` 标记） |
| `extracted/clean_markers.py` | 标记清理工具 |

## 强制规范

### 📋 计划进度维护规则
1. **每次操作前后**，必须读取 `计划进度.md`
2. **开始任务前**：在计划中记录本次目标
3. **完成步骤后**：立即更新进度（打勾 ✅ 或修改状态）
4. **发现问题时**：记录到计划的"问题/待办"部分
5. **任务结束时**：总结本次进展，规划下一步

### 标记规范
- 使用 `{{P?}}` 双花括号配对标记，不用 `<P?>` 尖括号
- 模板格式：`{{P1}}参考文字{{P1}}`
- 填充后必须通过 `clean_markers.py` 兜底清理
- 验证：XML 扫描确认无残留 `{{P\\d+}}` 或 `<P\\d+>`

### 脚本注意事项
- `fill_template.py` 中 `final_clean_markers` 函数：`ZipInfo` 对象没有 `endswith` 方法，需用 `item.filename.endswith('.xml')`
- **正则表达式修复**：清理标记时使用 `re.compile(r'\{\{P\d+\}\}')` 而不是 `re.compile(r'\\{\\{P\\d+\\}\\}')`
- **文本替换时机**：在数据预处理阶段替换特定文本（如"云汉"→"康乐"），而不是生成后处理
- 验证脚本：可创建 `validate_docx.py` 检查残留标记和 P3 内容长度
- P3 内容验证标准：建议 ≥100 字符，但 OCR 结果可能较短（如 5-25 条目 82 字符）
- **清理函数验证**：清理后应立即验证，确保标记确实被删除

### 数据自检规范
- P3 内容必须包含"内容标准"和"自评"关键词
- P3 长度不应小于 10 字符
- 不应包含 `{{P?}}` 或 `<P?>` 残留标记

### 跨会话记忆（OpenViking）
- **确认结论**（如"X已修正"、"Y已验证通过"）必须用 `viking_remember` 存储
- category 用 `case`（案例/状态记录）
- OpenViking 按相关性自动注入上下文（`[memory-context]` 块），但不保证全部注入
- 为确保召回，开始典型村任务时先 `viking_search("典型村")` 查询历史结论

## 模板结构与标记系统（2026-04-21 更新）

### Para3 精细标记系统
模板 `典型村精细模板_v7.docx` 使用 4 个独立标记：

| 标记 | 段落 | 字体 | 用途 |
|------|------|------|------|
| `{{P3_TITLE}}` | Para 7 | 仿宋 | 编号+类别标题 |
| `{{P3_CONTENT}}` | Para 8 | **黑体标签**+仿宋内容 | 内容标准正文 |
| `{{P3_SCORE}}` | Para 9 | **黑体标签**+仿宋内容 | 自评得分 |
| `{{P3_DESC}}` | Para 11 | 仿宋 | 自评情况简述正文 |

### 关键模板修复
1. **Para3 双重 `{{P1}}` 标记**：模板中 Para3 为 `{{P1}}固定文本`，需确保只有一个 `{{P1}}`
2. **Para22 括号问题**：模板中 Para22 为 `({{P2}})`，填充时 `{{P2}}` 替换为 `bid`（不带括号）
3. **P2 文本框**：Para6 txbx 中 `{{P2}}` 替换为 `bid`

### 填充脚本关键逻辑
```python
# P2 替换：注意模板已有括号
# Para6 txbx: {{P2}} → bid
# Para22: ({{P2}}) → (bid)

# P1 截断：在 all_data.json 中截断，不是 Para3
def truncate_p1(text, max_len=100):
    punct = '。！？'
    last_pos = -1
    for i in range(len(text)):
        if text[i] in punct and i <= max_len:
            last_pos = i
    if last_pos > 0:
        return text[:last_pos + 1]
    return text[:max_len]

# P3 解析：兼容中英文冒号
def find_colon_pos(l):
    for cp in ('：', ':'):
        if cp in l:
            return l.index(cp)
    return -1
```

### 验证脚本关键点
- **P1 长度**：检查 all_data.json 中的 p1 字段，不是 Para3 总长度
- **Para3 组成**：`{{P1}}` + 固定文本（43字符），总长 = P1长度 + 43
- **引号差异**：模板固定文本用中文引号 `"`，验证时需匹配

## 常见问题与解决方案

### 4. 标记被分割到多个 XML 节点
**问题**：`{{P3}}` 在 Word 中被拆成多个 `<w:r>` 节点：`{{` + `P` + `3` + `}}`
**诊断**：`re.search(r'\{\{P3\}\}', xml_text)` 找不到，但分段搜索能找到
**解决方案**：
```python
# 方案1：在完整 XML 字符串上用正则跨元素查找
# 方案2：逐 run 检查，识别包含标记片段的节点并删除
for para in body.iter(f'{ns_w}p'):
    for r in para.iter(f'{ns_w}r'):
        for t in r.iter(f'{ns_w}t'):
            if t.text and any(marker in t.text for marker in ['{{', 'P', '}}']):
                # 检查是否为标记片段
                t.text = re.sub(r'\{\{P\d+\}\}', '', t.text)
```

### 5. Para22 双重括号 `((bid))`
**根因**：模板 Para22 为 `({{P2}})`，填充脚本替换为 `((bid))`
**解决方案**：
- 模板：Para22 保持 `({{P2}})` 格式
- 填充脚本：`{{P2}}` 替换为 `bid`（不带括号）
```python
# 正确
t.text = t.text.replace('{{P2}}', bid)  # bid = "1-1"
# 结果: (1-1) ✓

# 错误
t.text = t.text.replace('{{P2}}', f'({bid})')
# 结果: ((1-1)) ✗
```

### 6. P3 解析：空行打断描述捕获
**问题**：`自评情况简述` 后有空行，导致 `in_desc=False`，后续内容丢失
**解决方案**：空行不重置 `in_desc` 状态
```python
for line in lines:
    line = line.strip()
    if not line:
        continue  # 跳过空行，但不重置 in_desc
    # ... 其他逻辑
```

### 7. lxml indent 问题
**问题**：`etree.tostring(doc, pretty_print=True)` 后 Word 报错
**根因**：`pretty_print=True` 插入不合规空白字符
**解决方案**：`pretty_print=False`

### 8. lxml ElementMaker 闭包问题
**问题**：循环中使用 `emaker.tag()` 会累积状态
**解决方案**：不要把 emaker 放在循环体内，或每次循环重置

### 9. P3 自评得分位置有两种格式（2026-04-22）
**问题**：`parse_p3` 解析时假设自评得分在"## 自评情况简述"之前，但 OCR 数据有两种格式：
- 格式A（score在简述前）：`## 【1-1 环境整治】` / `内容标准：...` / `自评得分：8 分` / `## 自评情况简述` / desc
- 格式B（score在简述后）：`## 【1-3 环境整治】` / `内容标准：...` / `## 自评情况简述` / `自评得分：3 分` / desc

**诊断**：`fill_template.py` 输出发现 Para9 内容混入 Para11（如"自评得分：3 分"跑到描述段落）

**解决方案**：判断 score_idx 是否等于 desc_idx + 1
```python
if score_idx == desc_idx + 1:
    # 格式B：score在desc之后
    score = re.sub(r'自评得分[：:]\s*', '', lines[score_idx]).strip()
    desc_lines = [l for l in lines[score_idx + 1:] if l]
elif desc_idx > 1:
    # 格式A：score在desc之前
    score = re.sub(r'自评得分[：:]\s*', '', lines[score_idx]).strip()
    desc_lines = lines[desc_idx + 1:]
```

### 2. 特定文本替换
**需求**：将数据中的特定文本替换为其他内容
**最佳实践**：在数据预处理阶段进行替换，而不是生成后处理
```python
def replace_yunhan_with_kangle(text):
    """将'云汉'替换为'康乐'"""
    return text.replace('云汉', '康乐')

# 在生成前替换
p1 = replace_yunhan_with_kangle(p1)
p3 = replace_yunhan_with_kangle(p3)
p4 = replace_yunhan_with_kangle(p4)
```

### 3. 验证脚本
创建验证脚本检查docx文件：
```python
import os, re
from zipfile import ZipFile

def validate_docx(fpath):
    """验证docx文件中的标记和特定文本"""
    with ZipFile(fpath, 'r') as z:
        if 'word/document.xml' in z.namelist():
            data = z.read('word/document.xml')
            text = data.decode('utf-8')
            
            # 检查标记
            marker_pattern = re.compile(r'\{\{P\d+\}\}')
            markers = marker_pattern.findall(text)
            
            # 检查特定文本
            yunhan_count = text.count('云汉')
            kangle_count = text.count('康乐')
            
            return {
                'markers': len(markers),
                'yunhan': yunhan_count,
                'kangle': kangle_count
            }
```

## 脚本版本管理
- `fill_template.py`：原始版本
- `fill_template_fixed.py`：修复ZipInfo问题
- `fill_template_fixed2.py`：添加文本替换
- `fill_template_fixed3.py`：修复正则表达式问题
- `fill_v6_wsl.py`：WSL路径，修复Para22括号

### 最终脚本清单（2026-04-22）
| 脚本 | 作用 |
|------|------|
| `典型村精细模板_v7.docx` | 修复后模板（sz=16，4标记结构） |
| `extracted/src/fill_template.py` | 填充脚本（适配v7四标记+双格式p3） |
| `extracted/output/` | 最终生成的docx文件（30个） |

## 计划进度.md 维护规范

### 文档结构（时间倒序）
```markdown
# 典型村填充任务 - 计划进度

## 第一章：进度 (最后更新：YYYY-MM-DD)
### 当前状态：✅/⏳/❌
#### 待办事项
#### 已完成事项

## 第二章：计划和目标
## 第三章：执行过程和结果
## 第四章：调试经验
```

### 渐进式读取
- AI 先读第一章了解当前状态
- 按需深入其他章节
- 节省 token，避免一次性加载全部内容

### 状态标记
- ✅ 完成
- ⏳ 进行中
- ❌ 失败
- ⚠️ 注意

## 输出目录
- `extracted/output/`：最终生成的docx文件
- `extracted/test_output/`：测试文件
- 文件命名格式：`{P2}_{P4}.docx`（如 `1-1_环境整治.docx`）
### 10. Word序号符号清理（2026-04-22）
**问题**：Word源文档中的①②③④⑤⑥等圈号序号渗入到JSON数据（`all_data.json`、`all_data_filled.json`、`P1_具体内容.md`）

**诊断**：`grep '[①②③④⑤⑥⑦⑧⑨⑩]' extracted/all_data.json` 发现20处匹配

**解决方案**：用正则批量清除
```python
import re
files = ['all_data.json', 'all_data_filled.json', 'P1_具体内容.md']
for fname in files:
    content = re.sub(r'[①②③④⑤⑥⑦⑧⑨⑩]', '', open(fname).read())
    open(fname, 'w').write(content)
```

### 11. pageBreakBefore 分页符（2026-04-22）
**需求**：`【{{P3_TITLE}}】` 段落（Para5）前面需要有分页符

**解决方案**：在模板中添加 `pageBreakBefore=True`
```python
pPr = p.find(f'{ns_w}pPr')
if pPr is None:
    pPr = etree.Element(f'{ns_w}pPr')
    p5.insert(0, pPr)
pageBreakBefore = etree.Element(f'{ns_w}pageBreakBefore')
pPr.insert(0, pageBreakBefore)
```

### 12. MiniMax API 重试间隔（2026-04-22）
**问题**：MiniMax HTTP 529 限流时重试间隔太短（base_delay=2.0）

**修改位置**：`/home/kangle/.hermes/hermes-agent/run_agent.py:10814`
```python
# 改前
jittered_backoff(retry_count, base_delay=2.0, max_delay=60.0)
# 改后
jittered_backoff(retry_count, base_delay=15.0, max_delay=120.0)
```
新间隔：attempt1 ~15-22s, attempt2 ~30-45s, attempt3 ~60-90s

### 模板版本（2026-04-22）
| 版本 | 说明 |
|------|------|
| `典型村精细模板_v8.docx` | 最新：4标记(P3_TITLE/CONTENT/SCORE/DESC)，Para5有pageBreakBefore |
| `典型村精细模板_v7.docx` | 4标记结构，sz=16，Para5无pageBreakBefore |
