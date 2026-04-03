# Spec: VS Code Profile Importer

## Overview

A PowerShell utility that imports a full VS Code profile — **settings.json**,
**keybindings.json**, and **extensions** — for both **Stable** and **Insiders** editions.

---

## Problem

Setting up VS Code on a new machine or after a reinstall requires:

1. Manually copying `settings.json` and `keybindings.json`
2. Individually installing each extension
3. Exporting/importing profiles through VS Code's UI

This is tedious and error-prone, especially when maintaining the same config
across multiple machines.

## Solution

A structured PowerShell script that:

- Accepts a `.code-profile` export file **or** individual JSON files
- Parses the profile to extract settings, keybindings, and extension list
- Backs up existing files before overwriting
- Copies `settings.json` and `keybindings.json` into the correct VS Code user settings path
- Installs all enabled extensions via CLI (`code --install-extension`)
- Supports both **VS Code Stable** and **VS Code Insiders**
- Provides colorful, structured terminal output with status badges

---

## File Structure

```
scripts/
└── 02-vscode-settings-sync/
    ├── config.json                    # Paths & edition settings
    ├── log-messages.json              # All display strings & banners
    ├── settings.json                  # Extracted/provided VS Code settings
    ├── keybindings.json               # Extracted/provided keybindings
    ├── extensions.json                # Extension IDs (enabled & disabled)
    ├── *.code-profile                 # (Optional) VS Code profile export
    ├── run.ps1                        # Main script
    └── logs/                          # Auto-created runtime log folder (gitignored)
        └── run-<timestamp>.log        # Timestamped execution log

spec/
└── 02-vscode-settings-sync/
    └── readme.md                      # This specification
```

## Input Priority

The script uses this priority for source data:

1. **`.code-profile` file** — If present in the script folder, the profile is
   parsed automatically to extract settings, keybindings, and extensions.
2. **Individual JSON files** — Falls back to `settings.json`, `keybindings.json`,
   and `extensions.json` if no profile file is found (or parsing fails).

## config.json Schema

| Key                                  | Type     | Description                                         |
|--------------------------------------|----------|-----------------------------------------------------|
| `editions.stable.settingsPath`       | string   | Path to Stable VS Code user settings dir            |
| `editions.stable.cliCommand`         | string   | CLI command for Stable (`code`)                     |
| `editions.insiders.settingsPath`     | string   | Path to Insiders VS Code user settings dir          |
| `editions.insiders.cliCommand`       | string   | CLI command for Insiders (`code-insiders`)          |
| `enabledEditions`                    | string[] | Which editions to target (`["stable","insiders"]`)  |
| `backupSuffix`                       | string   | Suffix for backup files (e.g. `.backup`)            |

## extensions.json Schema

```json
{
  "extensions": ["id1", "id2"],
  "disabled": ["id3", "id4"]
}
```

Only `extensions` (enabled) are installed. The `disabled` list is kept for reference.

## Execution Flow

1. Clean and recreate `logs/` subfolder in the script directory
2. Start logging all output to `logs/run-<timestamp>.log`
3. Load `log-messages.json` → display banner
4. Load `config.json` → determine enabled editions
5. Check for `.code-profile` → parse settings, keybindings, extensions if found
6. Fall back to individual JSON files for any missing data
7. For each enabled edition:
   a. Check if the CLI command is available (`code` / `code-insiders`)
   b. Backup existing `settings.json` and `keybindings.json` (timestamp + suffix)
   c. Copy settings and keybindings to the edition's settings path
   d. Install each enabled extension via CLI
8. Display summary footer

## Logging

- Each run creates a `logs/` subfolder inside the script directory
- The `logs/` folder is cleaned (deleted and recreated) at the start of every run
- A timestamped log file (`run-YYYYMMDD-HHmmss.log`) captures all terminal output
- The `logs` folder is already gitignored by the project-level `.gitignore`

## Prerequisites

- **Windows 10/11**
- **PowerShell 5.1+**
- **VS Code installed** (Stable and/or Insiders)
- **VS Code CLI (`code` / `code-insiders`) in PATH**

## How to Run

```powershell
# From the project root (backup & replace, default):
.\run.ps1 -I 2

# Deep-merge settings into existing settings.json:
.\run.ps1 -I 2 -Merge
```

## Naming Conventions

| Rule | Example |
|------|---------|
| All file names use **lowercase-hyphenated** (kebab-case) | `run.ps1`, `log-messages.json`, `config.json` |
| Never use PascalCase or camelCase for file names | ~~`Sync-VSCodeSettings.ps1`~~ → `run.ps1` |
| Folder names also use lowercase-hyphenated | `02-vscode-settings-sync`, `logs` |
| PowerShell functions inside scripts may use Verb-Noun PascalCase per PS convention | `Write-Status`, `Test-Path` |

## Design Decisions

| Decision                    | Rationale                                                    |
|-----------------------------|--------------------------------------------------------------|
| Profile-first parsing       | Users can drop a .code-profile export and it just works      |
| Fallback to individual JSON | Flexibility — users can also curate files manually           |
| Keybindings support         | Profiles include keybindings; a complete import requires them |
| Separate extensions.json    | Easy to maintain extension list without editing script logic |
| Timestamp backup            | Never lose existing settings, multiple backups coexist       |
| Edition loop                | Single script handles both Stable and Insiders               |
| CLI-based extension install | Official supported method, no registry hacking needed        |
| No admin required           | Settings and extensions are per-user, no elevation needed    |
| Plain ASCII banners         | Avoids Unicode alignment bugs in terminals                   |
| Per-run log files           | Debugging aid; cleaned each run to avoid clutter             |
