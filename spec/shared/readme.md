# Spec: Shared Helpers

## Overview

Shared PowerShell modules that live in `scripts/shared/` and are dot-sourced
by individual scripts. This avoids duplicating common logic across scripts.

---

## File Structure

```
scripts/
└── shared/
    ├── git-pull.ps1      # Provides Invoke-GitPull function
    ├── logging.ps1       # Provides Write-Log, Write-Banner, Initialize-Logging, Import-JsonConfig
    ├── json-utils.ps1    # Provides Backup-File, Merge-JsonDeep, ConvertTo-OrderedHashtable
    ├── resolved.ps1      # Provides Save-ResolvedData, Get-ResolvedDir
    ├── cleanup.ps1       # Provides Clear-ResolvedData
    ├── help.ps1          # Provides Show-ScriptHelp
    ├── path-utils.ps1    # Provides Add-ToUserPath, Add-ToMachinePath, Test-InPath
    ├── choco-utils.ps1   # Provides Assert-Choco, Install-ChocoPackage, Upgrade-ChocoPackage
    └── dev-dir.ps1       # Provides Resolve-DevDir, Initialize-DevDir

.resolved/                # Runtime-resolved data (gitignored, never committed)
├── 01-vscode-context-menu-fix/
│   └── resolved.json     # Discovered exe paths, timestamps
└── 02-vscode-settings-sync/
    └── resolved.json     # Resolved settings dirs, CLI commands
```

---

## git-pull.ps1

### Purpose

Provides `Invoke-GitPull` -- a function that runs `git pull` from the repo root.

### Skip Mechanism

| Scenario | Behavior |
|----------|----------|
| Script run directly (`.\scripts\01-...\run.ps1`) | `$env:SCRIPTS_ROOT_RUN` is not set -> git pull runs |
| Script run via root dispatcher (`.\run.ps1 -I 1`) | Root sets `$env:SCRIPTS_ROOT_RUN = "1"` before delegating -> git pull is skipped |

### Function Signature

```powershell
Invoke-GitPull -RepoRoot <string>
```

### How Child Scripts Use It

```powershell
# At the top of Main, before Initialize-Logging:
$sharedGitPull = Join-Path $ScriptDir "..\shared\git-pull.ps1"
if (Test-Path $sharedGitPull) {
    . $sharedGitPull
    $repoRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)
    Invoke-GitPull -RepoRoot $repoRoot
}
```

---

## logging.ps1

### Functions

| Function | Purpose |
|----------|---------|
| `Write-Log` | Prints a status-badged message (`[  OK  ]`, `[ FAIL ]`, etc.) |
| `Write-Banner` | Displays ASCII banner blocks in a specified color |
| `Initialize-Logging` | Cleans and recreates `logs/`, starts transcript |
| `Import-JsonConfig` | Loads and returns a JSON file with verbose logging |

---

## json-utils.ps1

### Purpose

Provides common JSON and file utilities extracted from script 02 so all scripts can reuse them.

### Functions

| Function | Purpose |
|----------|---------|
| `Backup-File` | Creates a timestamped backup copy of an existing file before overwriting |
| `ConvertTo-OrderedHashtable` | Converts a `PSCustomObject` (from `ConvertFrom-Json`) to an ordered hashtable for deep merging |
| `Merge-JsonDeep` | Recursively deep-merges two hashtables; incoming keys overwrite, existing-only keys are preserved |

### How Child Scripts Use It

```powershell
$sharedJsonUtils = Join-Path $PSScriptRoot "..\shared\json-utils.ps1"
if (Test-Path $sharedJsonUtils) { . $sharedJsonUtils }
```

---

## resolved.ps1

### Purpose

Provides a shared mechanism for persisting **runtime-discovered state** to the
`.resolved/` folder at the repo root. This keeps `config.json` files **purely
declarative** -- they are never mutated by scripts.

### Design Principle

**Config files are input. Resolved data is output.**

- `config.json` contains user-editable, declarative settings (paths with env vars, labels, edition preferences)
- `.resolved/` contains runtime state discovered by the script (expanded paths, timestamps, usernames)
- Config is committed to git. Resolved data is gitignored.

### Functions

| Function | Signature | Purpose |
|----------|-----------|---------|
| `Get-ResolvedDir` | `-ScriptDir <string>` | Returns `.resolved/<script-folder>/` path, creating the directory if needed |
| `Save-ResolvedData` | `-ScriptDir <string> -Data <hashtable>` | Merges new keys into `resolved.json`, preserving existing data |

### Folder Layout

```
<repo-root>/
└── .resolved/                              # gitignored
    ├── 01-vscode-context-menu-fix/
    │   └── resolved.json                   # { "stable": { "resolvedExe": "...", "resolvedAt": "...", "resolvedBy": "..." } }
    └── 02-vscode-settings-sync/
        └── resolved.json                   # { "stable": { "settingsDir": "...", "cliCommand": "...", "resolvedAt": "..." } }
```

### How It Works

1. Script calls `Save-ResolvedData -ScriptDir $ScriptDir -Data @{ ... }`
2. Helper computes `<repo-root>/.resolved/<script-folder-name>/`
3. If `resolved.json` already exists, it reads and merges (new keys overlay, old keys preserved)
4. Writes merged result back as JSON

### Cache-First Pattern (Script 01)

Script 01 checks `.resolved/` **before** running path detection:

```powershell
# Inside Resolve-VsCodePath:
$resolvedDir  = Get-ResolvedDir -ScriptDir $ScriptDir
$resolvedFile = Join-Path $resolvedDir "resolved.json"
if (Test-Path $resolvedFile) {
    $cached = Get-Content $resolvedFile -Raw | ConvertFrom-Json
    $cachedExe = $cached.$EditionName.resolvedExe
    if ($cachedExe -and (Test-Path $cachedExe)) {
        # Use cached path, skip detection
        return $cachedExe
    }
    # Cached path stale -- fall through to full detection
}
```

If the cached exe still exists on disk, detection is skipped entirely. If stale (uninstalled/moved), normal detection runs and the cache is updated.

### How Child Scripts Use It

```powershell
$sharedResolved = Join-Path $ScriptDir "..\shared\resolved.ps1"
if (Test-Path $sharedResolved) { . $sharedResolved }

# After resolving a path:
Save-ResolvedData -ScriptDir $ScriptDir -Data @{
    $EditionName = @{
        resolvedExe = $VsCodeExe
        resolvedAt  = (Get-Date -Format "o")
        resolvedBy  = $env:USERNAME
    }
}
```

## cleanup.ps1

### Purpose

Provides `Clear-ResolvedData` to wipe cached runtime state for a fresh start.

### Function Signature

```powershell
Clear-ResolvedData -ScriptDir <string> [-EditionName <string>]
```

### Modes

| Call | Effect |
|------|--------|
| `Clear-ResolvedData -ScriptDir $ScriptDir` | Removes **all** contents of `.resolved/` |
| `Clear-ResolvedData -ScriptDir $ScriptDir -EditionName "stable"` | Removes only the `"stable"` key from that script's `resolved.json` |

### How to Use

```powershell
$sharedCleanup = Join-Path $ScriptDir "..\shared\cleanup.ps1"
if (Test-Path $sharedCleanup) { . $sharedCleanup }

# Wipe everything:
Clear-ResolvedData -ScriptDir $ScriptDir

# Or just one edition:
Clear-ResolvedData -ScriptDir $ScriptDir -EditionName "insiders"
```

---

## Naming Conventions

| Rule | Example |
|------|---------|
| All file names use **lowercase-hyphenated** (kebab-case) | `git-pull.ps1` |
| Folder names also use lowercase-hyphenated | `shared` |
| PowerShell functions use Verb-Noun PascalCase per PS convention | `Invoke-GitPull` |

## Design Decisions

| Decision | Rationale |
|----------|-----------|
| Environment variable flag | Simple, no file I/O, works across process boundaries |
| Dot-sourcing (not module) | No module manifest overhead, just a simple function import |
| Graceful fallback | If shared helper is missing, scripts warn and continue |
| Root cleans flag after run | Prevents stale flag from affecting future standalone runs |
| Config is read-only at runtime | Scripts never mutate their own config.json -- keeps it declarative and git-friendly |
| .resolved/ is gitignored | Runtime state (discovered paths, timestamps) belongs outside version control |
| Merge semantics in Save-ResolvedData | Multiple editions can write to the same resolved.json without overwriting each other |
| Granular cleanup | Clear-ResolvedData supports per-edition clearing, not just full wipe |
| Cache-first detection | Avoids redundant filesystem probing on repeated runs |
