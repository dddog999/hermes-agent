# ============================================================================
# Hermes Agent Uninstaller for Windows
# ============================================================================
# 逆向 install.ps1 的所有操作
# 用法: powershell -ExecutionPolicy ByPass -File hermes-uninstall.ps1
# ============================================================================

param(
    [switch]$KeepConfig,      # 保留 .env 和 config.yaml
    [switch]$KeepUv,          # 不卸载 uv
    [switch]$KeepGit,         # 不卸载 PortableGit
    [switch]$KeepNode,        # 不卸载 portable Node.js
    [switch]$DryRun           # 只显示要删除什么，不实际执行
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
        $item = Get-Item $Path -ErrorAction SilentlyContinue
        $isReparse = $item -and ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)
        
        if ($DryRun) {
            Write-Warn "[DRY RUN] Would delete: $Path ($Desc)"
        } elseif ($isReparse) {
            # junction/symlink: 用 cmd rmdir 只删链接
            cmd /c "rmdir `"$Path`"" 2>&1 | Out-Null
            if (-not (Test-Path $Path)) {
                Write-OK "Removed junction/symlink: $Path ($Desc, target preserved)"
            } else {
                Write-Err "Failed to remove junction: $Path"
            }
        } else {
            Remove-Item -Recurse -Force $Path -ErrorAction SilentlyContinue
            if (-not (Test-Path $Path)) {
                Write-OK "Deleted: $Path ($Desc)"
            } else {
                Write-Err "Failed to delete: $Path"
            }
        }
    } else {
        Write-Info "Not found (already clean): $Path"
    }
}

function Remove-File {
    param([string]$Path, [string]$Desc)
    if (Test-Path $Path) {
        if ($DryRun) {
            Write-Warn "[DRY RUN] Would delete: $Path ($Desc)"
        } else {
            Remove-Item -Force $Path -ErrorAction SilentlyContinue
            Write-OK "Deleted: $Path ($Desc)"
        }
    } else {
        Write-Info "Not found (already clean): $Path"
    }
}

# ============================================================================
Write-Host ""
Write-Host "+---------------------------------------------------------+" -ForegroundColor Yellow
Write-Host "|          Hermes Agent Uninstaller for Windows            |" -ForegroundColor Yellow
Write-Host "+---------------------------------------------------------+" -ForegroundColor Yellow
if ($DryRun) { Write-Host "  *** DRY RUN MODE - no changes will be made ***" -ForegroundColor Magenta }
Write-Host ""

# 1. 停止进程
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

# 2. 清理 PATH
Write-Host ""
Write-Info "Step 2: Cleaning user PATH..."
Remove-Path -Dir "$InstallDir\venv\Scripts"

# 3. 删除环境变量
Write-Host ""
Write-Info "Step 3: Removing environment variables..."
Remove-EnvVar -Name "HERMES_HOME"

# 4. 删除安装目录
Write-Host ""
Write-Info "Step 4: Removing hermes-agent installation..."
Remove-Dir -Path $InstallDir -Desc "hermes-agent repo + venv"

# 5. PortableGit
if (-not $KeepGit) {
    Write-Host ""
    Write-Info "Step 5: Removing PortableGit..."
    Remove-Dir -Path "$HermesHome\git" -Desc "PortableGit"
} else {
    Write-Host ""
    Write-Info "Step 5: Skipping PortableGit removal (-KeepGit)"
}

# 6. portable Node.js
if (-not $KeepNode) {
    Write-Host ""
    Write-Info "Step 6: Removing portable Node.js..."
    Remove-Dir -Path "$HermesHome\node" -Desc "portable Node.js"
} else {
    Write-Host ""
    Write-Info "Step 6: Skipping portable Node.js removal (-KeepNode)"
}

# 7. 配置和数据
if (-not $KeepConfig) {
    Write-Host ""
    Write-Info "Step 7: Removing config and data..."
    
    # 安全删除符号链接
    Remove-Dir -Path "$HermesHome\skills" -Desc "skills junction (target preserved)"
    Remove-Dir -Path "$HermesHome\memories" -Desc "memories junction (target preserved)"
    
    # 删除文件
    Remove-File -Path "$HermesHome\.env" -Desc "API keys"
    Remove-File -Path "$HermesHome\config.yaml" -Desc "config"
    
    # 删除目录
    Remove-Dir -Path "$HermesHome\sessions" -Desc "sessions"
    Remove-Dir -Path "$HermesHome\logs" -Desc "logs"
    Remove-Dir -Path "$HermesHome\cron" -Desc "cron jobs"
    Remove-Dir -Path "$HermesHome\cache" -Desc "cache"
    Remove-Dir -Path "$HermesHome\checkpoints" -Desc "checkpoints"
    
    # 最后删除主目录（如果为空）
    if (Test-Path $HermesHome) {
        $remaining = Get-ChildItem $HermesHome -Force -ErrorAction SilentlyContinue
        if ($remaining.Count -eq 0) {
            Remove-Dir -Path $HermesHome -Desc "hermes home (empty)"
        } else {
            Write-Warn "$HermesHome is not empty, skipping. Remaining items:"
            $remaining | ForEach-Object { Write-Host "  $($_.Name)" }
        }
    }
} else {
    Write-Host ""
    Write-Info "Step 7: Skipping config/data removal (-KeepConfig)"
    Write-Warn "Config files remain at: $HermesHome"
}

# 8. uv
if (-not $KeepUv) {
    Write-Host ""
    Write-Info "Step 8: Uninstalling uv..."
    $uvExe = "$env:USERPROFILE\.local\bin\uv.exe"
    if (Test-Path $uvExe) {
        if ($DryRun) {
            Write-Warn "[DRY RUN] Would uninstall uv: $uvExe"
        } else {
            & $uvExe self uninstall 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-OK "uv uninstalled"
            } else {
                Write-Warn "uv self-uninstall failed. Remove manually: $uvExe"
            }
        }
    } else {
        Write-Info "uv not found at $uvExe"
    }
} else {
    Write-Host ""
    Write-Info "Step 8: Skipping uv removal (-KeepUv)"
}

# 完成
Write-Host ""
Write-Host "+---------------------------------------------------------+" -ForegroundColor Green
Write-Host "|           Hermes Agent Uninstall Complete               |" -ForegroundColor Green
Write-Host "+---------------------------------------------------------+" -ForegroundColor Green
Write-Host ""
Write-Info "You may need to restart your terminal for PATH changes to take effect."
Write-Host ""
