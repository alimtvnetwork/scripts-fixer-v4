# Spec: Script 09 -- Install Git

## Purpose

Install Git via Chocolatey and configure global settings including
user identity, credential manager, and line endings.

## Subcommands

| Command | Description |
|---------|-------------|
| `all` | Install Git + configure globals (default) |
| `install` | Install/upgrade Git only |
| `configure` | Configure global git settings only |
| `-Help` | Show usage information |

## config.json

| Key | Type | Purpose |
|-----|------|---------|
| `enabled` | bool | Master toggle |
| `chocoPackageName` | string | Chocolatey package (`git`) |
| `alwaysUpgradeToLatest` | bool | Upgrade on every run |
| `gitConfig.userName` | object | user.name (json-or-prompt mode) |
| `gitConfig.userEmail` | object | user.email (json-or-prompt mode) |
| `gitConfig.credentialManager` | object | credential.helper config |
| `gitConfig.lineEndings` | object | core.autocrlf config |
| `path.updateUserPath` | bool | Add git bin to PATH |

## Flow

1. Assert admin + Chocolatey
2. Install/upgrade Git via Chocolatey
3. Configure user.name (from config or prompt)
4. Configure user.email (from config or prompt)
5. Set credential.helper to `manager` (Git Credential Manager)
6. Set core.autocrlf to `true`
7. Ensure git bin is in PATH
8. Save resolved state
