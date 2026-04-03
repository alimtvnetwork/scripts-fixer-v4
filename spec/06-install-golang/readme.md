# Spec: Script 05 -- Install Golang

## Overview

Installs Go via Chocolatey and configures GOPATH, PATH, and go env settings.
Adapted from the user's existing `go-install.ps1` to follow project conventions.

---

## File Structure

```
scripts/05-install-golang/
+-- config.json              # Go settings, GOPATH config, go env settings
+-- go-config.sample.json    # Original reference config from user
+-- log-messages.json        # Display strings and banners
+-- run.ps1                  # Thin orchestrator with subcommand routing
+-- helpers/
|   +-- golang.ps1           # All Go-specific logic
+-- logs/                    # Auto-created (gitignored)

.resolved/05-install-golang/
+-- resolved.json            # GOPATH, version, timestamps
```

## Subcommands

```powershell
.\run.ps1                    # Install + configure (default "all")
.\run.ps1 install            # Install/upgrade Go only
.\run.ps1 configure          # Configure GOPATH/env only (skip install)
.\run.ps1 -Help              # Show usage
```

## config.json Schema

| Key | Type | Description |
|-----|------|-------------|
| `enabled` | bool | Master enable/disable |
| `chocoPackageName` | string | Chocolatey package name (`golang`) |
| `alwaysUpgradeToLatest` | bool | Upgrade on every run |
| `devDirSubfolder` | string | Subfolder under dev dir for GOPATH |
| `gopath.mode` | string | `json-only` or `json-or-prompt` |
| `gopath.default` | string | Default GOPATH if not overridden |
| `gopath.override` | string | Hard override (skips prompt) |
| `path.updateUserPath` | bool | Add GOPATH\bin to user PATH |
| `path.ensureGoBinInPath` | bool | Ensure bin dir is in PATH |
| `goEnv.applyMode` | string | `json-only` or `json-or-prompt` |
| `goEnv.relativeToGopath` | bool | Resolve relativePath entries from GOPATH |
| `goEnv.settings.*` | object | Individual go env settings (GOMODCACHE, etc.) |

## GOPATH Resolution Priority

1. `$env:DEV_DIR` + `devDirSubfolder` (set by orchestrator script 04)
2. `gopath.override` from config (if non-empty)
3. User prompt (if mode is `json-or-prompt`)
4. `gopath.default` from config

## Functions (helpers/golang.ps1)

| Function | Purpose |
|----------|---------|
| `Install-Go` | Install/upgrade via Chocolatey |
| `Resolve-Gopath` | Priority-based GOPATH resolution |
| `Initialize-Gopath` | Create directory + set env var |
| `Update-GoPath` | Add GOPATH\bin to user PATH (uses shared `Add-ToUserPath`) |
| `Set-GoEnvSetting` | Run `go env -w KEY=VALUE` with logging |
| `Configure-GoEnv` | Apply all go env settings from config |
| `Invoke-GoSetup` | Orchestrate full install + configure flow |

## Prerequisites

- **Windows 10/11**
- **PowerShell 5.1+**
- **Administrator privileges**
- **Chocolatey** (script 03, or will auto-check via `Assert-Choco`)
