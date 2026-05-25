---
name: windows-print-debug
description: Debugging Windows print services where logs show success but no paper output. Covers unreliable return codes, Start-Process -Wait behavior, Session 0 issues, and verification strategies.
version: 1.3.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [Windows, Printing, Debugging, PowerShell, Service, Session-0, Python]
    related_skills: [systematic-debugging]
---

# Windows Print Service Debugging

Debug cases where Windows print commands return success but no paper actually prints.

## Key Findings

### 1. `Start-Process -Verb Print -Wait` is Misleading

The `-Wait` parameter only waits for the **launched application to exit**, not for the print job to complete:

```powershell
# This waits for Adobe Reader/Foxit to exit, NOT for paper to come out
Start-Process -FilePath "file.pdf" -Verb Print -Wait
```

If the associated app prints silently and exits immediately, `-Wait` returns right away with exit code 0 even if printing failed.

### 2. Print Return Codes are Unreliable

| Method | Exit Code 0 Means |
|--------|-------------------|
| `print /D:"printer" file.pdf` | Command executed, NOT that printing succeeded |
| `Start-Process -Verb Print` | Application launched, NOT that printing succeeded |
| Python `subprocess.run()` | Subprocess completed, NOT that printing succeeded |

**Core problem:** All these methods only verify the command ran, not that paper came out.

### 3. Cache Corruption Pattern

JSON cache files can get corrupted with boolean values instead of dictionaries:
```json
{
  "files": {
    "file.pdf": true,  // ← Corrupted entry
    "file2.pdf": { "hash": "...", "filename": "..." }  // ← Correct
  }
}
```

This happens when code saves `cache[key] = True` instead of `cache[key] = {...}`.

### 4. Session 0 (Windows Service) Incompatibility ⚠️

**Critical:** Windows services run in **Session 0** (non-interactive), which has fundamentally different behavior:

| Environment | `Start-Process -Verb Print` | Result |
|-------------|----------------------------|--------|
| Interactive session (user logged in) | Works | Paper comes out |
| Session 0 (Windows service) | Fails silently | No paper, exit code 0 |

**Root cause:** `-Verb Print` requires an interactive desktop. Session 0 has no desktop, so the print command "succeeds" but nothing prints.

**Symptoms:**
- Service logs show "Printed: filename.pdf" but no paper
- Manual test of same command works fine
- Print queue shows no jobs from service

## Fix Options

### Option A: Run service as user account (Recommended)

**WinSW configuration:**
```xml
<serviceaccount>
  <domain>.</domain>
  <user>yourusername</user>
  <password>yourpassword</password>
  <allowservicelogon>true</allowservicelogon>
</serviceaccount>
```

**Command line:**
```cmd
sc config ServiceName obj= .\yourusername password= yourpassword
```

### Option B: Use Session 0 compatible printing

- **SumatraPDF CLI** - Works from Session 0: `SumatraPDF.exe -print-to-default file.pdf`
- **.NET PrintDocument API** - Direct spooler access, Session 0 compatible
- **PDFtoPrinter** - Command-line tool designed for services

### Option C: Print queue verification

```powershell
# Before printing
$jobsBefore = (Get-PrintJob -PrinterName "Printer").Count
# Print
Start-Process -FilePath "file.pdf" -Verb Print
Start-Sleep -Seconds 5
# Verify job appeared in queue
$jobsAfter = (Get-PrintJob -PrinterName "Printer").Count
if ($jobsAfter -gt $jobsBefore) { Write-Host "Job queued" }
```

## Service Monitoring Logic Limitations

When debugging print services that monitor directories, be aware of common filtering logic:

### 1. File Modification Time Filtering
Many services only process files with modification time older than a threshold (e.g., 1 minute) to avoid processing files still being written:

**Implications:**
- Newly created test files won't be processed immediately
- Wait at least 1-2 minutes after creating test files
- Check file modification time: `stat -c %y filename` (Linux) or `Get-Item filename | Select-Object LastWriteTime` (PowerShell)

### 2. Hash-Based Duplicate Detection
Services often use file hash caching to prevent re-printing:

**Debugging steps:**
1. Check cache file: `data/print_cache.json`
2. Look for corrupted boolean entries: `true` instead of `{hash: "...", filename: "..."}`
3. Clear cache or use unique test file names

## WSL-to-Windows Debugging

When debugging Windows services from WSL:

### Path Conversion
PowerShell commands need Windows-format paths:

```bash
# Convert WSL path to Windows path
WSL_PATH="/mnt/c/Users/kangle/PrintHotFolder/TempPrint/test.pdf"
WIN_PATH=$(wslpath -w "$WSL_PATH")
echo "Windows path: $WIN_PATH"  # C:\Users\kangle\PrintHotFolder\TempPrint\test.pdf
```

### Service Status Checking
```bash
# Check Windows service status from WSL
powershell.exe -Command "Get-Service -Name ServiceName | Select-Object Name, Status, StartType"

# Check service logs
tail -50 /mnt/c/Users/Username/Project/logs/service/ServiceName-Service.out.log
```

## Debugging Workflow

### Step 1: Verify Basic Print Functionality
1. Test print command manually from interactive session
2. Ask user: "是否成功出纸？" (Did paper actually come out?)
3. Only proceed if manual printing works

### Step 2: Check Service Configuration
1. Verify service account (not Local System for printing)
2. Check service status: `Get-Service -Name ServiceName`
3. Review service logs for errors

### Step 3: Test Service Monitoring
1. Create test file with unique name
2. Wait at least 1-2 minutes (for modification time filtering)
3. Check service logs for processing
4. Verify file hash not in cache

## Modifying Printer Configuration

When changing printer configuration for a Windows print service:

### 1. Check Multiple Locations
Printer names may be hardcoded in multiple places:
- Config files (e.g., `EmailMonitorConfig.json`)
- PowerShell scripts (e.g., `PrintHotFolder.ps1`)
- Python scripts (e.g., `print_helper_improved.py`)
- Backup/template config files

### 2. Search for Hardcoded Printer Names
```bash
# Search all script files for printer references
grep -r "PrinterName\|printer_name\|HP LaserJet\|DocuCentre" --include="*.ps1" --include="*.py" --include="*.json" src/ config/
```

### 3. Restart Service After Changes
Windows services cache configuration at startup. Always restart after config changes:
```powershell
Stop-Service -Name ServiceName -Force
Start-Service -Name ServiceName
```

### 4. Verify Configuration Loaded
Check service logs for printer configuration messages after restart.

## Verification Strategy

Since return codes are unreliable, you must verify actual printing:

### Check Print Queue (Recommended)
```powershell
# Get print jobs before
$jobsBefore = Get-PrintJob -PrinterName "PrinterName"
# Print the file
Start-Process -FilePath "file.pdf" -Verb Print
Start-Sleep -Seconds 5
# Check if new job appeared
$jobsAfter = Get-PrintJob -PrinterName "PrinterName"
if ($jobsAfter.Count -gt $jobsBefore.Count) {
    Write-Host "Print job submitted to queue"
}
```

### User Verification
For critical printing, ask user to confirm paper output. Don't mark as "printed" until confirmed.

## Debugging Checklist

When "printed but no paper":

1. **Check logs vs reality** - Logs may show success without actual printing
2. **Inspect cache files** - Look for boolean `true/false` entries mixed with dicts
3. **Test manually** - Run the exact print command the service uses
4. **Check print queue** - `Get-PrintJob` shows what's actually queued
5. **Check printer default** - Service may print to wrong printer
6. **Check file association** - PDF handler may show dialog instead of printing silently
7. **Service permissions** - Windows services run as SYSTEM in Session 0
8. **Test SumatraPDF** - Install and test if it works from service context
9. **Check for hardcoded printer names** - Search .ps1 files: `grep -r "PrinterName\|printer_name" --include="*.ps1" src/`

## Cache Cleanup Utility

When JSON cache gets corrupted with boolean entries:
```powershell
# Clean boolean entries from cache JSON
$content = Get-Content "cache.json" -Raw
$content = $content -replace '"[^"]*":\s*true,?\s*', ''
$content = $content -replace ',\s*}', '}'
$content = $content -replace ',\s*]', ']'
$content | Set-Content "cache.json" -Encoding UTF8
```

## Common Pitfalls

- Trusting return codes without verification
- Using `-Wait` with `-Verb Print` and expecting it to wait for print completion
- Marking files as "printed" immediately after command returns
- Not checking print queue status
- Assuming service has same permissions as logged-in user
- **Running Windows services as Local System when printer access is needed**
- Not testing print methods in actual service context (Session 0)
- Forgetting to install SumatraPDF for Session 0 compatible printing
- **Not waiting for file modification time threshold when testing services**
- **Using WSL paths in PowerShell commands without conversion**
- **Not checking service logs for SKIP/filtering messages**
- **Not checking for hardcoded printer names in PowerShell scripts** - Config files may be updated but scripts still use old printer names. Search all .ps1 files for hardcoded printer names: `grep -r "PrinterName\|printer_name" --include="*.ps1"`