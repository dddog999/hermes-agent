
# WSL Python 包安装指南

## 问题场景

WSL（尤其 Ubuntu 24.04）默认的 Python 环境可能缺少 pip，导致无法安装第三方包。

## 环境特征

| 环境 | pip | 说明 |
|------|-----|------|
| WSL 系统 Python (`/usr/bin/python3`) | ❌ 默认无 | 需手动安装 |
| WSL venv | ❌ 可能无 | `ensurepip` 可能也不可用 |
| Ubuntu 24.04 | PEP 668 | 需要 `--break-system-packages` |

## 最佳安装路径（3步）

### 1. 先装 pip（快，小包）

```bash
sudo apt install -y python3-pip
```

### 2. 用 pip 装目标包（快，直接下载 wheel）

```bash
/usr/bin/python3 -m pip install --break-system-packages pandas xlrd requests
```

**关键参数：**
- `--break-system-packages` — Ubuntu 24.04 (PEP 668) 必须加，否则报 externally-managed-environment
- 指定 `/usr/bin/python3` 而不是 `python3` — 避免用到 venv 的 Python

### 3. 验证

```bash
/usr/bin/python3 -c "import pandas, xlrd, requests; print('OK')"
```

> ⚠️ pandas 导入较慢（~5-10s），验证命令建议 timeout ≥ 15s
>
> 实测超时参考（kangle WSL）：
> - `apt install python3-pip`: ~30s
> - `pip install pandas xlrd`: ~20s（wheel 下载 ~25MB 总计）
> - `python3 -c "import pandas"`: ~5-10s 首次导入

## 踩坑记录

### ❌ 直接 apt install python3-pandas 太慢

```bash
# 不推荐：pandas 的 apt 依赖链极长（numpy, matplotlib 等），经常超时
sudo apt install -y python3-pandas python3-xlrd
```

### ❌ venv 中无 pip

```bash
# hermes-agent venv 中：
python3 -m pip        # → No module named pip
python3 -m ensurepip  # → No module named ensurepip
```

**解决：** 不在 venv 里装，用系统 Python。

### ❌ sudo 密码交互问题

```bash
# 如果 sudo 需要密码且非免密：
echo "PASSWORD" | sudo -S apt install ...
# 或让用户手动执行 sudo 命令
```

### ⚠️ pip install 也可能超时

pandas wheel 包约 11MB + numpy 17MB，首次下载需几十秒。设 timeout ≥ 180s。

## 核心依赖速查

| 包 | 大小 | 用途 |
|---|---|---|
| pandas | ~11MB wheel | 数据分析/Excel 读取 |
| xlrd | ~97KB wheel | 读取 .xls（旧版 Excel） |
| requests | ~50KB | HTTP 请求 |
| openpyxl | ~200KB | 读取 .xlsx（新版 Excel） |
| python-docx | ~400KB | Word 文档处理 |
