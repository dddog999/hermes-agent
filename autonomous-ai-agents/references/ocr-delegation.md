# OCR 任务委派参考

## 什么任务适合委派

PDF→xlsx、图片批量OCR、表格提取等**多步骤数据处理任务**适合直接委派给子代理，而不是自己逐页手动处理。

## 委派示例

```python
delegate_task(
    context="""
PDF 路径: /path/to/input.pdf
Token: xxx（从 .env 读取）
API: https://of096elflbvcx5h1.aistudio-app.com/layout-parsing
超时: 120秒
输出: /path/to/output.xlsx
    """,
    goal="""
将 PDF 转换为 xlsx：
1. pdf2image 转图片（dpi=150）
2. PaddleOCR PP-StructureV3 API OCR 每页（超时120s）
3. 每页 OCR 后保存到 /tmp/ocr_results.json（断点续传）
4. 解析结果生成 xlsx
5. 验证输出文件
    """,
    toolsets=["terminal", "file"],
    acp_command="qwen",  # 或 codebuddy
    acp_args=["--acp", "--stdio", "--model", "minimax-m2.7"]
)
```

## 关键上下文要传递

- Token 值（不要让子代理自己从 .env 找）
- API URL 和认证格式
- 超时设置
- 输入输出路径
- 中间结果保存路径（断点续传）
