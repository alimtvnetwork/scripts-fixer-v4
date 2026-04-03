# Spec: Script 10 -- Install GitHub Desktop

## Purpose

Install GitHub Desktop via Chocolatey. Simple single-purpose script
with no additional configuration beyond install/upgrade.

## Usage

```powershell
.\run.ps1            # Install/upgrade GitHub Desktop
.\run.ps1 -Help      # Show usage
```

## config.json

| Key | Type | Purpose |
|-----|------|---------|
| `enabled` | bool | Master toggle |
| `chocoPackageName` | string | Chocolatey package (`github-desktop`) |
| `alwaysUpgradeToLatest` | bool | Upgrade on every run |

## Flow

1. Assert admin + Chocolatey
2. Check if GitHub Desktop is installed (command or AppData path)
3. Install via Chocolatey if missing, upgrade if configured
4. Save resolved state
