---
name: ocr-fallback-tesseract
description: 当 OCR API token 不可用时，使用 Tesseract 作为备选方案进行中文 OCR 识别
category: productivity
---

# Tesseract OCR 备选方案

## 使用场景
- PaddleOCR/GLM-4V 等 API token 不可用或过期
- 需要离线 OCR 识别
- 快速识别单页文档

## 安装

```bash
sudo apt-get install -y tesseract-ocr tesseract-ocr-chi-sim
```

## 命令行用法

```bash
# 基本用法
tesseract input.png output -l chi_sim

# 指定 DPI（提高识别率）
tesseract input.png output -l chi_sim --dpi 300
```

## Python 调用（无需 pytesseract）

直接用 subprocess 调用命令行，避免 PIL 兼容性问题：

```python
import subprocess

img_path = "/path/to/image.png"
output_path = "/path/to/output"

cmd = ["tesseract", img_path, output_path, "-l", "chi_sim"]
result = subprocess.run(cmd, capture_output=True, text=True)

# 读取结果
with open(f"{output_path}.txt", "r", encoding="utf-8") as f:
    text = f.read()
```

## PDF 页面提取 + OCR 完整流程

```python
import subprocess
import os

# 1. 提取 PDF 指定页为 PNG（使用 pdftoppm，poppler-utils 自带）
pdf_path = "/path/to/document.pdf"
output_dir = "/tmp/ocr_pages"
os.makedirs(output_dir, exist_ok=True)

cmd = [
    "pdftoppm", "-png",
    "-f", "5",    # 起始页
    "-l", "5",    # 结束页
    "-r", "200",  # DPI
    pdf_path,
    f"{output_dir}/page"
]
subprocess.run(cmd)

# 2. OCR 识别
img_path = f"{output_dir}/page-005.png"
tesseract_cmd = ["tesseract", img_path, f"{output_dir}/result", "-l", "chi_sim"]
subprocess.run(tesseract_cmd)

# 3. 读取结果
with open(f"{output_dir}/result.txt", "r", encoding="utf-8") as f:
    ocr_text = f.read()
```

## 坑点

1. **不要用 pytesseract** - PIL/Pillow 版本冲突会导致 `_imaging` 导入错误，直接用 subprocess 调命令行
2. **中文识别率** - 对于扫描版 PDF，建议 DPI ≥ 200
3. **输出文件** - tesseract 自动添加 `.txt` 后缀，不要手动加
4. **中英文混排** - 如需同时识别中英文，用 `chi_sim+eng`

## 识别质量对比

| 工具 | 中文识别 | 安装难度 | 需要网络 |
|------|----------|----------|----------|
| PaddleOCR API | ★★★★★ | 低 | 是 |
| GLM-4V | ★★★★☆ | 低 | 是 |
| Tesseract | ★★★☆☆ | 中 | 否 |
