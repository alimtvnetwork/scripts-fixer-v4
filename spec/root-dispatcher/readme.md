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
.\run.ps1                          # Git pull + show help
.\run.ps1 -d                       # Shortcut for -I 12 (interactive dev tools menu)
.\run.ps1 -I <number>              # Run a script
.\run.ps1 -I <number> -Merge       # Run with -Merge passed through
.\run.ps1 -I <number> -Clean       # Wipe .resolved/ cache, then run
.\run.ps1 -CleanOnly               # Wipe .resolved/ cache and exit
.\run.ps1 -Help                    # Show help (same as no params)
```

## Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `-d` | switch | No | Shortcut for `-I 12` -- launches the interactive dev tools menu |
| `-a` | switch | No | Shortcut for `-I 13` -- runs the audit scanner |
| `-v` | switch | No | Shortcut for `-I 1` -- installs VS Code |
| `-I` | int | No | Script number to run (resolved via `scripts/registry.json`) |
| `-Merge` | switch | No | Passed through to child script (used by script 02 for deep-merge) |
| `-Clean` | switch | No | Wipes all `.resolved/` data before running, forcing fresh detection |
| `-CleanOnly` | switch | No | Wipes all `.resolved/` data and exits without running any script |
| `-Help` | switch | No | Show help (also shown when no params given) |

## Examples

```powershell
.\run.ps1                   # Pull, show help
.\run.ps1 -d                # Pull, then run interactive dev tools menu (script 12)
.\run.ps1 -I 1              # Pull, then run scripts/01-install-vscode/run.ps1
.\run.ps1 -I 2 -Merge       # Pull, then run scripts/02-install-package-managers/run.ps1 with merge mode
.\run.ps1 -I 12             # Same as -d (interactive menu)
.\run.ps1 -I 1 -Clean       # Wipe cache, pull, then run scripts/01-install-vscode/run.ps1
.\run.ps1 -CleanOnly         # Wipe all cached resolved data
```

## Execution Flow

1. If no parameters at all: clear stale `$env:SCRIPTS_ROOT_RUN`, git pull, show help, exit
2. If `-Help`: show help and exit
3. If `-CleanOnly`: wipe `.resolved/` contents and exit immediately
4. If `-d`: set `$I = 12` (shortcut expansion)
5. Validate `-I` is provided (show usage help if missing)
5. If `-Clean`: wipe `.resolved/` contents, then continue
6. Dot-source `scripts/shared/git-pull.ps1`
7. Resolve script folder from `-I` via registry lookup (see below)
8. Verify `run.ps1` exists in the resolved folder
9. Clean and recreate the target script's `logs/` folder
10. `Invoke-GitPull` from the repo root
11. Set `$env:SCRIPTS_ROOT_RUN = "1"` so child scripts skip their own git pull
12. Delegate to the child script, passing through any extra flags (`-Merge`)
13. Clean up `$env:SCRIPTS_ROOT_RUN`

## Script Resolution

The dispatcher resolves `-I <number>` to a script folder using a two-tier strategy:

### Primary: Registry lookup (`scripts/registry.json`)

A flat JSON file maps zero-padded IDs to exact folder names:

```json
{
  "scripts": {
    "01": "01-install-vscode",
    "04": "04-install-pnpm",
    "11": "11-install-all-dev-tools"
  }
}
```

The dispatcher reads the registry, looks up the formatted prefix (e.g. `04`),
and joins `scripts/<folder>` to get the exact path. This avoids glob ambiguity
when stale or renamed folders share the same prefix.

### Fallback: Glob matching

If `registry.json` is missing, the dispatcher falls back to globbing
`scripts/<NN>-*` and filtering to directories that contain a `run.ps1`.
Only the first match is used.

### Resolution errors

| Condition | Behaviour |
|-----------|-----------|
| Registry entry exists but folder is missing on disk | `[ FAIL ]` with "No script folder found for ID NN" |
| Registry missing + no glob match | `[ FAIL ]` with "No script folder found for ID NN" |
| Folder found but no `run.ps1` inside | `[ FAIL ]` with "run.ps1 not found in <folder>" |

## Help Output

The help display shows:
- Project title and usage syntax
- All available scripts with ID, name, and description (grouped: Core Tools, Optional, Orchestrator)
- Script 11 specific options (interactive menu, -All, -Skip, -Only)
- How to get per-script help

## Environment Variables

| Variable | Set by | Purpose |
|----------|--------|---------|
| `$env:SCRIPTS_ROOT_RUN` | Root dispatcher | Set to `"1"` before delegating; child scripts check this to skip redundant git pull |

The flag is removed after the child script completes, preventing stale state
in future standalone runs.

## .resolved/ Cache Management

The `-Clean` and `-CleanOnly` flags provide direct control over the `.resolved/`
runtime cache without needing to manually delete folders.

| Flag | Requires -I | Effect |
|------|-------------|--------|
| `-Clean` | Yes | Wipe cache, then run script (forces fresh detection) |
| `-CleanOnly` | No | Wipe cache and exit |
| Neither | Yes | Run script using existing cache (cache-first detection) |

## Design Decisions

| Decision | Rationale |
|----------|-----------|
| Registry-based resolution | Exact folder names avoid glob collisions with stale/renamed folders |
| Glob fallback | Backwards-compatible for repos that haven't added `registry.json` yet |
| No params = git pull + help | User discovers available scripts on first run |
| Clear `$env:SCRIPTS_ROOT_RUN` on no-param run | Prevents stale env var from a previous session causing git pull to skip |
| `-I` is optional (not `Mandatory`) | Allows `-CleanOnly` and default help to work without a script number |
| Usage help on missing `-I` | Better UX than a raw PowerShell parameter error |
| Clean before git pull | Ensures fresh detection even if git pull brings new config |
| Inline wipe (not via cleanup.ps1) | Root dispatcher runs before shared helpers are loaded; avoids dependency on logging |
| Flag passthrough via splatting | `$scriptArgs` hashtable makes it easy to add future flags |
