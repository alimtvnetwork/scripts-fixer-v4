# Spec: VS Code Settings & Extensions Loader

## Overview

A PowerShell utility that applies a predefined VS Code `settings.json` and
installs a list of extensions — for both **Stable** and **Insiders** editions.

---

## Problem

Setting up VS Code on a new machine or after a reinstall requires:

1. Manually copying `settings.json`
2. Individually installing each extension

This is tedious and error-prone, especially when maintaining the same config
across multiple machines.

## Solution

A structured PowerShell script that:

- Reads configuration (paths, editions) from an external **`config.json`**
- Reads log/display messages from a separate **`log-messages.json`**
- Copies a provided `settings.json` into the correct VS Code user settings path
- Backs up existing `settings.json` before overwriting
- Installs all extensions listed in `extensions.json`
- Supports both **VS Code Stable** and **VS Code Insiders**
- Provides colorful, structured terminal output with status badges

---

## File Structure

```
scripts/
└── 02-vscode-settings-sync/
    ├── config.json           # Paths & edition settings
    ├── log-messages.json     # All display strings & banners
    ├── settings.json         # The VS Code settings to apply (user-provided)
    ├── extensions.json       # List of extension IDs to install
    └── run.ps1               # Main script

spec/
└── 02-vscode-settings-sync/
    └── readme.md             # This specification
```

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
  "extensions": [
    "esbenp.prettier-vscode",
    "dbaeumer.vscode-eslint",
    "..."
  ]
}
```

## Execution Flow

1. Load `log-messages.json` → display banner
2. Load `config.json` → determine enabled editions
3. For each enabled edition:
   a. Check if the CLI command is available (`code` / `code-insiders`)
   b. Backup existing `settings.json` (rename with timestamp + suffix)
   c. Copy provided `settings.json` to the edition's settings path
   d. Load `extensions.json` → install each extension via CLI
4. Display summary footer

## Prerequisites

- **Windows 10/11**
- **PowerShell 5.1+**
- **VS Code installed** (Stable and/or Insiders)
- **VS Code CLI (`code` / `code-insiders`) in PATH**

## How to Run

```powershell
# From the project root:
.\run.ps1 -I 2
```

## Design Decisions

| Decision                    | Rationale                                                    |
|-----------------------------|--------------------------------------------------------------|
| Separate extensions.json    | Easy to maintain extension list without editing script logic |
| Timestamp backup            | Never lose existing settings, multiple backups coexist       |
| Edition loop                | Single script handles both Stable and Insiders               |
| CLI-based extension install | Official supported method, no registry hacking needed        |
| No admin required           | Settings and extensions are per-user, no elevation needed    |
