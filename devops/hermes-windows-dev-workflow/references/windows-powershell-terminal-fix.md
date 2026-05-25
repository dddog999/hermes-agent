# Windows PowerShell Terminal Fix for Hermes Agent

## Session Context (2026-05-08)
Fixed `tools/environments/local.py` to correctly use powershell.exe on Windows, resolving exit code 1 errors for all terminal commands.

## Problem
Windows Hermes terminal tool returned exit code 1 for all commands (e.g., `echo hello`) despite producing correct output. Error message: "terminal appears to be returning exit code 1 for all commands without output or error messages".

## Root Cause
1. `_find_bash()` correctly returned `powershell.exe` on Windows.
2. `_run_bash()` used bash-style arguments: `[bash, "-c", cmd_string]` → `powershell.exe -c "echo hello"` which is invalid (powershell uses `-Command`, not `-c`).
3. No exit code propagation: powershell's `$LASTEXITCODE` was not captured, leading to incorrect exit code 1.

## Fix Steps
### 1. Modify `_run_bash()` in `tools/environments/local.py`
```python
# Use -Command for powershell.exe, -c for bash
is_powershell = "powershell" in bash.lower()
if is_powershell:
    # Append exit code handling to ensure proper exit code propagation
    cmd_with_exit = cmd_string + "; exit $LASTEXITCODE"
    ps_args = ["-NoProfile", "-NonInteractive", "-Command", cmd_with_exit]
    args = [bash] + ps_args
else:
    args = [bash, "-l", "-c", cmd_string] if login else [bash, "-c", cmd_string]
```

### 2. Sync modified files
```bash
# Sync to Windows hermes-windows directory
cp /mnt/c/Users/dddog/hermes-windows/tools/environments/local.py /home/dddog/hermes-windows-wsl/tools/environments/local.py
```

## Testing
In Windows PowerShell:
```powershell
cd C:\Users\dddog\hermes-windows
.\start.ps1
```
Enter Hermes and run:
```
terminal echo hello
```
Expected: Output `hello` with exit code 0 (no warning about exit code 1).

## Related Corrections (User-Provided)
- **WSL-Windows local execution**: Do NOT use SSH to connect to local Windows host. WSL can directly invoke Windows executables:
  ```bash
  powershell.exe -Command "echo hello"
  cmd.exe /c "dir"
  ```
- **Model switching syntax**: Correct is `/model <model-name> --provider <provider-key>`. INVALID: `/model provider:model` (colon syntax is not supported).
