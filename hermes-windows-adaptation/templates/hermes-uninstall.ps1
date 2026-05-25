# ============================================================================
# Hermes Agent Uninstaller for Windows
# ============================================================================
# 逆向 install.ps1 的所有操作
# 用法: powershell -ExecutionPolicy ByPass -File hermes-uninstall.ps1
#
# 参数:
#   -KeepConfig    保留 .env 和 config.yaml
#   -KeepUv        不卸载 uv
#   -KeepGit       不卸载 PortableGit
#   -KeepNode      不卸载 portable Node.js
#   -DryRun        只显示要删除什么，不实际执行
# ============================================================================

param(
    [switch]$KeepConfig,
    [switch]$KeepUv,
    [switch]$KeepGit,
    [switch]$KeepNode,
    [switch]$DryRun
)

$ErrorActionPreference = "Continue"

$HermesHome = "$env:LOCALAPPDATA\hermes"
$InstallDir = "$env:LOCALAPPDATA\hermes\hermes-agent"

function Write-Info { param([string]$m) Write-Host "-> $m" -ForegroundColor Cyan }
function Write-OK   { param([string]$m) Write-Host "[OK] $m" -ForegroundColor Green }
function Write-Warn { param([string]$m) Write-Host "[!] $m" -ForegroundColor Yellow }
function Write-Err  { param([string]$m) Write-Host "[X] $m" -ForegroundColor Red }

function Remove-Path {
    param([string]$Dir)
    $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($currentPath -like "*$Dir*") {
        $newPath = ($currentPath -split ";" | Where-Object { $_ -and $_ -ne $Dir }) -join ";"
        if (-not $DryRun) {
            [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
        }
        Write-OK "Removed from user PATH: $Dir"
    } else {
        Write-Info "Not in PATH (already clean): $Dir"
    }
}

function Remove-EnvVar {
    param([string]$Name)
    $val = [Environment]::GetEnvironmentVariable($Name, "User")
    if ($val) {
        if (-not $DryRun) {
            [Environment]::SetEnvironmentVariable($Name, $null, "User")
        }
        Write-OK "Removed env var: $Name (was: $val)"
    } else {
        Write-Info "Env var not set: $Name"
    }
}

function Remove-Dir {
    param([string]$Path, [string]$Desc)
    if (Test-Path $Path) {
        # 检查是否是 junction/symlink，只删链接不删目标
        $item = Get-Item $Path -Force -ErrorAction SilentlyContinue
        if ($item -and ($item.Attributes -match "ReparsePoint")) {
            if ($DryRun) {
                Write-Warn "[DRY RUN] Would remove junction: $Path -> $($item.Target)"
            } else {
                # 用 cmd rmdir 删除 junction，不影响目标目录
                cmd /c "rmdir `"$Path`"" 2>$null
                if (-not (Test-Path $Path)) {
                    Write-OK "Removed junction: $Path (target preserved: $($item.Target))"
                } else {
                    Write-Err "Failed to remove junction: $Path"
                }
            }
        } else {
            if ($DryRun) {
                Write-Warn "[DRY RUN] Would delete: $Path ($Desc)"
            } else {
                Remove-Item -Recurse -Force $Path -ErrorAction SilentlyContinue
                if (-not (Test-Path $Path)) {
                    Write-OK "Deleted: $Path ($Desc)"
                } else {
                    Write-Err "Failed to delete: $Path — may need to kill running processes first"
                }
            }
        }
    } else {
        Write-Info "Not found (already clean): $Path"
    }
}

# ============================================================================
# 1. 停止正在运行的 hermes 进程
# ============================================================================
Write-Host ""
Write-Info "Step 1: Stopping hermes processes..."
$procs = Get-Process -Name "hermes" -ErrorAction SilentlyContinue
if ($procs) {
    foreach ($p in $procs) {
        if ($DryRun) {
            Write-Warn "[DRY RUN] Would kill: PID=$($p.Id) Path=$($p.Path)"
        } else {
            Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
            Write-OK "Killed hermes process: PID=$($p.Id)"
        }
    }
} else {
    Write-Info "No running hermes processes found"
}

# ============================================================================
# 2. 从 PATH 中移除 hermes venv Scripts 目录
# ============================================================================
Write-Host ""
Write-Info "Step 2: Cleaning user PATH..."
Remove-Path -Dir "$InstallDir\venv\Scripts"

# ============================================================================
# 3. 删除 HERMES_HOME 环境变量
# ============================================================================
Write-Host ""
Write-Info "Step 3: Removing environment variables..."
Remove-EnvVar -Name "HERMES_HOME"

# ============================================================================
# 4. 删除安装目录 (hermes-agent 仓库 + venv)
# ============================================================================
Write-Host ""
Write-Info "Step 4: Removing hermes-agent installation..."
# 先杀可能占用文件的 python 进程
Get-Process -Name "python" -ErrorAction SilentlyContinue | Where-Object {
    $_.Path -like "*hermes-agent*"
} | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
Remove-Dir -Path $InstallDir -Desc "hermes-agent repo + venv"

# ============================================================================
# 5. 删除 PortableGit
# ============================================================================
if (-not $KeepGit) {
    Write-Host ""
    Write-Info "Step 5: Removing PortableGit..."
    Remove-Dir -Path "$HermesHome\git" -Desc "PortableGit"
} else {
    Write-Host ""
    Write-Info "Step 5: Skipping PortableGit removal (-KeepGit)"
}

# ============================================================================
# 6. 删除 portable Node.js
# ============================================================================
if (-not $KeepNode) {
    Write-Host ""
    Write-Info "Step 6: Removing portable Node.js..."
    Remove-Dir -Path "$HermesHome\node" -Desc "portable Node.js"
} else {
    Write-Host ""
    Write-Info "Step 6: Skipping portable Node.js removal (-KeepNode)"
}

# ============================================================================
# 7. 删除符号链接（skills, memories）— 只删链接，不碰坚果云原始数据
# ============================================================================
Write-Host ""
Write-Info "Step 7: Removing junctions/symlinks..."
@("$HermesHome\skills", "$HermesHome\memories") | ForEach-Object {
    Remove-Dir -Path $_ -Desc "junction to cloud sync dir"
}

# ============================================================================
# 8. 删除配置和数据目录
# ============================================================================
if (-not $KeepConfig) {
    Write-Host ""
    Write-Info "Step 8: Removing config and data..."
    @(
        "$HermesHome\.env",
        "$HermesHome\config.yaml",
        "$HermesHome\sessions",
        "$HermesHome\logs",
        "$HermesHome\cron",
        "$HermesHome\cache",
        "$HermesHome\checkpoints"
    ) | ForEach-Object {
        Remove-Dir -Path $_ -Desc "data"
    }

    # 最后删除 hermes 主目录（如果为空）
    if (Test-Path $HermesHome) {
        $remaining = Get-ChildItem $HermesHome -Force -ErrorAction SilentlyContinue
        if ($remaining.Count -eq 0) {
            Remove-Dir -Path $HermesHome -Desc "hermes home (empty)"
        } else {
            Write-Warn "$HermesHome is not empty, skipping. Remaining:"
            $remaining | ForEach-Object { Write-Host "  $($_.Name)" }
        }
    }
} else {
    Write-Host ""
    Write-Info "Step 8: Skipping config/data removal (-KeepConfig)"
    Write-Warn "Config files remain at: $HermesHome"
}

# ============================================================================
# 9. 卸载 uv
# ============================================================================
if (-not $KeepUv) {
    Write-Host ""
    Write-Info "Step 9: Removing uv..."
    $uvPaths = @(
        "$env:USERPROFILE\.local\bin\uv.exe",
        "$env:USERPROFILE\.cargo\bin\uv.exe"
    )
    foreach ($uvPath in $uvPaths) {
        if (Test-Path $uvPath) {
            if ($DryRun) {
                Write-Warn "[DRY RUN] Would delete: $uvPath"
            } else {
                Remove-Item $uvPath -Force
                Write-OK "Deleted: $uvPath"
            }
        }
    }
    # 删除 uv 缓存
    $uvCache = "$env:LOCALAPPDATA\uv"
    if (Test-Path $uvCache) {
        Remove-Dir -Path $uvCache -Desc "uv cache"
    }
} else {
    Write-Host ""
    Write-Info "Step 9: Skipping uv removal (-KeepUv)"
}

# ============================================================================
# 完成
# ============================================================================
Write-Host ""
Write-Host "+---------------------------------------------------------+" -ForegroundColor Green
Write-Host "|           Hermes Agent Uninstall Complete               |" -ForegroundColor Green
Write-Host "+---------------------------------------------------------+" -ForegroundColor Green
Write-Host ""
Write-Info "You may need to restart your terminal for PATH changes to take effect."
Write-Host ""
