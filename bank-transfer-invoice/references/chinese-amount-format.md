# 中文大写金额实现笔记
# Session: 2026-05-01

## 问题
模板 D8 单元格公式 `=E20` 直接引用数值 5000，打印出来是 "5000" 而非中文大写 "伍仟圆整"。

## 根因分析
模板设计：D8=F9（合并单元格 D8:F9），E20 是小写金额格。
- I9:Q9 那行用复杂 IF+FLOOR+RIGHT 公式提取数字位渲染，但这是格式化数字，不是中文大写
- D8 的公式 `=E20` 只显示数字，不是中文大写金额

## 解决方案
在 `_xml_fill_and_save()` 中调用 `num2chinese()` 生成中文大写字符串，注入 sharedStrings，替换 D8 单元格内容。

### num2chinese() 函数
位置: `src/cli.py` 第 82-140 行

关键逻辑：
- 整数部分：递归处理万位（最大支持仟万元级别）
- 小数部分：角+分，有"分"时末尾不加"整"
- 边界：money=0 → "零圆整"，int_part=0 → 直接返回角分

### 注入步骤
1. `chinese_amount = num2chinese(info["money"])`
2. `ss_content, d8_idx = add_string(ss_content, chinese_amount)` → sharedStrings
3. `content = replace_cell_value(content, 'D8', d8_idx)` → 替换原公式单元格

## 测试用例（全部通过）
| 金额 | 中文大写 |
|------|---------|
| 5000 | 伍仟圆整 |
| 110 | 壹佰壹拾圆整 |
| 3256.89 | 叁仟贰佰伍拾陆圆捌角玖分 |
| 10000 | 壹万圆整 |
| 0.5 | 伍角整 |
| 0.01 | 壹分 |
| 0 | 零圆整 |

## 涉及文件
- `src/cli.py` — num2chinese() + _xml_fill_and_save() 修改
- `data/template.xlsx` — 不需要修改，凭证动态生成
- `data/归档/` — 生成的凭证保存位置
