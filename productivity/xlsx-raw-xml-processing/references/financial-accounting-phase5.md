# 财务网 出纳帐 Phase 5 工作流

项目路径：`C:\Users\kangle\Documents\OfficeChores\projects\财务网\`
脚本目录：`scripts/`
数据目录：`data/`
留言板：`C:\Users\kangle\Nutstore\1\myNutstore (1)\hermes-sync\留言板.md`

## 阶段说明

两个原始xls文件（出纳帐58和59）需经过清洗合并流程。

### Step 1 — `phase5_step1.py`
- 删除指定列（保留 A-E 列）
- 删除 F=0 的行
- 补齐行号
- 输入：原始xls转xlsx → `出纳帐 (58/59)_cleaned.xlsx`

### Step 2 — `phase5_step2.py`
- 删除 D 列中以下值的行：241开头 / 21开头 / 101 / 112012001 / 513005 / 513015
- 补齐行号
- 输入：`出纳帐 (58/59)_cleaned.xlsx`

### Step 3 — B列摘要关键词分类（搁置待确认）

### Step 4 — `phase5_step4.py`
- 两表合并为一个，按日期（A列）升序排列
- **必须用原始XML方式**（解包→改XML→打包），保持原格式
- sharedString索引重映射（58的索引→新索引，59的索引→新索引）
- 输入：`出纳帐 (58)_cleaned.xlsx` + `出纳帐 (59)_cleaned.xlsx`
- 输出：`出纳帐_合并.xlsx`

## 数据结构

| 行 | 内容 | A | B | C | D | E |
|---|------|---|---|---|---|---|
| 1 | 空行 | - | - | - | - | - |
| 2 | 单位名称 | 单位名称: | 广东省中山市沙溪镇康乐村民委员会 | | | |
| 3 | 表头 | 日期 | 摘要 | (金额) | 对方科目 | 原始单据号 |
| 4 | 子表头 | 20 | (借方/贷方) | | | |
| 5+ | 数据行 | 2026-04-14 | 付-xxx | 金额 | 科目编码 | F开头的单据号 |

## 运行顺序

```bash
cd C:\Users\kangle\Documents\OfficeChores\projects\财务网\scripts
python phase5_step1.py    # Step 1: 清洗
python phase5_step2.py    # Step 2: 过滤D列
python phase5_step4.py    # Step 4: 合并
```
