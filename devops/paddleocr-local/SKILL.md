---
name: paddleocr-local
description: PaddleOCR 本地部署技能 - PP-OCRv5 通用 OCR + PP-StructureV3 文档解析。适用于图片文字识别、PDF/图片转 Markdown、表格识别等场景。
---

# PaddleOCR 本地部署技能

## 安装

```bash
# 基础 OCR（PP-OCRv5）
pip install paddleocr

# 文档解析（PP-StructureV3，包含 PP-OCRv5）
pip install "paddleocr[doc-parser]"

# transformers 引擎依赖（CPU 环境必须）
pip install transformers torch torchvision
```

**依赖**: Python 3.8+，自动下载模型到 `~/.paddlex/official_models/`

## 推理引擎选择

| 引擎 | 说明 | 适用场景 |
|------|------|----------|
| `paddle_static` (默认) | 飞桨静态图，最快 | 有 paddlepaddle 且无 oneDNN bug 时 |
| `paddle_dynamic` | 飞桨动态图 | 部分模型仅支持动态图 |
| `transformers` | HuggingFace 后端 | **CPU 环境首选**，绕过 oneDNN bug |

**⚠️ 重要**: paddlepaddle 3.3.1 有 oneDNN bug（CPU 推理报错 `ConvertPirAttribute2RuntimeAttribute`），**CPU 环境必须用 `engine="transformers"`**。

## PP-OCRv5 通用 OCR

```python
from paddleocr import PaddleOCR

ocr = PaddleOCR(
    engine='transformers',  # CPU 环境必须
    use_doc_orientation_classify=False,
    use_doc_unwarping=False,
    use_textline_orientation=False,
)
result = ocr.predict("image.png")
for res in result:
    # transformers 引擎返回 dict，不是对象
    texts = res.get('rec_texts', [])
    scores = res.get('rec_scores', [])
    for text, score in zip(texts, scores):
        print(f'识别: {text}  (置信度: {score:.3f})')
```

## PP-StructureV3 文档解析

```python
from paddleocr import PPStructureV3

pipeline = PPStructureV3(
    use_doc_orientation_classify=False,
    use_doc_unwarping=False,
    use_textline_orientation=False,
)
output = pipeline.predict("document.png")  # 或 PDF 文件
for res in output:
    res.print()
    res.save_to_json("output")
    res.save_to_markdown("output")
    res.save_to_word("output")
```

**轻量模式（CPU 快速加载）**:

```python
pipeline = PPStructureV3(
    layout_detection_model_name='PP-DocLayout-S',  # 5MB 轻量版面检测
    use_doc_orientation_classify=False,
    use_doc_unwarping=False,
    use_textline_orientation=False,
    use_table_recognition=False,      # 跳过表格识别加速
    use_formula_recognition=False,    # 跳过公式识别加速
)
```

**PDF 转 Markdown（多页合并）**:

```python
from pathlib import Path
from paddleocr import PPStructureV3

pipeline = PPStructureV3()
output = pipeline.predict("document.pdf")

markdown_list = []
markdown_images = []
for res in output:
    md_info = res.markdown
    markdown_list.append(md_info)
    markdown_images.append(md_info.get("markdown_images", {}))

markdown_texts = pipeline.concatenate_markdown_pages(markdown_list)

with open("output.md", "w", encoding="utf-8") as f:
    f.write(markdown_texts)
```

## 模型选择

### PP-OCRv5 默认模型
- 检测: `PP-OCRv5_server_det`
- 识别: `PP-OCRv5_server_rec`（中英文）

### PP-StructureV3 核心模型
| 模块 | 默认模型 | 大小 | 说明 |
|------|----------|------|------|
| 版面检测 | `PP-DocLayout-L` | 124MB | 20 类版面元素 |
| 文本检测 | `PP-OCRv5_server_det` | - | 继承自 OCR 产线 |
| 文本识别 | `PP-OCRv5_server_rec` | - | 继承自 OCR 产线 |
| 表格结构 | `SLANeXt_wired/wireless` | 351MB | 有线/无线表格 |
| 公式识别 | `UniMERNet` | - | 数学公式 |

### 轻量模型（低显存/CPU）
- 版面检测: `PP-DocLayout-S` (5MB) 或 `PP-DocLayout-M` (23MB)
- 文本检测: `PP-OCRv5_mobile_det`
- 文本识别: `PP-OCRv5_mobile_rec`

## 常见问题

1. **oneDNN bug** (paddlepaddle 3.3.1): CPU 环境必须用 `engine="transformers"`
2. **transformers 引擎结果格式**: 返回 dict，用 `res['rec_texts']` 取文本，不支持 `res.print()`
3. **模型下载慢**: 设置 `PADDLE_PDX_DISABLE_MODEL_SOURCE_CHECK=1` 跳过检查
4. **内存不足**: 使用 mobile 模型或 PP-DocLayout-S，关闭不需要的子模块
5. **PDF 处理**: 每页单独处理，用 `concatenate_markdown_pages` 合并

## 参考文档

- `references/online_api_fallback.md` — 在线 API fallback 详细参数和测试记录
- 本地文档: `wiki/raw/paddleocr-docs/`
- 安装: `docs_version3.x_installation.md`
- OCR 使用: `docs_version3.x_pipeline_usage_OCR.md`
- PP-StructureV3 使用: `docs_version3.x_pipeline_usage_PP-StructureV3.md`
