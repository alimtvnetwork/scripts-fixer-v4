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
The `Invoke-Edition` function resolved the executable path but never wrote it back anywhere. There was no persistence mechanism -- the resolved path lived only in memory for the current run.

**Original fix (v3.0):**
Added a `Save-ResolvedPath` function that wrote a `"resolved"` key back into `config.json`. This worked but violated separation of concerns -- the script was mutating its own declarative config with runtime state.

**Improved fix (v3.1):**
Moved runtime-resolved data out of `config.json` entirely into a repo-root `.resolved/` folder (gitignored). Each script writes to `.resolved/<script-folder>/resolved.json`:

```json
// .resolved/01-vscode-context-menu-fix/resolved.json
{
  "stable": {
    "resolvedExe": "C:\\Program Files\\Microsoft VS Code\\Code.exe",
    "resolvedAt": "2026-04-03T18:10:02+08:00",
    "resolvedBy": "alim"
  }
}
```

A shared helper `scripts/shared/resolved.ps1` provides `Save-ResolvedData` and `Get-ResolvedDir`, merging new keys into existing resolved data.

**How to write better code:**
- Never mutate source config files with runtime-discovered state. Keep config declarative and gitignored runtime state separate.
- Use a dedicated `.resolved/` (or `.cache/`, `.state/`) folder for any data the script discovers at runtime.
- Shared helpers reduce duplication -- `Save-ResolvedData` is used by both script 01 and 02.
