# Issues Log -- VS Code Context Menu Fix

## Issue 1: Registry writes fail with `-LiteralPath` error

**Error:**
```
[ FAIL ] FAILED: A parameter cannot be found that matches parameter name 'LiteralPath'.
```

**Root cause:**
The script used PowerShell's `New-Item -LiteralPath` to create registry keys under `HKCR:\*\shell\VSCode`. On Windows PowerShell 5.1, `New-Item` for the Registry provider does **not** support `-LiteralPath` -- only `-Path`. However, `-Path` treats `*` as a wildcard, so the key `HKCR:\*\shell\VSCode` would fail or match unintended locations.

This is a known limitation of Windows PowerShell 5.1's Registry provider. PowerShell 7+ supports `-LiteralPath` on `New-Item`, but the script must support 5.1 since that ships with Windows.

**Fix:**
Replaced all PowerShell registry cmdlets (`New-Item`, `Set-ItemProperty`) with native `reg.exe` calls. `reg.exe` has no wildcard interpretation issues and works identically on all Windows versions:

```powershell
# Before (broken on PS 5.1)
New-Item -LiteralPath $RegistryPath -Force
Set-ItemProperty -LiteralPath $RegistryPath -Name "(Default)" -Value $Label

# After (works everywhere)
reg.exe add "HKCR\*\shell\VSCode" /ve /d "Open with Code" /f
reg.exe add "HKCR\*\shell\VSCode" /v "Icon" /d "C:\...\Code.exe" /f
reg.exe add "HKCR\*\shell\VSCode\command" /ve /d "C:\...\Code.exe \"%1\"" /f
```

A helper `ConvertTo-RegPath` translates the `Registry::HKEY_CLASSES_ROOT\...` paths from config into the short `HKCR\...` format that `reg.exe` expects.

**How to write better code:**
- Always test against Windows PowerShell 5.1 when targeting Windows desktops -- it is still the default shell.
- Prefer `reg.exe` for HKCR writes. It is simpler, has no wildcard quirks, and produces clearer error messages.
- Document the minimum PowerShell version in the script header so future contributors know the constraint.

---

## Issue 2: Detected VS Code path not persisted to config.json

**Symptom:**
The script detected VS Code at `C:\Program Files\Microsoft VS Code\Code.exe` (system install) after the preferred user-install path was not found, but this resolved path was never saved. On every run the detection logic repeated from scratch.

**Root cause:**
The `Invoke-Edition` function resolved the executable path but never wrote it back to `config.json`. There was no persistence mechanism at all -- the resolved path lived only in memory for the current run.

**Fix:**
Added a `Save-ResolvedPath` function that writes a `"resolved"` key into the edition's `vscodePath` object in `config.json`:

```json
"vscodePath": {
  "user": "%LOCALAPPDATA%\\Programs\\Microsoft VS Code\\Code.exe",
  "system": "C:\\Program Files\\Microsoft VS Code\\Code.exe",
  "resolved": "C:\\Program Files\\Microsoft VS Code\\Code.exe"
}
```

On subsequent runs the script can check `resolved` first, skipping the detection fallback entirely.

**How to write better code:**
- When a script performs expensive or environment-dependent detection, always cache the result. A config file is the natural place.
- Use `Add-Member -Force` to upsert JSON properties without breaking existing keys.
- Use `[System.IO.File]::WriteAllText()` instead of `Set-Content` to avoid BOM and encoding surprises on different PS versions.
