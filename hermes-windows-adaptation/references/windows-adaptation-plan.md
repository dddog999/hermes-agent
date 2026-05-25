# Hermes Agent Windows 适配规划

> 完整规划文档路径：`/mnt/c/Users/dddog/Nutstore/1/myNutstore/hermes-sync/wiki/raw/projectProgress/windows-adaptation-plan.md`

## 快速摘要

### 根本障碍
- **TUI 模式**：`hermes --tui` 依赖 POSIX PTY，Windows 原生不可用（WSL OK）
- **CLI 和 Gateway 模式**：理论上可以工作，需要适配

### 已有支持（无需改）
- ✅ `preexec_fn=None if _IS_WINDOWS` 守卫
- ✅ `os.killpg`/`os.getpgid` 守卫
- ✅ Git Bash 自动检测
- ✅ ptyprocess Windows 排除
- ✅ Windows 兼容性测试 `test_windows_compat.py`

### 需要改动
1. **`hermes_constants.py`**：添加 `is_windows()` / `is_macos()`
2. **`local.py`**：HOME + USERPROFILE 同步设置
3. **安装脚本**：创建 `setup.ps1`
4. **验证**：在 kangle 上测试 Gateway + CLI

### 分支
- `feat/windows-native`（新分支，基于 `fix/patch-timeout`）
- `fix/patch-timeout`（已同步上游 + 本地 patch）
