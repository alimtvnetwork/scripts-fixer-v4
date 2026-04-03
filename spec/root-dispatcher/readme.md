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
.\run.ps1 -I <number>              # Run a script
.\run.ps1 -I <number> -Merge       # Run with -Merge passed through
.\run.ps1 -I <number> -Clean       # Wipe .resolved/ cache, then run
.\run.ps1 -CleanOnly               # Wipe .resolved/ cache and exit
.\run.ps1 -Help                    # Show help (same as no params)
```

## Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `-I` | int | No | Script number to run (resolved via `scripts/registry.json`) |
| `-Merge` | switch | No | Passed through to child script (used by script 02 for deep-merge) |
| `-Clean` | switch | No | Wipes all `.resolved/` data before running, forcing fresh detection |
| `-CleanOnly` | switch | No | Wipes all `.resolved/` data and exits without running any script |
| `-Help` | switch | No | Show help (also shown when no params given) |

## Examples

```powershell
.\run.ps1                   # Pull, show help
.\run.ps1 -I 1              # Pull, then run scripts/01-*/run.ps1
.\run.ps1 -I 2 -Merge       # Pull, then run scripts/02-*/run.ps1 with merge mode
.\run.ps1 -I 4              # Pull, then run install-all-dev-tools (interactive menu)
.\run.ps1 -I 1 -Clean       # Wipe cache, pull, then run scripts/01-*/run.ps1
.\run.ps1 -CleanOnly         # Wipe all cached resolved data
```

## Execution Flow

1. If no parameters at all: git pull, show help, exit
2. If `-Help`: show help and exit
3. If `-CleanOnly`: wipe `.resolved/` contents and exit immediately
4. Validate `-I` is provided (show usage help if missing)
5. If `-Clean`: wipe `.resolved/` contents, then continue
6. Dot-source `scripts/shared/git-pull.ps1`
7. Resolve script folder from `-I` (e.g. `1` -> `scripts/01-*/`)
8. Verify `run.ps1` exists in the target folder
9. Clean and recreate the target script's `logs/` folder
10. `Invoke-GitPull` from the repo root
11. Set `$env:SCRIPTS_ROOT_RUN = "1"` so child scripts skip their own git pull
12. Delegate to the child script, passing through any extra flags (`-Merge`)
13. Clean up `$env:SCRIPTS_ROOT_RUN`

## Help Output

The help display shows:
- Project title and usage syntax
- All available scripts with ID, name, and description of what each folder does
- Script 04 specific options (interactive menu, -All, -Skip, -Only)
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
| No params = git pull + help | User discovers available scripts on first run |
| `-I` is optional (not `Mandatory`) | Allows `-CleanOnly` and default help to work without a script number |
| Usage help on missing `-I` | Better UX than a raw PowerShell parameter error |
| Clean before git pull | Ensures fresh detection even if git pull brings new config |
| Inline wipe (not via cleanup.ps1) | Root dispatcher runs before shared helpers are loaded; avoids dependency on logging |
| Flag passthrough via splatting | `$scriptArgs` hashtable makes it easy to add future flags |
