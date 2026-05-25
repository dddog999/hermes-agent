---
name: bank-transfer-invoice
description: 银行转账凭证自动生成系统 - 从发票PDF提取信息并生成转账凭证
category: productivity
version: 1.0
created: 2026-04-16
---

# 银行转账凭证自动生成系统

## 概述
从发票PDF中自动提取转账信息，生成标准格式的转账凭证（Excel和PDF），适用于日常财务转账工作。

## 系统要求
- **操作系统**: Windows（依赖pywin32和Excel COM接口）
- **Python**: 3.10+
- **依赖包**: xlwings, reportlab, pyinputplus, requests, Pillow, PyMuPDF
- **软件依赖**: Microsoft Excel, Microsoft Print to PDF
- **网络依赖**: 智谱GLM API（用于发票识别）

## 项目位置
```
C:\Users\kangle\Documents\银行\转账\transfer\
```

## 快速使用

### 1. 使用CLI版本（推荐）
```bash
# 切换到项目目录
cd C:\Users\kangle\Documents\银行\转账\transfer

# 运行CLI处理发票
python src/cli.py <发票文件.pdf> [输出目录]

# 示例
python src/cli.py 发票.pdf
python src/cli.py 发票.pdf output
```

### 2. 使用PowerShell脚本
```powershell
# 运行交互式版本
./scripts/run_transfer.ps1
```

### 3. 使用Python脚本
```bash
# 交互式版本
python src/transfer.py

# TUI界面版本
python src/transfer_textual_ui.py
```

## 工作流程

### 步骤1：发票识别
1. 系统使用PaddleOCR（主引擎）或智谱GLM（备用方案）提取发票文字
2. 自动识别以下关键信息：
   - 收款方名称
   - 银行账号
   - 开户银行
   - 转账金额
   - 转账用途

### 步骤2：账户库匹配
1. 系统自动从账户数据库（`data/acNoRe_optimized.json`）匹配收款方信息
2. 补充缺失的银行账号、开户行等信息

### 步骤3：生成转账凭证
1. 使用Excel模板（`data/template.xlsx`）生成转账凭证
2. 自动填充识别到的信息
3. 保存为Excel文件

### 步骤4：转换为PDF
1. 使用Excel COM接口将Excel转换为PDF
2. 保存到归档目录（`data/归档/`）

## 配置文件

### API密钥配置
- **位置**: `.env` 文件（项目根目录）
- **格式**: JSON格式，包含API密钥配置
- **必需配置**:
  ```json
  {
    "api_keys": {
      "zhipu_glm": "智谱GLM API密钥",
      "paddleocr": {
        "api_url": "PaddleOCR API地址",
        "token": "PaddleOCR API令牌"
      }
    }
  }
  ```

### 账户数据库
- **位置**: `data/acNoRe_optimized.json`
- **用途**: 存储常用收款方账户信息
- **格式**: JSON数组，每个对象包含户名、账号、支行等字段

## 输出文件

### Excel文件
- **位置**: `data/归档/`
- **命名**: `<收款方名称><日期>.xlsx`
- **内容**: 标准转账凭证格式

### PDF文件
- **位置**: `data/归档/`
- **命名**: `<收款方名称><日期>.pdf`
- **用途**: 打印和存档

## 代码修改记录

### 1. usage字段处理优化（2026-04-16）
**文件**: `src/invoice_processor.py`
**修改内容**:
- 移除了usage字段中的星号"*"标识符
- 将格式从"*分类*项目名"改为"分类: 项目名"
- 添加了空白字符清理，移除换行符和多余空白
- 改进了正则表达式，支持跨行文本匹配

**修改原因**:
- 发票上的星号是分类标识符，不应出现在最终用途字段中
- PaddleOCR可能将文本分割成多行，导致截断

### 2. PaddleOCR VLLM参数优化（2026-04-16）
**文件**: `src/paddleocr_processor.py`
**修改内容**:
添加了VLLM参数优化：
```python
optional_payload = {
    "useDocOrientationClassify": False,
    "useDocUnwarping": False,
    "useChartRecognition": False,
    # 添加表格识别相关的参数
    "promptLabel": "table",           # 使用表格识别提示词
    "temperature": 0.1,               # 降低温度，提高稳定性
    "topP": 0.9,                      # 调整topP
    "useLayoutDetection": True,       # 启用版面检测
}
```

**修改原因**:
- 尝试改善PaddleOCR-VL-1.5的识别效果
- 使用表格识别提示词可能提高表格内容的识别准确性

## 技术限制说明

### PaddleOCR-VL-1.5 API限制
1. **promptLabel参数限制**: 只支持预定义类型（ocr、formula、table、chart），不支持自定义提示词
2. **文本截断问题**: 当文本被分割成多行时，可能只识别部分内容
3. **模型选择**: PaddleOCR-VL-1.5 vs PP-StructureV3，后者可能有更好的表格识别能力，但API响应较慢

### 截断问题根本原因
从PDF分析看，完整文本被分割成多行：
```
*建筑服务*康乐村党建宣
传项目工程款
```
PaddleOCR可能将这两行识别为独立的文本块，导致截断。

### 可能的进一步改进方向
1. **后处理逻辑**: 在解析阶段合并被分割的文本块
2. **调整其他参数**: 如`layoutMergeBboxesMode`等
3. **使用其他OCR引擎**: 如百度OCR、腾讯OCR等
4. **手动校对**: 对于关键发票进行人工校对

## 常见问题

### 1. 发票识别失败
- 检查`.env`文件中的API密钥配置
- 确保网络连接正常
- 尝试使用不同的发票文件

### 2. Excel转换失败
- 确保已安装Microsoft Excel
- 检查Excel COM接口是否正常工作
- 尝试手动打开Excel文件

### 3. 打印问题
- 确保已安装Microsoft Print to PDF
- 检查打印机配置（默认使用EPSON DLQ-3250K ESC/P2）

### 4. usage字段问题
- **星号问题**：发票上的"*"是分类标识符，系统会自动移除并转换为"分类: 项目名"格式
- **截断问题**：PaddleOCR可能无法识别完整的项目名称，特别是当文本被分割成多行时
- **解决方案**：
  1. 使用LLM分析结果（如果可用）
  2. 手动校对识别结果
  3. 调整PaddleOCR参数或使用其他OCR引擎

## 维护建议

### 定期更新
1. **账户数据库**: 定期更新`data/acNoRe_optimized.json`
2. **API密钥**: 定期更新`.env`中的API密钥
3. **依赖包**: 定期更新Python依赖包

### 备份策略
1. **配置文件备份**: 定期备份`.env`文件
2. **数据备份**: 定期备份`data/`目录
3. **归档备份**: 定期备份`data/归档/`目录

## 扩展功能

### 自定义模板
- 修改`data/template.xlsx`自定义转账凭证格式
- 注意：不要修改单元格位置，只修改格式和样式

### 添加新的发票类型
- 修改`src/invoice_processor.py`添加新的发票识别规则
- 更新AI提示词以支持新的发票格式

### 批量处理
- 可以编写脚本批量处理多个发票文件
- 使用`src/cli.py`的命令行接口进行自动化处理

## 故障排除

### 日志查看
- 系统运行时会输出详细日志
- 注意查看错误信息和警告

### 调试模式
- 使用`src/transfer.py`的交互式模式进行调试
- 检查中间文件（如`last_print_info.json`）

### 联系支持
- 查看项目README.md获取更多信息
- 检查项目issues获取常见问题解决方案