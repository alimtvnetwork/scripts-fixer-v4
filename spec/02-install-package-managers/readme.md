# Spec: Install Package Managers

## Overview

A PowerShell script that installs and/or updates **Chocolatey** and **Winget**
package managers on Windows. These are prerequisites for scripts 04-07.

---

## File Structure

```
scripts/03-install-package-managers/
├── config.json              # Enable/disable each manager, install URLs
├── log-messages.json        # Display strings and banners
├── run.ps1                  # Thin orchestrator with subcommand routing
├── helpers/
│   ├── choco.ps1            # Install-Chocolatey function
│   └── winget.ps1           # Install-Winget function
└── logs/                    # Auto-created (gitignored)

.resolved/03-install-package-managers/
└── resolved.json            # Installed versions + timestamps
```

## Subcommands

```powershell
.\run.ps1                    # Install both (default "all")
.\run.ps1 choco              # Chocolatey only
.\run.ps1 winget             # Winget only
.\run.ps1 -Help              # Show usage
```

## config.json Schema

| Key | Type | Description |
|-----|------|-------------|
| `chocolatey.enabled` | bool | Whether to install/check Chocolatey |
| `chocolatey.installUrl` | string | URL for Chocolatey install script |
| `chocolatey.upgradeOnRun` | bool | Upgrade Chocolatey itself on every run |
| `winget.enabled` | bool | Whether to install/check Winget |
| `winget.installIfMissing` | bool | Install Winget if not found |
| `winget.msStoreUrl` | string | Download URL for App Installer package |

## Execution Flow

1. Parse subcommand (default: `all`)
2. If `-Help`: display usage and exit
3. Load shared helpers (logging, choco-utils, resolved, help)
4. Load script helpers (choco.ps1, winget.ps1)
5. Git pull (unless `$env:SCRIPTS_ROOT_RUN`)
6. Start logging
7. Assert admin privileges
8. Load config.json
9. Route to subcommand handler:
   - `choco`: Install-Chocolatey
   - `winget`: Install-Winget
   - `all`: both in sequence
10. Save resolved versions to `.resolved/`
11. Display summary

## Prerequisites

- **Windows 10/11**
- **PowerShell 5.1+**
- **Administrator privileges**
- **Internet access** (for downloads)

## Design Decisions

| Decision | Rationale |
|----------|-----------|
| Subcommand via positional param | Simple, no extra flags needed |
| Assert-Choco from shared helper | Same logic reused by scripts 04-06 |
| Winget via msixbundle download | Works when Microsoft Store is unavailable |
| Versions saved to .resolved/ | Other scripts can check prerequisite versions |
