---
name: pr-valuation
category: research
description: 市赚率（PR）估值分析技能。基于雪球用户丁宁发明的市赚率体系，结合 DCF 现金流折现，对股票进行估值判断。
triggers:
  - 市赚率
  - PR估值
  - 估值分析
  - 股票估值
  - DCF估值
---

# 市赚率（PR）估值分析

## 概念来源
雪球用户「市赚率」（ID: 7804794005，丁宁）发明。核心理念源自巴菲特"用合理价格买入优质企业"。

## 三个公式

### 1. 基础公式（稳定企业）
```
PR = PE / ROE / 100
```
- PR = 1 → 合理估值
- PR < 1 → 低估
- PR > 1 → 高估
- 巴菲特买可口可乐 PR ≈ 0.4（"40美分买入1美元"）

### 2. 修正公式（低分红企业）
```
N = 50% / 股利支付率
PR = N × PE / ROE / 100
```
- 股利支付率 ≥ 50% → N = 1.0
- 股利支付率 25-50% → N = 50% / 实际支付率
- 股利支付率 ≤ 25% → N = 2.0
- ⚠️ 仅适用于 ROE 及分红稳定的价值股，科技股别用（回购代替分红）

### 3. 第二公式（周期/资源股）
```
PR = PB / ROE² / 100
```
- PB 是明牌，ROE 取多年平均值
- 不能太乐观也不能太悲观

## 关键阈值
| PR 范围 | 含义 | 巴菲特参考 |
|---------|------|-----------|
| < 0.4 | 极度低估 | 可口可乐买入价 |
| 0.4-0.6 | 低估（4-6折） | 巴菲特买入区间 |
| 0.6-0.72 | 合理偏低 | 持有区间 |
| 0.72-1.0 | 合理偏高 | 关注卖出 |
| > 1.0 | 高估 | 考虑清仓 |

## 与 DCF 的关系
- 市赚率与 DCF 理论相通
- 低利率环境下折现率降低，合理估值提升 1.1-1.4 倍
- 丁宁清仓标普 500 时 PR = 1.5

## 适用范围
- ✅ 价值股（银行、保险、能源、消费）
- ✅ 高分红蓝筹
- ✅ ROE 稳定的成熟企业
- ❌ 成长股（ROE 波动大）
- ❌ 科技股（回购代替分红）
- ❌ 宽基指数（混合了价值和成长）

## 分析步骤
1. 获取股票 PE、ROE、PB、股利支付率
2. 判断股票类型（稳定/低分红/周期）
3. 选择合适公式计算 PR
4. 结合 DCF 现金流折现交叉验证
5. 对比阈值给出估值判断

## 数据获取（实战验证）

### A股/港股实时行情
```bash
opencli xueqiu stock SH600519 -f json   # 茅台
opencli xueqiu stock 00700 -f json      # 腾讯港股
```

### PE/ROE/PB 财务数据（东方财富 API，无需登录）
```python
import requests
# A股: secid "1.600519"(沪) "0.300750"(深)
# 港股: secid "116.00700"
r = requests.get("https://push2.eastmoney.com/api/qt/stock/get",
    params={"secid": "1.600519", "fields": "f162,f167,f173"})
# 返回值除以100: f162=PE(TTM), f167=PB, f173=ROE(%)
```

### 雪球丁宁帖子（Jina Reader）
```python
requests.get("https://r.jina.ai/https://xueqiu.com/u/7804794005",
    headers={"Accept": "text/plain"}, timeout=30)
```

## DCF 现金流折现模板
```python
wacc = 0.10; terminal_g = 0.03
pv = sum(fcf*(1+g_yr)**yr / (1+wacc)**yr for yr in 1..10)
tv = fcf*(1+g*0.6)**10 * (1+terminal_g) / (wacc - terminal_g)
intrinsic = pv + tv/(1+wacc)**10
per_share = intrinsic / 总股本
margin = (per_share - price) / price  # 安全边际
```

## 注意事项
- ROE 取值很关键，最好多年平均（3-5年）
- 周期股要看完整周期的 ROE
- PR 是"模糊正确"的工具，不要精确到小数点
- 需结合行业前景、管理层等定性因素
