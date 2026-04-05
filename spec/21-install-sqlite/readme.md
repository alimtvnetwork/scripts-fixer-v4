# Spec: Script 21 -- Install SQLite

## Purpose

Installs SQLite with flexible installation path options and also installs
**DB Browser for SQLite** for a GUI workflow.

## Usage

```powershell
.\run.ps1          # Install SQLite + DB Browser for SQLite
.\run.ps1 -Help    # Show usage
```

From root dispatcher:

```powershell
.\run.ps1 install sqlite
.\run.ps1 -Install sqlite
```

## What gets installed

1. **SQLite CLI** via Chocolatey package `sqlite`
2. **DB Browser for SQLite** via Chocolatey package `sqlitebrowser`

## config.json

| Key | Type | Purpose |
|-----|------|---------|
| `devDir.mode` | string | Resolution mode (json-or-prompt) |
| `devDir.default` | string | Default dev directory path |
| `devDir.override` | string | Hard override (skips prompt) |
| `installMode.default` | string | Default install location (devDir/custom/system) |
| `database.enabled` | bool | Toggle installation |
| `database.chocoPackage` | string | Chocolatey package for SQLite CLI |
| `database.verifyCommand` | string | Command to verify installation |
| `database.versionFlag` | string | Flag to check version |
| `database.browser.enabled` | bool | Toggle DB Browser for SQLite installation |
| `database.browser.name` | string | Friendly browser name |
| `database.browser.chocoPackage` | string | Chocolatey package for DB Browser |

## Install Path Options

1. **Dev directory** (default): `E:\dev\sqlite`
2. **Custom path**: User-specified location
3. **System default**: Package manager default (e.g. `C:\Program Files`)

If the configured drive is unavailable or invalid, the shared dev-dir helper
falls back to a safe path such as `C:\dev`.

## Flow

1. Assert admin privileges
2. Resolve dev directory from config
3. Fall back to a safe local drive if the configured path is invalid or missing
4. Prompt for install location
5. Check if SQLite is already installed
6. Install SQLite via Chocolatey if not found
7. Verify SQLite installation and save resolved state
8. Install DB Browser for SQLite
9. Show summary
