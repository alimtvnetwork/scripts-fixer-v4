# Spec: Root Dispatcher (run.ps1)

## Overview

The root-level `run.ps1` is the single entry point for running any numbered
script in the project. It handles git pull, log cleanup, environment flags,
and cache management before delegating to the target script.

When run with no parameters, it performs a git pull and shows help
(available scripts and usage).

---

## Usage

```powershell
.\run.ps1                              # Git pull + show help
.\run.ps1 -Install vscode             # Install VS Code by keyword
.\run.ps1 -Install nodejs,pnpm        # Install Node.js + pnpm (combo)
.\run.ps1 -Install python             # Install Python + pip
.\run.ps1 -Install go,git,cpp         # Install Go, Git, and C++
.\run.ps1 -Install all-dev            # Interactive dev tools menu
.\run.ps1 -d                          # Shortcut for -I 12 (interactive menu)
.\run.ps1 -I <number>                 # Run a script by ID
.\run.ps1 -I <number> -Merge          # Run with -Merge passed through
.\run.ps1 -I <number> -Clean          # Wipe .resolved/ cache, then run
.\run.ps1 -CleanOnly                  # Wipe .resolved/ cache and exit
.\run.ps1 -Help                       # Show help (same as no params)
```

## Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `-Install` | string | No | Comma-separated keywords to install (e.g. `vscode`, `nodejs,pnpm`, `go,git`) |
| `-d` | switch | No | Shortcut for `-I 12` -- launches the interactive dev tools menu |
| `-a` | switch | No | Shortcut for `-I 13` -- runs the audit scanner |
| `-v` | switch | No | Shortcut for `-I 1` -- installs VS Code |
| `-w` | switch | No | Shortcut for `-I 14` -- installs Winget |
| `-t` | switch | No | Shortcut for `-I 15` -- launches Windows tweaks utility |
| `-I` | int | No | Script number to run (resolved via `scripts/registry.json`) |
| `-Merge` | switch | No | Passed through to child script (used by script 02 for deep-merge) |
| `-Clean` | switch | No | Wipes all `.resolved/` data before running, forcing fresh detection |
| `-CleanOnly` | switch | No | Wipes all `.resolved/` data and exits without running any script |
| `-Help` | switch | No | Show help (also shown when no params given) |

## Keyword Install System

The `-Install` parameter accepts human-friendly keywords that map to script IDs via
`scripts/shared/install-keywords.json`. Keywords are case-insensitive and comma-separated.

### Keyword Mapping

| Keyword | Maps to | Script ID(s) |
|---------|---------|-------------|
| `vscode`, `vs-code`, `code` | VS Code | 01 |
| `choco`, `chocolatey` | Chocolatey | 02 |
| `nodejs`, `node`, `node.js` | Node.js + Yarn + Bun | 03 |
| `pnpm` | Node.js + pnpm | 03, 04 |
| `python`, `pip` | Python + pip | 05 |
| `go`, `golang` | Go | 06 |
| `git`, `gh`, `github-cli` | Git + LFS + GitHub CLI | 07 |
| `github-desktop` | GitHub Desktop | 08 |
| `cpp`, `c++`, `gcc`, `mingw` | C++ (MinGW-w64) | 09 |
| `context-menu` | VSCode context menu fix | 10 |
| `settings-sync` | VSCode settings sync | 11 |
| `all-dev`, `all` | Interactive dev tools menu | 12 |
| `audit` | Audit mode | 13 |
| `winget` | Winget | 14 |
| `tweaks`, `windows-tweaks` | Windows tweaks | 15 |
| `php` | PHP | 16 |
| `powershell`, `pwsh` | PowerShell (latest) | 17 |

### Combo Examples

```powershell
.\run.ps1 -Install nodejs,pnpm           # Installs scripts 03, 04 in order
.\run.ps1 -Install go,git,cpp            # Installs scripts 06, 07, 09 in order
.\run.ps1 -Install python,php            # Installs scripts 05, 16 in order
.\run.ps1 -Install vscode,nodejs,git     # Installs scripts 01, 03, 07 in order
```

Duplicate IDs are automatically de-duplicated and sorted by ID for logical execution order.

## Examples

```powershell
.\run.ps1                   # Pull, show help
.\run.ps1 -Install vscode   # Pull, then install VS Code
.\run.ps1 -d                # Pull, then run interactive dev tools menu (script 12)
.\run.ps1 -I 1              # Pull, then run scripts/01-install-vscode/run.ps1
.\run.ps1 -I 2 -Merge       # Pull, then run scripts/02-install-package-managers/run.ps1 with merge
.\run.ps1 -I 12             # Same as -d (interactive menu)
.\run.ps1 -I 1 -Clean       # Wipe cache, pull, then run scripts/01-install-vscode/run.ps1
.\run.ps1 -CleanOnly         # Wipe all cached resolved data
```

## Execution Flow

### Standard mode (-I)
1. If no parameters at all: clear stale `$env:SCRIPTS_ROOT_RUN`, git pull, show help, exit
2. If `-Help`: show help and exit
3. If `-CleanOnly`: wipe `.resolved/` contents and exit immediately
4. If `-Clean`: wipe `.resolved/` contents, then continue
5. Dot-source `scripts/shared/git-pull.ps1`
6. Run `Invoke-GitPull` from repo root
7. Set `$env:SCRIPTS_ROOT_RUN = "1"`
8. Expand shortcuts (`-d` -> 12, `-v` -> 1, etc.)
9. Resolve script via `Invoke-ScriptById` (registry lookup + logs cleanup)
10. Delegate to the child script
11. Clean up `$env:SCRIPTS_ROOT_RUN`

### Keyword mode (-Install)
1. Steps 1-7 same as above
2. Parse comma-separated keywords via `Resolve-InstallKeywords`
3. Look up each keyword in `scripts/shared/install-keywords.json`
4. De-duplicate and sort script IDs
5. Run each script in sequence via `Invoke-ScriptById`
6. Show summary (success/fail counts)
7. Clean up `$env:SCRIPTS_ROOT_RUN`

## Script Resolution

The dispatcher resolves script IDs to folders using `Invoke-ScriptById`:

### Primary: Registry lookup (`scripts/registry.json`)

A flat JSON file maps zero-padded IDs to exact folder names:

```json
{
  "scripts": {
    "01": "01-install-vscode",
    "04": "04-install-pnpm"
  }
}
```

### Fallback: Glob matching

If `registry.json` is missing, the dispatcher falls back to globbing
`scripts/<NN>-*` and filtering to directories that contain a `run.ps1`.

### Resolution errors

| Condition | Behaviour |
|-----------|-----------|
| Registry entry exists but folder is missing on disk | `[ FAIL ]` with "No script folder found for ID NN" |
| Registry missing + no glob match | `[ FAIL ]` with "No script folder found for ID NN" |
| Folder found but no `run.ps1` inside | `[ FAIL ]` with "run.ps1 not found in <folder>" |

## Git Pull Output

The `Format-GitPullOutput` function in `scripts/shared/git-pull.ps1` parses raw
`git pull` output and formats it with clean, aligned, color-coded lines:

| Line type | Badge | Color |
|-----------|-------|-------|
| From / branch tracking | `[  OK  ]` | Green |
| Updating / Fast-forward | `[ INFO ]` / `[  OK  ]` | Cyan / Green |
| File changes | `[  --  ]` | White filename, yellow count, green `+`, red `-` |
| Create mode | `[  --  ]` | Green |
| Delete mode | `[  --  ]` | Red |
| Summary line | `[  OK  ]` | Green |

## Environment Variables

| Variable | Set by | Purpose |
|----------|--------|---------|
| `$env:SCRIPTS_ROOT_RUN` | Root dispatcher | Set to `"1"` before delegating; child scripts check this to skip redundant git pull |

## .resolved/ Cache Management

| Flag | Requires -I | Effect |
|------|-------------|--------|
| `-Clean` | Yes | Wipe cache, then run script (forces fresh detection) |
| `-CleanOnly` | No | Wipe cache and exit |
| Neither | Yes | Run script using existing cache |

## Design Decisions

| Decision | Rationale |
|----------|-----------|
| Keyword install system | Human-friendly names avoid needing to memorize script IDs |
| External keyword JSON | Easy to add new keywords without editing run.ps1 |
| Auto-chaining (e.g. pnpm -> 03,04) | Dependencies are resolved automatically |
| De-duplication + sorting | Prevents running the same script twice; ensures logical order |
| Registry-based resolution | Exact folder names avoid glob collisions |
| Glob fallback | Backwards-compatible for repos without `registry.json` |
| No params = git pull + help | User discovers available scripts on first run |
| Refactored into `Invoke-ScriptById` | Shared by both `-I` and `-Install` modes, reduces duplication |
| Formatted git pull output | Clean, colored, line-by-line display instead of raw dump |
