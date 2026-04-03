# Spec: Install PHP

## Overview

A PowerShell script that installs **PHP** via Chocolatey on Windows
and verifies the installation is available in PATH.

---

## File Structure

```
scripts/16-install-php/
├── config.json              # Package name, verify command
├── log-messages.json        # Display strings
├── run.ps1                  # Entry point
├── helpers/
│   └── php.ps1              # Install-Php function
└── logs/                    # Auto-created (gitignored)
```

## Usage

```powershell
.\run.ps1              # Install/verify PHP
.\run.ps1 -Help        # Show usage
```

## config.json Schema

| Key | Type | Description |
|-----|------|-------------|
| `enabled` | bool | Master enable/disable |
| `php.enabled` | bool | Whether to install/check PHP |
| `php.chocoPackage` | string | Chocolatey package name |
| `php.verifyCommand` | string | Command to verify installation |

## Execution Flow

1. If `-Help`: display usage and exit
2. Load shared + script helpers
3. Git pull (unless `$env:SCRIPTS_ROOT_RUN`)
4. Assert admin privileges
5. Check if PHP is already installed
6. If not: install via Chocolatey, refresh PATH, verify
7. Save resolved version to `.resolved/`
