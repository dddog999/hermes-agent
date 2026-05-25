---
name: hermes-windows-adaptation
description: Hermes Agent Windows 原生适配规划与实施指南
category: devops
---

# Hermes Agent Windows 适配

## 核心架构区分：两个 Hermes 实例

⚠️ 当前系统运行着 **两个独立** 的 Hermes 实例，症状不同，修法不同：

| | Windows 原生 Hermes | WSL Hermes（微信/飞书 gateway） |
|---|---|---|
| 进程路径 | `C:\...\Python312\Scripts\hermes.exe` | `~/.hermes/hermes-agent/venv/bin/hermes`（通过 bash alias） |
| `sys.platform` | `"win32"` | `"linux"` |
| 终端 shell | Git Bash → 退到 `powershell.exe` | `/bin/bash`（WSL 原生） |
| 痛点 | gateway 重启后自动关闭 + 丢上下文 | 终端工具不能用 pwsh（只能用 bash） |
| config.yaml | 共享坚果云同步目录 | 共享（WSL `/mnt/c/Users/dddog/Nutstore/...`） |

**config.yaml 通过坚果云共享**，但两个实例的 env var 解析路径不同（WSL 的 `~` → `/home/dddog/`，Windows 的 `~` → `C:\Users\dddog\`）。

## 现状

Hermes 已有**部分** Windows 支持，并非完全不支持。关键现状：

### 已有 Windows 兼容代码
- `tools/environments/local.py` — `_IS_WINDOWS` 守卫 `pexec_fn=None`、`os.killpg`、`os.getpgid`
- `tools/process_registry.py` — 同上
- `tools/code_execution_tool.py` — 同上
- `gateway/platforms/whatsapp.py` — 同上
- `local.py:_find_bash()` — 自动检测 Git Bash（Windows 上）
- `pyproject.toml` — ptyprocess 已标记 `sys_platform != 'win32'`
- `tests/tools/test_windows_compat.py` — AST 静态检查

### 根本障碍：TTY/PTY
AGENTS.md 原文：`hermes --tui` 通过 ptyprocess（POSIX PTY — **WSL works, native Windows does not**）

结论：TUI 模式在 Windows 原生上不可用。CLI 模式和 Gateway 模式可以工作。

---

## 需要改动的地方

### 1. hermes_constants.py — 添加平台检测函数

在 `is_termux()` 和 `is_wsl()` 旁边添加：

```python
def is_windows() -> bool:
    """Return True when running on native Windows."""
    return sys.platform == "win32"

def is_macos() -> bool:
    """Return True when running on macOS."""
    return sys.platform == "darwin"
```

### 2. local.py — 修复 HOME / TEMP / USERPROFILE

`_make_run_env()` 中设置 `HOME` 时，Windows 需要同步设置 `USERPROFILE`：

```python
from hermes_constants import get_subprocess_home
_profile_home = get_subprocess_home()
if _profile_home:
    run_env["HOME"] = _profile_home
    if _IS_WINDOWS:
        # Windows 子进程需要 USERPROFILE
        if "USERPROFILE" not in run_env:
            run_env["USERPROFILE"] = os.environ.get("USERPROFILE", "")
```

`get_temp_dir()` 的 POSIX 路径检查（`if candidate.startswith("/")`）对 Windows 有效，因为 Windows 路径以盘符开头如 `C:\`，不需要改。

### 3. scripts/install.ps1 — Windows 安装脚本

`install.sh` 是 Bash 脚本，不支持 Windows 原生。需要创建 PowerShell 安装脚本。

### 4. TUI — 添加 Windows 检测提示

在 `ui-tui/src/app.tsx` 中检测 `navigator.platform` 或通过 gateway 传递平台信息，TUI 启动时显示：

> "TUI mode requires WSL, Docker, or Linux/macOS. Use `hermes` CLI mode or `hermes gateway run` on Windows."

---

## ⚠️ Gateway 重启自动关闭（`_launch_detached_restart_command` 纯 Unix）

**症状**：在 Windows 上执行 `/restart` 后，gateway 停止且不再重启（"自己关闭"）。

**根因**：`gateway/run.py:2631-2660` 的 `_launch_detached_restart_command()` 是纯 Unix 实现：

```python
# 原代码（Windows 上完全不可用）
subprocess.Popen(["bash", "-lc",
    f"while kill -0 {current_pid} 2>/dev/null; do sleep 0.2; done; "
    f"{cmd} gateway restart"
], ...)
```

Windows 上三个不可用组件：

| 组件 | 问题 |
|------|------|
| `bash -lc` | Windows 无原生 bash；WSL/Git Bash 的 bash 对原生 Windows PID 不可见 |
| `kill -0` | MSYS `kill` 对原生 Windows PID 行为不可靠 |
| `setsid` | Windows 没有 `setsid` 命令 |

**结果**：子进程抛 `FileNotFoundError`（catch 后只 log error），或错误地提前运行 `hermes gateway restart` → 旧 gateway PID 文件还在 → 新实例检测到冲突退出 → **gateway 彻底停止**。

### 修复方案

修改 `_launch_detached_restart_command()`，在 `sys.platform == "win32"` 时用 Python 原生替代 bash：

```python
if sys.platform == "win32":
    watcher = textwrap.dedent("""\
        import os, subprocess, sys, time
        pid = int(sys.argv[1]); cmd = sys.argv[2:]
        deadline = time.monotonic() + 120
        while time.monotonic() < deadline:
            try:
                os.kill(pid, 0)  # Windows 上通过 WaitForSingleObject 检查
            except (ProcessLookupError, PermissionError):
                break
            time.sleep(0.2)
        subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            creationflags=subprocess.CREATE_NEW_PROCESS_GROUP | subprocess.DETACHED_PROCESS)
    """)
    subprocess.Popen(
        [sys.executable, "-c", watcher, str(current_pid), *_rebuild_hermes_cmd()],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        creationflags=subprocess.CREATE_NEW_PROCESS_GROUP | subprocess.DETACHED_PROCESS,
    )
```

关键点：
- `os.kill(pid, 0)` 在 Windows 上通过 `WaitForSingleObject` 检查进程存活
- `subprocess.DETACHED_PROCESS | CREATE_NEW_PROCESS_GROUP` 替代 `start_new_session=True`
- `sys.executable` 确保用相同 Python 解释器

### Sibling: `launch_detached_profile_gateway_restart` 已有正确模式

`hermes_cli/gateway.py:439` 的 `launch_detached_profile_gateway_restart()` 已经用了正确的 Windows 兼容模式：

```python
# 用 python -c watcher 脚本 + os.kill(pid, 0)，完美跨平台
watcher = textwrap.dedent("""\
    import os, subprocess, sys, time
    pid = int(sys.argv[1]); cmd = sys.argv[2:]
    deadline = time.monotonic() + 120
    while time.monotonic() < deadline:
        try:
            os.kill(pid, 0)
        except (ProcessLookupError, PermissionError):
            break
        time.sleep(0.2)
    subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
""")
```

这个模式可以直接复用给 `_launch_detached_restart_command`。

## ⚠️ Windows 信号处理无声降级

**症状**：对 gateway 进程发 `SIGTERM` 后没有优雅关闭（不执行 drain、不写 resume_pending 标记），直接 `sys.exit(1)`。

**根因**：`gateway/run.py:14804-14815`：

```python
for sig in (signal.SIGINT, signal.SIGTERM):
    try:
        loop.add_signal_handler(sig, shutdown_signal_handler, sig)
    except NotImplementedError:
        pass  # ← Windows 上静默跳过！无信号处理！
```

`asyncio` 的 `loop.add_signal_handler()` 在 Windows 上始终抛 `NotImplementedError`。结果：
- SIGTERM → Python 默认处理 → `sys.exit(1)`（非零退出）
- 无 drain、无 resume_pending 标记 → 下次启动时可能触发 stuck-loop 检测
- 信号诊断用 `ps aux` → `FileNotFoundError`（catch 后无害）

**影响**：`hermes gateway restart` CLI 路径使用 `stop_profile_gateway()` 发 SIGTERM → Windows 上直接杀进程。

### Gateway Windows 兼容性矩阵

| 组件 | Unix | Windows | 修复优先级 |
|------|------|---------|-----------|
| `start_gateway()` 主流程 | ✅ | ✅ 可启动 | — |
| adapter 创建（Telegram/Discord/微信等） | ✅ | ✅ 纯 Python | — |
| session store（SQLite） | ✅ | ✅ | — |
| agent cache | ✅ | ✅ | — |
| `_launch_detached_restart_command` | ✅ | ❌ 重启后死 | **P0** |
| `loop.add_signal_handler(SIGTERM)` | ✅ | ❌ 无声降级 | **P1** |
| `ps aux` 诊断 | ✅ | ⚠️ catch 后无害 | — |
| `_get_parent_pid`（`ps -o ppid=`） | ✅ | ❌ 返回 None | P2 |
| `_scan_gateway_pids` | ✅ | ✅ 已有 wmic 分支 | — |
| cron scheduler | ✅ | ✅ 纯 Python | — |
| `start_new_session=True` in Popen | ✅ | ✅ 等效于 `DETACHED_PROCESS` | 需改 |
| `launch_detached_profile_gateway_restart` | ✅ | ✅ 已用 python -c 模式 | — |

## 上游 Windows 支持现状（2026-05 重大更新）

上游 `upstream/main` 已原生支持 Windows，比我们的 fork 更完整：

### 上游已有（我们的分支没有或被删除的）

| 文件 | 说明 |
|---|---|
| `hermes_cli/stdio.py` (1252行) | **Windows UTF-8 console 修复** — `SetConsoleCP(65001)` 解决 cp1252/cp437 编码问题 |
| `scripts/install.ps1` | 官方一键安装脚本 (`irm\|iex`)，支持 uv/Python/Node/Git 自动安装 |
| `website/docs/user-guide/windows-native.md` | **完整 Windows 原生指南**（功能矩阵、安装步骤、已知坑） |
| `tools/environments/local.py` | `HERMES_GIT_BASH_PATH` 环境变量 + Portable Git 支持 |

### 我们的分支额外有的（上游没有）

| 改动 | 说明 |
|---|---|
| **PowerShell fallback** | Windows 上优先 `powershell.exe`，找不到才 Git Bash |
| **Gateway 重启** | `launch_detached_restart()` 的 win32 `subprocess.Popen` 分支 |
| **信号降级** | `add_signal_handler` → `signal.signal` |
| **WSL bash 排除** | `_find_bash()` 跳过 WSL `C:\WINDOWS\system32\bash.exe` |

### 融合策略

**推荐：Rebase + 二合一 `_find_bash()`**

```
# 1. 整理 patch
git format-patch upstream/main..win/feat/windows-native -- > /tmp/our-patches.patch

# 2. 基于 upstream/main 新建分支
git checkout -b feat/windows-native-v2 upstream/main

# 3. 应用 patch
git am /tmp/our-patches.patch
```

**关键冲突：`tools/environments/local.py` 的 `_find_bash()` 策略不同**

- 上游：`HERMES_GIT_BASH_PATH` + Portable Git 优先
- 我们：PowerShell 优先

**二合一方案**：保留我们的 PowerShell fallback，但加入上游的 `HERMES_GIT_BASH_PATH` 机制作为最高优先级。

### 网络限制

GitHub 访问在 WSL 内因 Tailscale DNS 拦截返回代理 IP（198.18.x.x）而失败。参考 `wsl` skill 的 `references/tailscale-github-dns-intercept.md`。

## 不需要改的地方

- ✅ PTY/ptyprocess 守卫（已有 `sys_platform != 'win32'`）
- ✅ `preexec_fn=None if _IS_WINDOWS`（已有）
- ✅ `os.killpg`/`os.getpgid` 守卫（已有）
- ✅ Git Bash 自动检测（已有）
- ✅ 临时目录 POSIX 路径检查（已有，`tempfile.gettempdir()` 在 Windows 上返回 `%LOCALAPPDATA%\Temp`）
- ✅ bashrc/bash_profile 守卫（已有 `not _IS_WINDOWS`）

---

## 技能库共享（多设备/多助手）

### 目录联接（mklink /D）

Windows 上技能库通过目录联接（junction）指向坚果云同步目录，实现跨设备/跨助手共享：

```cmd
REM 先备份原有技能目录（可选）
move %USERPROFILE%\.hermes\skills %USERPROFILE%\.hermes\skills.bak

REM 将技能目录指向坚果云同步目录
mklink /D %USERPROFILE%\.hermes\skills C:\Users\dddog\Nutstore\1\myNutstore\hermes-sync\skills
```

**原理**：`mklink /D` 创建 Windows 目录联接（与软链接类似但不需要管理员权限）。所有对 `~/.hermes/skills/` 的访问都被透明重定向到坚果云路径。坚果云自动同步到其他设备。

**注意事项**：
- 坚果云目录必须是完整的 200+ 技能集（包括 built-in 技能和 `openclaw-imports/`）
- 初始搭建时需先将 `~/.hermes/skills/` 中 Hermes 内置但没有同步的技能**回填到坚果云目录**
- `.bundled_manifest` 和 `.curator_state` 是 Hermes 内部状态文件，建议一并复制到坚果云目录中

### 记忆备份（Cron）

在 Windows 上用 Node.js 脚本每日备份 MEMORY.md 和 USER.md 到坚果云 `hermes-backups/`：

```javascript
// ~/.hermes/scripts/backup-memory.cjs
const fs = require('fs');
const path = require('path');

const today = new Date().toISOString().slice(0, 10).replace(/-/g, '');
const hostTag = 'wooking-win';  // 区分 WSL 时代的 "wooking_" 前缀

const hermesMemDir = path.join(process.env.USERPROFILE, '.hermes', 'memories');
const nutstoreBackupDir = path.join(
  process.env.USERPROFILE, 'Nutstore', '1', 'myNutstore', 'hermes-sync', 'hermes-backups'
);

fs.mkdirSync(nutstoreBackupDir, { recursive: true });
['MEMORY.md', 'USER.md'].forEach(f => {
  const src = path.join(hermesMemDir, f);
  if (fs.existsSync(src)) {
    fs.copyFileSync(src, path.join(nutstoreBackupDir, `${hostTag}_${f.replace('.md', '')}_${today}.md`));
  }
});
// 清理 90 天前的旧备份
```

**命名规则**：`<hostname>-<os>_MEMORY_YYYYMMDD.md`（如 `wooking-win_MEMORY_20260509.md`）区别于 WSL 时代的 `wooking_` 前缀。

## ⚠️ 终端 shell 配置 `terminal.shell` 不被 `_find_bash()` 读取

**症状**：config.yaml 配置了 `terminal.shell: powershell.exe`，但 terminal 工具仍然用 bash（WSL 上 `/bin/bash`，Windows 上 Git Bash）。

**根因**：`tools/environments/local.py:177-214` 的 `_find_bash()` 完全不读 config：

```python
def _find_bash() -> str:
    if _IS_WINDOWS:
        # 只找 Git Bash → 退到 powershell.exe
        for candidate in (...):
            if candidate and os.path.isfile(candidate):
                return candidate
        return shutil.which("powershell.exe") or r"C:\Windows\System32\..."
    # POSIX/WSL：硬编码找 bash
    return (
        shutil.which("bash")          # → /bin/bash
        or "/usr/bin/bash"
        or "/bin/bash"
        or os.environ.get("SHELL")    # → 用户的登录 shell（也是 bash）
        or "/bin/sh"
    )
```

`terminal.shell` 配置了但没有对应的 env var 桥接（`gateway/run.py:324-349` 的 `_terminal_env_map` 不包含 `shell` 和 `shell_args`）。简而言之：**配了等于没配**。

**影响**：
- WSL 上永远用 `/bin/bash`，即使用户登录 shell 是 `pwsh` 也不行
- Windows 上优先 Git Bash，仅当 Git Bash 不存在才退到 `powershell.exe`
- `pwsh.exe`（PowerShell 7）从未被考虑

### `_run_bash()` 中的 pwsh 兼容性

```python
def _run_bash(self, cmd_string, ...):
    bash = _find_bash()
    is_powershell = "powershell" in bash.lower()
    if is_powershell:
        args = [bash, "-NoProfile", "-NonInteractive", "-Command", cmd_with_exit]
    else:
        args = [bash, "-l", "-c", cmd_string]
```

`is_powershell` 只匹配 `powershell` 字符串，不匹配 `pwsh`（PowerShell 7）。

### Windows 上 `_find_bash()` 检测顺序缺陷

当 Hermes 跑在 Windows 原生 hermes.exe 上时（`sys.platform == \"win32\"`），`_find_bash()` 检测顺序：

```python
def _find_bash() -> str:
    if _IS_WINDOWS:
        # 1. 检查 Git Bash
        for candidate in [
            os.path.join(os.environ.get("ProgramFiles", ""), "Git", "bin", "bash.exe"),
            os.path.join(os.environ.get("ProgramFiles(x86)", ""), "Git", "bin", "bash.exe"),
            os.path.join(os.environ["USERPROFILE"], "scoop", "apps", "git", "current", "bin", "bash.exe"),
            os.path.join(os.environ["LOCALAPPDATA"], "Programs", "Git", "bin", "bash.exe"),
        ]:
            if candidate and os.path.isfile(candidate):
                return candidate
        # 2. 退到 PATH 中的 bash.exe → 坑！WSL 注册了 C:\WINDOWS\system32\bash.exe
        #    这个 bash.exe 启动 WSL 的 /bin/bash，仍然是 WSL 环境
        return shutil.which("bash") or shutil.which("powershell.exe") or ...
```

**问题**：WSL 安装后会在 `C:\WINDOWS\system32\bash.exe` 注册一个 bash 启动器。`shutil.which("bash")` 找到的不是 Git Bash 而是 WSL 的 bash.exe → terminal 仍然跑在 WSL bash 中，即使 gateway 本身是 Windows 原生。

**修复方向**：
1. 在 `_find_bash()` 中优先检查 Git Bash 完整路径列表后再 fallback 到 `shutil.which("bash")`
2. 或修改 `shutil.which("bash")` 的搜索路径，排除 `C:\WINDOWS\system32\`
3. 或让 `_find_bash()` 区分 WSL bash 和 Git Bash（检测 `--version` 输出）

### `_wrap_command()` 的 bash 语法假设

`tools/environments/base.py` 的 `_wrap_command()` 生成的脚本是纯 bash 语法：

```bash
source ~/.snapshot 2>/dev/null || true
builtin cd /some/path 2>/dev/null || true
pwd -P > /tmp/cwd 2>/dev/null || true
export -p >> /tmp/snapshot 2>/dev/null || true
echo $? > /tmp/exitcode
```

这些在 PowerShell 中全部不兼容。Windows 上用 Git Bash 没遇到问题，因为 Git Bash 就是 bash。但如果在 WSL 上试图切换到 `pwsh.exe`，就会崩溃。

**可能的修法**：
1. **WSL 上不换 shell 二进制**，而是在 terminal 命令前加 `pwsh.exe -c "..."` 包装
2. 或让 `_wrap_command()` 检测 `pwsh` 并输出 PS 语法
3. 或修改 `_find_bash()` 读取 `terminal.shell` 配置 + 桥接 env var（修法更彻底但涉及 core 改动）

**关键事实**：Hermes 的 `terminal` 工具在 WSL 环境中通过 `/bin/bash` 执行命令，而不是 Windows Git Bash（即使 Git Bash 已安装）。

**用户 shell 偏好**：该用户明确偏好 `pwsh`（PowerShell 7）> Git Bash > WSL bash。任何自动 fallback 到 WSL bash 的情况都需要修复，不要接受"WSL bash 也能用"作为终局方案。如果无法直接切到 pwsh，至少切到 Git Bash。

**检测方法**：
```bash
# 在 terminal 工具中执行
echo "HOME: $HOME"    # → /home/dddog  (WSL home)
echo "SHELL: $SHELL"  # → /bin/bash
echo $0               # → /bin/bash
```

**影响**：
- `~` 解析为 `/home/dddog/`（WSL home），不是 `C:\Users\dddog\`
- Windows 路径 `C:\xxx` 需要通过 `/mnt/c/xxx` 访问
- `which`、`where` 等 Windows 命令不可用，用 `type` 代替
- 普通 Windows 命令如 `dir`、`tasklist` 在 bash 中不可用
- `&`, `|` 等符号被 bash 转义处理

**最佳实践**：
- WSL 路径格式：`/mnt/c/Users/dddog/...`
- 检查命令类型用：`type hermes` 而非 `which hermes`
- 前台长时间任务注意：`timeout N cmd` 在 bash 中不可用
- 后台任务：使用 Hermes 的 `terminal(background=true)` 配合 `process` 工具

## ⚠️ Windows 和 WSL 的 `~/.hermes/` 是独立目录

| 环境 | 位置 |
|------|------|
| Windows 原生 | `C:\Users\dddog\.hermes\` (Windows 文件系统) |
| WSL bash | `/home/dddog/.hermes/` (Linux 文件系统) |

**两者完全独立**，互不影响。修改 Windows 的 `config.yaml` 不会影响 WSL 的配置，反之亦然。

**唯一共享的部分**：
- 坚果云同步目录（`C:\Users\dddog\Nutstore\...` = WSL `/mnt/c/Users/dddog/Nutstore/...`）
- ClawMem 源码（`C:\Users\dddog\clawmem\` = WSL `/mnt/c/Users/dddog/clawmem/`）

但路径写法在各自的 .env 和 config.yaml 中各自独立配置。

## ⚠️ 终端工具 exit code 126 故障模式

**症状**：简单的 `echo hello` 也返回 exit code 126（"Command invoked cannot execute"）。pty=true 也不行。

**根因**：Hermes terminal foreground 模式通过 WSL bash（`/bin/bash`）执行命令。当 bash 子进程因之前的命令中断 / Ctrl+C 或 session 初始化失败后，整个 shell 进入不可执行状态。**即使没有后台进程也会发生**。

实测确认：
- `process list` → 空（无后台进程）
- 所有 foreground 命令 → exit 126
- background 模式（`background=true`）→ **正常工作**
- 这不是"有后台进程占用 session"，而是 foreground 模式的 bash 子进程本身已损坏

**根治**：确保 Hermes gateway 用 Windows 原生 Hermes 运行（`C:\\Users\\dddog\\AppData\\Local\\Programs\\Python\\Python312\\Scripts\\hermes.exe`），而非 WSL 别名。切过去后 `_find_bash()` 用 Git Bash，不再有 WSL bash session 损坏问题。

## ⚠️ 从 WSL bash 调用 Windows 原生 pwsh.exe

当 Hermes 跑在 WSL 别名下（terminal 工具 = WSL bash），但用户需要 Windows 原生命令时：

**背景**：Windows 原生 pwsh.exe 可通过 WSL 的 interop 机制直接从 bash 调用。Hermes background 模式下可以工作。

**pwsh.exe vs WSL pwsh 版本差异**：
| | pwsh.exe（Windows 原生） | pwsh（WSL） |
|---|---|---|
| 路径 | `/mnt/c/Program Files/PowerShell/7/pwsh.exe` 或直接 `pwsh.exe` | `/usr/bin/pwsh` |
| 版本 | 7.5.5 | 7.6.1 |
| 可访问 Windows 注册表/COM | ✅ 是 | ❌ 否 |
| 访问 WSL 文件系统 | ✅ 通过 `\\wsl.localhost\` | ✅ 原生 |

**调用模式**：

```bash
# 在 WSL bash terminal 中（background 模式）
terminal(background=true, command="pwsh.exe -NoLogo -NoProfile -Command 'Get-Process | Select -First 5'")

# 复杂命令用临时脚本文件避免转义地狱
terminal(background=true, command='pwsh.exe -NoLogo -NoProfile -File "C:\temp\script.ps1"')
```

**转义注意事项**：
- 外层 bash 双引号中 `$` 会被 bash 解释 → 用单引号包裹 PowerShell 命令
- PowerShell 的参数用单引号，整体给 bash 也用单引号 → 无法嵌套 → 改用脚本文件
- `$env:VAR` 参考：外层用 bash 单引号，内层 PowerShell 直接写 `$env:VAR`

**config.yaml 无 terminal 段**：当前配置没有 `terminal` 节，使用 Hermes 默认本地后端。如需持久化 pwsh 配置，需添加：
```yaml
terminal:
  backend: local
  shell: pwsh.exe
  cwd: C:\Users\dddog
  timeout: 180
```
（注意：Hermes local.py 目前硬编码找 bash，`shell: pwsh.exe` 需要 core 层面改动才能生效。当前最佳方案是换 Windows 原生 Hermes。）

## 🎯 实战：Gateway WSL → Windows 原生切换（已验证 2026-05-10）

### 场景
Gateway 跑在 WSL 别名下（`/home/dddog/...`），terminal 用 WSL bash，foreground 模式 exit code 126。

### 操作步骤

```bash
# 在 Hermes 会话中，用 background 模式执行切换
# 关键：foreground 会 exit 126，必须 background=true
terminal(background=true, command="pwsh.exe -NoLogo -NoProfile -Command \"C:\\Users\\dddog\\AppData\\Local\\Programs\\Python\\Python312\\Scripts\\hermes.exe gateway run --replace 2>&1\"")
```

**原理**：`--replace` 杀掉当前 WSL gateway + 启动 Windows 原生 hermes.exe。通过 `pwsh.exe` 调用确保走 Windows interop 而非 WSL 内部命令。

### 验证切换是否成功

```bash
# 从 pwsh.exe 看 hermes 进程
pwsh.exe -NoLogo -NoProfile -Command "Get-Process -Name hermes | Select-Object Id,ProcessName,Path"
# ✅ → C:\Users\dddog\AppData\Local\Programs\Python\Python312\Scripts\hermes.exe

# terminal 测试 foreground 模式
echo "test" && whoami
# ✅ → exit_code: 0，foreground 恢复正常

# terminal shell 检测
echo "SHELL=$SHELL" && pwd && which bash
# ✅ → SHELL=/usr/bin/bash, pwd=/c/Users/... (Git Bash 风格)
```

### 切换后的终端行为

| 指标 | 切换前（WSL 别名） | 切换后（Windows 原生） |
|------|------------------|---------------------|
| Gateway 进程 | WSL python → venv/bin/hermes | `C:\...\Python312\Scripts\hermes.exe` |
| Terminal shell | WSL bash `/bin/bash` | **Git Bash** `/usr/bin/bash` |
| 路径风格 | `/mnt/c/Users/...` | **`/c/Users/...`** |
| Foreground 模式 | ❌ exit code 126 | ✅ 正常 |
| `pwsh.exe` 调用 | ✅ WSL interop | ✅ 直接调 |
| config.yaml 路径 | 共享坚果云 | 共享坚果云 |

### 实战纠正：`_find_bash()` 在 Windows 原生上成功找到 Git Bash

技能之前警告说 `_find_bash()` 可能找到 WSL 的 `C:\WINDOWS\system32\bash.exe` 而非 Git Bash。**实战验证**：切到 Windows 原生后，`_find_bash()` **正确找到了 Git Bash**（`/usr/bin/bash` + `/c/` 路径前缀）。可能原因：
- Git Bash 的 `bash.exe` 在 WSL 的 `bash.exe` 之前被找到（按 `_find_bash()` 的硬编码路径列表优先匹配）
- 或系统 PATH 中 Git Bash 优先级高于 `C:\WINDOWS\system32`

结论：**切到 Windows 原生后，shell 检测通常能正常工作**，无需额外修复。但如果遇到仍走 WSL bash 的情况，才需要修改 `_find_bash()` 顺序。

### 已知注意事项

- 切换后当前会话上下文丢失（新 gateway 重新加载配置）
- WSL gateway 被杀后，其管理的 background 进程也终止
- 如果切换后仍走 WSL bash（`/mnt/c/` 路径），说明 `_find_bash()` 找到了 WSL 的 bash.exe。此时需手动改 `_find_bash()` 优先 Git Bash

## ⚠️ 关键陷阱：`hermes` 命令可能是 WSL 别名

**症状**：Gateway 日志显示 WSL 路径 (`/home/dddog/...`) 而非 Windows 路径 (`C:\Users\...`)。

**根因**：Git Bash 或 WSL bash 的 shell 启动脚本中可能定义了别名：
```bash
alias hermes='cd ~/.hermes/hermes-agent; ./venv/bin/hermes'
```
在 WSL bash 中 `~` → `/home/dddog/`，所以此时 `hermes` 实际调用的是 **WSL 的 Hermes**，而非 Windows 原生安装的 `hermes.exe`。

**检测方法**：
```bash
type hermes
# hermes is aliased to `cd ~/.hermes/hermes-agent; ./venv/bin/hermes'
```

**解决方法**：
1. 使用完整路径调用 Windows 原生 Hermes：
   ```bash
   # Git Bash / WSL bash 中
   /mnt/c/Users/dddog/AppData/Local/Programs/Python/Python312/Scripts/hermes.exe

   # 或 Windows CMD/PowerShell
   C:\Users\dddog\AppData\Local\Programs\Python\Python312\Scripts\hermes.exe
   ```
2. 或在 WSL bash 中临时绕过别名：
   ```bash
   \hermes              # 反斜杠前缀跳过别名
   command hermes       # command 前缀跳过别名
   /usr/bin/env hermes  # 全路径
   ```
3. 或修改 `~/.bashrc` 删除该别名。

> 💡 Windows 原生 Hermes 的 pip 安装位置：
> `C:\Users\dddog\AppData\Local\Programs\Python\Python312\Scripts\hermes.exe`
> 对应 WSL 挂载路径：
> `/mnt/c/Users/dddog/AppData/Local/Programs/Python/Python312/Scripts/hermes.exe`

### ⚠️ 使用 `--replace` 重启 Gateway 会连带杀掉当前 CLI 会话

**症状**：在 CLI 会话中执行 `hermes gateway run --replace` 后，当前 CLI 会话也退出了。

**根因**：`gateway.py` 中 `_scan_gateway_pids()` 用命令行模式匹配进程：

```python
patterns = ["hermes_cli.main gateway", "hermes gateway", "gateway/run.py", ...]
```

`--replace` 的流程：
1. `find_gateway_pids()` → 匹配所有含 "hermes gateway" 的进程
2. `_get_ancestor_pids()` → 排除当前进程的祖先链
3. 剩余 PID 全部发送 SIGTERM

**Windows 上的 bug**：`_get_ancestor_pids()` 在 Linux 上通过遍历 `/proc/` 获取父进程链，但在 Windows 上没有实现（回退为空集）。加上 WSL interop 的 `/init` 容器会作为父进程插入，进一步打破祖先链。结果是当前 CLI 会话不被排除 → 被误杀。

**WSL 上正常**：因为 Linux procfs 能正确追踪父进程链。

**解决方法**：不要在 CLI 会话内用 `--replace`。改用以下方式：

```bash
# 方式 A（推荐）：从 PowerShell 启动，不经过 WSL interop
powershell.exe -Command "Start-Process -WindowStyle Hidden -FilePath 'C:\Users\dddog\AppData\Local\Programs\Python\Python312\Scripts\hermes.exe' -ArgumentList 'gateway run'"

# 方式 B：从 Hermes terminal（background 模式）启动
terminal(background=true, command="powershell.exe -Command \"Start-Process -WindowStyle Hidden -FilePath 'C:\\Users\\dddog\\AppData\\Local\\Programs\\Python\\Python312\\Scripts\\hermes.exe' -ArgumentList 'gateway run'\"")

# 方式 C：从 Windows 原生终端（PowerShell/CMD）直接启动
# C:\Users\dddog\AppData\Local\Programs\Python\Python312\Scripts\hermes.exe gateway run
```

### ⚠️ 双 Gateway 共存冲突

**症状**：WSL 和 Windows 各有一个 Gateway 在运行，微信消息被 WSL 的 Gateway 处理，而不是 Windows 原生的。

**根因**：`hermes.exe gateway run --replace` 从 WSL bash 中执行时，通过 WSL interop 转发，可能不会正确杀掉 WSL 端的 hermes 进程。两个 Gateway 各自监听不同的端口/资源，但都尝试连接同一个 WeChat 账号，先连上的处理消息。

**快速检测双 Gateway**：
```bash
# 从 WSL bash 看有没有 WSL 的 hermes 进程
ps aux | grep hermes | grep -v grep

# 从 Windows pwsh 看有没有 Windows 原生 hermes
pwsh.exe -NoLogo -NoProfile -Command "Get-Process -Name hermes -ErrorAction SilentlyContinue | Select-Object Id,ProcessName,Path"
```

如果两边都有，说明双 Gateway 共存。解决方案见下方。

### Gateway 切换操作指南（WSL → Windows 原生）

**前提**：当前 gateway 跑在 WSL 别名下（terminal 中 `HOME=/home/dddog/`，`sys.platform=linux`）。

**操作步骤**：

```bash
# 1. 在 Hermes 会话中，用 background 模式执行切换
#    注意：不能用 foreground（exit 126），必须 background=true
terminal(background=true, command="pwsh.exe -NoLogo -NoProfile -Command \"C:\Users\dddog\AppData\Local\Programs\Python\Python312\Scripts\hermes.exe gateway run --replace 2>&1\"")
```

`--replace` 会：
- 杀死当前 WSL gateway
- 启动 Windows 原生 hermes.exe gateway

**验证切换是否成功**：
```bash
# terminal 内执行（注意：切换后 terminal 后端仍然可能是 WSL bash）
echo "HOME=$HOME"     # 如果还是 /home/dddog 说明 terminal 后端没变
echo "PLATFORM=$(python3 -c 'import sys; print(sys.platform)')"  # still "linux"

# 从 pwsh.exe 看真正的 hermes 进程
pwsh.exe -NoLogo -NoProfile -Command "Get-Process -Name hermes | Select-Object Id,ProcessName,Path"
# → 应输出 C:\Users\dddog\AppData\Local\Programs\Python\Python312\Scripts\hermes.exe
```

**关键陷阱：切换后 terminal 后端仍用 WSL bash**

即使 gateway 跑在 Windows 原生 hermes.exe 上，`_find_bash()` 在 Windows 上的查找顺序是：
1. Git Bash（`C:\Program Files\Git\bin\bash.exe`）
2. 退到系统 PATH 中的 `bash.exe`（`C:\WINDOWS\system32\bash.exe` → WSL bash launcher）
3. 退到 `powershell.exe`

如果系统 PATH 里有 WSL 的 `bash.exe`（默认安装 WSL 后就有），它会被优先于 Git Bash 找到 → terminal 继续用 WSL bash。

**解决**：修改 `_find_bash()` 检测顺序（见下方 `_find_bash()` 修复章节），或从 PATH 中去掉 `C:\WINDOWS\system32` 中的 WSL bash 入口。

**如果切换后双 gateway 共存**：

```bash
# 从 WSL bash 中手动杀掉 WSL gateway 进程
ps aux | grep hermes | grep -v grep | awk '{print $2}' | xargs kill

# 确认只剩 Windows 原生 gateway
pwsh.exe -NoLogo -NoProfile -Command "Get-Process -Name hermes | Select-Object Id,ProcessName,Path"
```

**检测方法**：
```bash
# 在 WSL bash 中查看所有 hermes 进程
ps aux | grep hermes | grep -v grep

# 如果有 python 进程（/home/dddog/...）就是 WSL 的
# 如果有 hermes.exe 且带 /init 前缀就是 WSL interop 转发的
```

**解决**：从 Windows 侧（PowerShell）使用 `Start-Process` 启动，不经过 WSL bash。同时手动杀掉 WSL 侧的 hermes 进程：
```bash
# 1. 在 WSL bash 中杀掉 WSL 的 hermes 进程
kill <pid>

# 2. 从 PowerShell 启动 Windows 原生 Gateway（不经过 WSL）
powershell -Command "Start-Process -WindowStyle Hidden -FilePath 'C:\Users\dddog\AppData\Local\Programs\Python\Python312\Scripts\hermes.exe' -ArgumentList 'gateway run'"
```

### ⚠️ Gateway 微信平台默认没有 terminal 工具

**症状**：微信上给 Hermes 发消息，回复说"终端不可用"/"file tools not found"。

**根因**：`config.yaml` 的 `platform_toolsets` 中没有 `weixin` 条目，导致微信平台只有空工具集。CLI 配了 toolset 不代表 Gateway 平台自动继承。

**修复**：
```yaml
platform_toolsets:
  weixin:
  - hermes-cli      # 给微信加上终端等工具
```

## Windows 原生 Hermes 卸载清理

当从 Windows 原生 Hermes 迁移到 WSL Hermes 后，需手动清理以下残留：

### 需要删除的文件/目录

```
C:\Users\<user>\AppData\Local\hermes\gateway-service\   — Windows 原生启动脚本目录
C:\Users\<user>\AppData\Local\hermes\gateway.lock       — 旧 gateway 锁文件
C:\Users\<user>\AppData\Local\hermes\gateway.pid        — 旧 gateway PID 文件
C:\Users\<user>\AppData\Local\hermes\gateway_state.json — 旧 gateway 状态文件
```

### 需要删除的符号链接（只删链接，不删目标）

```
C:\Users\<user>\AppData\Local\hermes\skills    → 指向坚果云同步目录（只删链接）
C:\Users\<user>\AppData\Local\hermes\memories  → 指向坚果云同步目录（只删链接）
```

⚠️ **删除前确认符号链接目标目录安全**，坚果云原始数据不受影响。

### 需要清理的注册表项

- 用户 PATH 中的 `C:\Users\<user>\AppData\Local\hermes\hermes-agent\venv\Scripts`
- 用户环境变量 `HERMES_HOME`

### 不需要删除的

- `C:\Users\<user>\AppData\Local\hermes\.env` — WSL hermes 也在用（如果已迁移则保留）
- `C:\Users\<user>\AppData\Local\hermes\config.yaml` — 同上
- `C:\Users\<user>\.local\bin\uv.exe` — uv 可能被其他项目使用，不强制卸载

## WSL Gateway 开机自启方案

### 当前方案：systemd + Windows 计划任务（双层保活）

**Layer 1 — WSL systemd 服务**（WSL 内）：
```bash
hermes gateway install --force   # 注册 systemd user 服务
hermes gateway start             # 启动服务
```

服务文件含保活配置：`Restart=always`、`RestartSec=60`、`RestartMaxDelaySec=300`

**Layer 2 — Windows 计划任务**（开机触发）：
```powershell
$action = New-ScheduledTaskAction -Execute "wsl.exe" -Argument "--user kangle -- systemctl --user start hermes-gateway"
$trigger = New-ScheduledTaskTrigger -AtLogon -User "kangle"
Register-ScheduledTask -TaskName "HermesGateway" -Action $action -Trigger $trigger -Force
```

### 前提条件

1. WSL 已启用 systemd（`/etc/wsl.conf` 中 `[boot] systemd=true`）
2. 用户 linger 已启用（`loginctl show-user kangle --property=Linger` → `yes`）

### 验证命令

```powershell
# Windows 侧检查 WSL gateway 状态
wsl.exe --user kangle -- systemctl --user is-active hermes-gateway

# WSL 内检查
systemctl --user status hermes-gateway
```

## 开机自启方案对比

### 方案 A: Windows 原生 Hermes → Task Scheduler（已弃用）

Windows 原生 Hermes 安装时通过 Task Scheduler + Startup 文件夹 + Watchdog 实现三层保活。详情见已删除的 `wsl-gateway-autostart-disable.md`。

### 方案 B: WSL Hermes → 三层架构（当前活跃）

当前系统仅运行 WSL Hermes，使用三层自启保活架构：

1. **Layer 1 — keepalive 脚本** (`~/.hermes/gateway-start.sh`)：`setsid` 启动 gateway，30秒检查一次，崩溃自动重启
2. **Layer 2 — Windows 自启** (`hermes-wsl-startup.bat`)：通过 Startup 文件夹 .lnk 或 Task Scheduler 在登录时执行 `wsl.exe -d Ubuntu-24.04 -e bash ~/.hermes/gateway-start.sh`
3. **Layer 3 — .bashrc 补启**：手动打开 WSL 终端时检测 gateway 状态并补启

详细实现、部署步骤、验证方法和已知问题 → `references/wsl-gateway-autostart-with-keepalive.md`

### 微信 (iLink) 扫码登录 — Windows 原生

### 前置条件

```bash
pip install aiohttp cryptography  # 微信适配器依赖
```

### 扫码流程

在 Windows 上运行 WeChat QR 登录有两种方式：

**方式 A：交互式向导（推荐）**
```bash
C:\Users\dddog\AppData\Local\Programs\Python\Python312\Scripts\hermes.exe gateway setup
# → 选 Weixin / WeChat → 扫码 → 自动保存 token
```

**方式 B：直接调 API（不推荐）**
```python
python -c "
from gateway.platforms.weixin import qr_login, check_weixin_requirements
from hermes_constants import get_hermes_home
import asyncio
creds = asyncio.run(qr_login(str(get_hermes_home())))
"
```

### 关键陷阱：iLink API 字段名映射

**问题**：`qr_login()` 函数内部调用的 iLink `get_qrcode_status` API 返回的字段名与外层期望的不一致：

| API 返回字段 | 外层期望字段 |
|-------------|------------|
| `bot_token` | `token` |
| `ilink_bot_id` | `account_id` |
| `ilink_user_id` | `user_id` |

`qr_login()` 函数内部有字段名映射代码。**如果自行调用 API，必须手动映射字段名**，不要直接 `data.get('token')`。

### 验证环境变量：
```bash
grep WEIXIN_ ~/.hermes/.env
```

### DM 配对批准

iLink 二维码约 **3-5 分钟**内有效，之后需要重新生成。超时后 API 返回 `status: "expired"`。

### Naming 区分（备份日志）

Windows 原生备份文件名带 `-win` 后缀以区分 WSL 版本：
```
woking-win_MEMORY_20260509.md   ← Windows 原生
wooking_MEMORY_20260509.md      ← WSL 版本
desktop-4jfhq88_MEMORY_20260509.md ← kangle 机器
```

## ClawMem 路径转换（WSL → Windows）

从 WSL 迁移到 Windows 原生时，ClawMem 配置中的路径需要全部转换：

| 配置项 | WSL 路径 | Windows 路径 |
|--------|---------|-------------|
| `CLAWMEM_MEMORY_DIR` | `/mnt/c/Users/.../wiki/raw/memory` | `C:\Users\...\wiki\raw\memory` |
| MCP 脚本 | `/mnt/c/Users/dddog/clawmem/dist/mcp-server.js` | `C:\Users\dddog\clawmem\dist\mcp-server.js` |
| Hook 脚本 | `/mnt/c/Users/dddog/clawmem/src/hooks/*.mjs` | `C:\Users\dddog\clawmem\src\hooks\*.mjs` |

**转换位置**（两处都要改）：
- `~/.hermes/.env` - `CLAWMEM_MEMORY_DIR`
- `~/.hermes/config.yaml` - hooks 命令路径 + MCP server args

**注意**：`.env` 中路径用正斜杠或双反斜杠，直接写 `\U` 会被解析为 Unicode escape。
```python
# 正确写法：
# CLAWMEM_MEMORY_DIR=C:/Users/dddog/...      # 正斜杠（推荐）
# CLAWMEM_MEMORY_DIR=C:\\Users\\dddog\\...    # 双反斜杠
```

### ⚠️ `.env` 反斜杠转义陷阱（高频踩坑）

在 **bash terminal** 中通过 `node -e`、`python -c` 或 `sed` 修改 `.env` 文件时，反斜杠会被多层转义：

| 层 | 转义行为 |
|---|---------|
| bash | `\\` → `\` |
| Node.js string | `\U` → Unicode escape （报错） |
| Node.js string | `\1` → SOH 控制字符 |
| Node.js string | `\r` → 回车（`raw` → `aw`） |
| sed replacement | `\1` → 反向引用（报错） |

**正确的修改方式**：
```bash
# Node.js：用正斜杠 + 正则替换（避免字符串转义）
node -e "var fs=require('fs');var c=fs.readFileSync('C:/Users/dddog/.hermes/.env','utf8');c=c.replace(/CLAWMEM_MEMORY_DIR=.*/,'CLAWMEM_MEMORY_DIR=C:/Users/dddog/Nutstore/1/myNutstore/hermes-sync/wiki/raw/memory');fs.writeFileSync('C:/Users/dddog/.hermes/.env',c);"

# 或者用 Python（注意 r 前缀 raw string）
python -c "import pathlib; p=pathlib.Path('C:/Users/dddog/.hermes/.env'); p.write_text(p.read_text().replace('old_path', r'C:\Users\dddog\new\path'))"
```

## ⚠️ write_file 写入 0 字节故障

**症状**：`write_file` 成功返回但 `bytes_written: 0`，文件实际未写入。

**触发条件**：路径中包含特殊字符（中文、`⚠️`、emoji），或路径过长，或文件系统不可达。

**解决方法**（按可靠度排序）：

1. ✅ **node -e 写脚本文件 → 执行脚本**（最可靠，避免 bash 转义）：
   ```bash
   # 先写一个临时脚本
   node -e "fs.writeFileSync('/tmp/write.js', 'var fs=require(\"fs\");var content=JSON.parse(process.argv[1]);fs.writeFileSync(process.argv[2],content);console.log(\"OK\");')"
   # 再用 JSON 传内容（避免 bash 转义内容中的特殊字符）
   node /tmp/write.js '{"content":"你的文件内容"}' 'C:/path/to/file.md'
   ```

2. ✅ **pwsh.exe -c "Set-Content ..."**（适合纯内容，path 用单引号避免 $ 转义）：
   ```bash
   pwsh.exe -NoLogo -NoProfile -Command "Set-Content -Path 'C:\\path\\to\\file.md' -Value '内容' -Encoding UTF8"
   ```

3. ⚠️ **node -e 直接写**（仅限纯文本，无换行/引号/特殊字符）：
   ```bash
   node -e "fs.writeFileSync('path', 'text')"
   ```

4. ❌ **base64** — 不可靠（base64 解码遇中文编码失效）

**如果多次尝试写入失败**（如路径不存在、bash 转义导致命令损坏），**立即停止尝试，直接将文本内容发给用户**。用户明确指示过："如果写不了，发文本给我"。

## ⚠️ OpenRouter max_tokens 截断陷阱

**症状**：模型回复末尾出现 `⚠️ Response truncated due to output length limit`。

**根因**：`config.yaml` 中 `model.max_tokens` 设置超过了模型/API 的实际输出上限。OpenRouter 对某些模型有服务端硬限制，超出后直接截断并追加警告。

**受影响模型**：`openrouter/owl-alpha`、可能还有其他通过 OpenRouter 中转的模型。

**解决**：将 `max_tokens` 降低到模型能力范围内（如 8192），而不是调到模型理论上限（16384）：
```yaml
model:
  max_tokens: 8192   # 不是 16384
```

**验证**：降低后长回复不再出现截断提示。

## 验证步骤

```powershell
# 1. 确认当前用的是 Windows 原生 Hermes
# 如果 type hermes 显示 alias，用完整路径
C:\Users\dddog\AppData\Local\Programs\Python\Python312\Scripts\hermes.exe --version

# 2. 检查 Gateway 日志确认是 Windows 路径
# 正常：Session storage: C:\Users\dddog\.hermes\sessions
# 异常：Session storage: /home/dddog/.hermes/sessions

# 3. 启动 Gateway（Windows 原生）
C:\Users\dddog\AppData\Local\Programs\Python\Python312\Scripts\hermes.exe gateway run --replace

# 4. 查看日志确认平台状态
type C:\Users\dddog\.hermes\logs\gateway.log
```

## 从 WSL 迁移后的环境变量清理

将 Windows 原生 Hermes 从 WSL 配置迁移过来时，以下环境变量需要更新：

### API_SERVER_HOST

WSL 的 `API_SERVER_HOST` 通常是 WSL 内网 IP（如 `100.67.91.123`），Windows 上绑定失败。改成 `127.0.0.1`：

```bash
# .env
API_SERVER_HOST=127.0.0.1
```

### WEIXIN_TOKEN

WSL 时代的微信 token 会过期。迁移后需重新扫码：

```bash
# 用 Windows 原生 Hermes 重配微信
"C:\Users\dddog\AppData\Local\Programs\Python\Python312\Scripts\hermes.exe" gateway setup
# → 选 Weixin / WeChat → 扫码 → 自动保存新 token
```

### Gateway 日志排查

```bash
# 查看微信连接状态
grep weixin C:\\Users\\dddog\\.hermes\\logs\\gateway.log

# 正常输出：
# [Weixin] Connected account=xxx base=https://ilinkai.weixin.qq.com
# ✓ weixin connected

# 异常输出（token 过期）：
# [Weixin] Session expired; pausing for 10 minutes
```

## ⚠️ kanban.db 损坏导致 gateway 频繁崩溃

**症状**：日志 `~/.hermes/logs/gateway-autostart.log` 出现大量连续 ERROR（数百条），正常的心跳/重启记录被淹没：

```
sqlite3.DatabaseError: file is not a database
ERROR gateway.run: kanban dispatcher: tick failed on board default
```

**影响**：
- gateway 进程 crash 后 keepalive 会重启，但 kanban.db 损坏导致重启后继续 crash
- 日志被 ERROR 刷屏（460KB+），真实的 keepalive 行为难以追踪
- 看起来像"半夜12点才自启"，实际是 keepalive 在持续工作但 gateway 反复崩溃

**根因**：`gateway/run.py` 的 kanban 调度器在每次 tick 时打开 `kanban.db`，文件损坏后 `PRAGMA journal_mode=WAL` 失败。

**修复方法**：

```bash
# 1. 备份损坏的数据库
cp ~/.hermes/kanban.db ~/.hermes/kanban.db.bak.$(date +%Y%m%d)

# 2. 删除损坏文件，gateway 重启时会自动重建
rm ~/.hermes/kanban.db

# 3. 重启 gateway 使其重建数据库
kill $(pgrep -f 'hermes.*gateway.*run')
```

**验证**：
```bash
# ERROR 消失
grep -c ERROR ~/.hermes/logs/gateway-autostart.log
# 应该从数百降到 0 或个位数
```

**排查技巧**：当日志被刷屏时，查看真实 keepalive 行为：
```bash
grep -E "Starting Hermes|Gateway dead|Gateway started|already running" \
  ~/.hermes/logs/gateway-autostart.log | tail -20
```

## Windows 计划任务黑窗问题（2026-05-23）

### 症状

计划任务每 5 分钟运行 `wsl-check-gateway.bat`，每次弹出一个 cmd.exe 黑窗。

### 根因

1. `.bat` 由 `schtasks` 触发时总是弹窗（bat 本身没有隐藏机制）
2. PowerShell 脚本（`.ps1`）也缺少 `-WindowStyle Hidden`

### 修复

**已删除旧计划任务**：
```powershell
schtasks /Delete /TN "HermesWSLGateway" /F
```

**已修复脚本**（`wsl-check-gateway.ps1` + `wsl-check-gateway.bat`）——`C:\Users\dddog\.hermes\scripts\` 下已更新。

### 当前保活方案

当前 WSL Gateway 使用 **systemd user 服务 + `gateway-start.sh`** 双重保活，**无需 Windows 计划任务**。

计划任务仅用于**开机后快速检测补启**（前提是 WSL systemd linger 未生效时）。如果以后需要重建计划任务，务必加上 `-WindowStyle Hidden`：

```powershell
$action  = New-ScheduledTaskAction  -Execute "powershell.exe" -Argument "-NoLogo -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File C:\Users\dddog\.hermes\scripts\wsl-check-gateway.ps1"
$trigger = New-ScheduledTaskTrigger -AtLogon -User "dddog"
Register-ScheduledTask -TaskName "HermesWSLGateway" -Action $action -Trigger $trigger -Force
```

## WSL Tailscale DNS 拦截与绕过（2026-05-23 实证）

### 现象

WSL 内 `curl https://github.com/...`、`apt install gh`（连接 `security.ubuntu.com`）全部超时：

```
curl: (28) Operation timed out
apt: Error reading from server. Remote end closed connection [IP: 198.18.1.65 80]
```

### 根因

WSL 的 `/etc/resolv.conf` 使用 Tailscale MagicDNS（`100.100.100.100`），GitHub 等域名被解析到 `198.18.x.x`（Tailscale DNS 拦截代理地址），连接超时。

### 绕过方法

**方案 A：`curl --resolve`（推荐，临时绕过）**

```bash
curl --resolve github.com:443:140.82.112.3 -L -o /tmp/gh.tar.gz "https://github.com/..."
```

已知稳定 CDN IP：`140.82.112.3`、`140.82.113.3`、`140.82.114.3`

**方案 B：`/etc/hosts` 静态绑定（持久化）**

```bash
echo "140.82.112.3 github.com api.github.com" | sudo tee -a /etc/hosts
```

### 实战：安装 gh CLI

```bash
curl --resolve github.com:443:140.82.112.3 -o /tmp/gh.tar.gz -L \
  "https://github.com/cli/cli/releases/download/v2.67.0/gh_2.67.0_linux_amd64.tar.gz"
tar xzf /tmp/gh.tar.gz -C /tmp
sudo cp /tmp/gh_*/bin/gh /usr/local/bin/
```
