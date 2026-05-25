---
name: hp-printer-upd
description: HP Universal Print Driver (UPD) 下载、卸载旧版本和安装指南
tags: [printer, hp, driver, installation]
---

# HP Universal Print Driver (UPD) 安装指南

适用于HP LaserJet等打印机的通用打印驱动安装，特别针对HP LaserJet Professional M1213nf MFP等型号。

## 前置条件

- 确认打印机型号兼容HP UPD（大多数HP LaserJet系列都支持）
- 确保有管理员权限
- 建议先备份打印机设置

## 下载驱动程序

### 方法1：通过HP官网下载（推荐）

1. **访问HP支持页面**：
   ```
   https://support.hp.com/us-en/drivers/hp-universal-print-driver-series-for-windows/4157320
   ```

2. **选择操作系统版本**：
   - 页面会自动检测当前系统
   - 如需其他版本，点击"选择其他作業系統"

3. **下载所需驱动**：
   - **PCL6驱动**（推荐）：`upd-pcl6-x64-x.x.x.xxxxx.zip`
   - **PS驱动**（PostScript）：`upd-ps-x64-x.x.x.xxxxx.zip`
   - **PARK工具包**（可选）：`HP-PARK-vx.x.x.zip`

### 方法2：通过搜索找到下载页面

1. 搜索"HP Universal Print Driver download"
2. 选择HP官方支持页面（support.hp.com）
3. 找到"HP Universal Print Driver Series for Windows"

## 卸载旧版本（v7.4及更早）

**重要**：HP建议卸载v7.4及更早版本以解决安全问题。

### 步骤1：打开打印管理控制台
```cmd
printmanagement.msc
```
或：控制面板 → 管理工具 → 打印管理

### 步骤2：识别需要删除的打印机
1. 左侧导航窗格选择"打印机"
2. 右侧窗格按"驱动程序版本"列排序
3. 找到驱动程序版本为 `61.315.1.25959` 或更早的打印机
4. 驱动程序名称包含"HP Universal Printing"

### 步骤3：删除打印机名称
- 选择要删除的打印机（可多选）
- 右键 → 删除 → 确认

### 步骤4：删除驱动程序和驱动程序包
1. 左侧导航窗格选择"驱动程序"
2. 菜单栏："操作" → "管理驱动程序"
3. 找到要删除的HP UPD驱动程序（如"HP Universal Printing PCL6"）
4. 选择"删除" → "删除驱动程序和驱动程序包" → 确定

### 步骤5：如果删除失败
- 确认驱动程序没有被其他打印机使用
- 重启Print Spooler服务：
  ```cmd
  net stop spooler && net start spooler
  ```

### 步骤6：可选 - 删除打印处理器
1. 停止Print Spooler服务
2. 删除 `C:\Windows\System32\spool\prtprocs\x64` 中的HP打印处理器DLL文件（如`hpcpp315.dll`及更早版本）
3. 启动Print Spooler服务

## 安装新版本UPD

### 解压驱动程序
```bash
# 在WSL中解压
mkdir -p UPD-PCL6
unzip upd-pcl6-x64-x.x.x.xxxxx.zip -d UPD-PCL6
```

### 运行安装程序
1. 打开Windows资源管理器，导航到解压目录
2. 双击运行 `Install.exe`
3. 按照安装向导操作

### 安装模式选择（重要：三个选项互斥！）

**针对USB连接的打印机（如HP LaserJet Professional M1213nf MFP）：**
- **USB模式 - 即插即用**（推荐）：专为USB即插即用设计，自动处理USB连接
  - 选择此模式后，会显示两个额外选项：
    - ✓ 勾选"从Windows驱动程序存储区删除所有版本的HP通用打印驱动程序"（清理旧版本）
    - ✓ 勾选"将HP Universal Printing PCL6驱动程序添加到Windows驱动程序存储区"（USB即插即用必需）

**针对网络打印机：**
- **传统模式**：适合固定网络打印机，创建永久驱动实例，支持双向通信
- **动态模式**：适合移动办公，可自动发现网络打印机

**关键区别：**
- 三个安装模式是互斥的，只能选择一个
- 两个勾选选项（删除旧版本、添加到驱动存储区）**仅在选择USB模式时出现**
- PDF文档明确说明："Select USB mode for USB Plug and Play"

## WSL环境中的网页自动化

### 安装Chrome（如需要）
```bash
# 下载安装Chrome
cd /tmp
wget -q --timeout=30 https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O chrome.deb
sudo dpkg -i chrome.deb
sudo apt-get install -y xdg-utils  # 解决依赖问题
```

### 启动Chrome远程调试
```bash
google-chrome --remote-debugging-port=9222 --remote-allow-origins=* --no-sandbox --disable-gpu --user-data-dir=/tmp/chrome-debug &
```

### 使用CDP Proxy
```bash
# 检查依赖
node ~/.hermes/skills/web-access/scripts/check-deps.mjs

# 创建新标签页访问HP官网
curl -s "http://localhost:3456/new?url=https://support.hp.com/us-en/drivers"

# 点击下载按钮等操作
curl -s -X POST "http://localhost:3456/click?target=ID" -d '#download-button-id'
```

## 常见问题

### 1. 下载页面找不到
- 确保访问的是HP官方支持页面
- 尝试不同区域版本（如us-en、tw-zh等）

### 2. 驱动程序安装失败
- 确保以管理员权限运行安装程序
- 先卸载旧版本再安装新版本
- 检查打印机是否已连接并开机

### 3. WSL中无法访问网页
- 使用CDP Proxy方案（参考web-access技能）
- 或手动在Windows中下载文件后复制到WSL

## 版本历史

- v7.9.0.26347（2025年9月）：当前推荐版本
- v8.1.0.26560（2026年1月）：最新版本，包含PS驱动

## 参考文档

- HP UPD发布说明：`HP_UPD_Release_Notes.pdf`
- 旧版本卸载指南：`HP_UPD_Remove_Earlier_Versions.pdf`
- PARK工具包说明：`HP_UPD_PARK_Release_Notes.pdf`