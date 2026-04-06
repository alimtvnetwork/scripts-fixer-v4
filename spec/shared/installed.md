# Spec: Installation Tracking (.installed/)

## Overview

The `.installed/` folder at the project root tracks successfully installed
tool versions as individual JSON files. On subsequent runs, scripts compare
the currently installed version against the tracked version. If they match,
the script skips installation/upgrade entirely -- saving time and avoiding
unnecessary Chocolatey calls.

---

## Directory Layout

```
project-root/
├── .installed/                    # Gitignored -- never committed
│   ├── nodejs.json
│   ├── python.json
│   ├── git.json
│   ├── git-lfs.json
│   ├── github-cli.json
│   ├── golang.json
│   ├── mingw.json
│   ├── pnpm.json
│   ├── yarn.json
│   ├── bun.json
│   ├── chocolatey.json
│   ├── winget.json
│   ├── php.json
│   ├── powershell.json
│   ├── github-desktop.json
│   ├── vscode-stable.json
│   ├── vscode-insiders.json
│   ├── mysql.json
│   ├── postgresql.json
│   └── ...
└── scripts/
    └── shared/
        └── installed.ps1
```

---

## JSON Schema

Each `.installed/<name>.json` file:

```json
{
  "name": "nodejs",
  "version": "v22.14.0",
  "method": "chocolatey",
  "installedAt": "2026-04-06T15:30:00.0000000+08:00",
  "installedBy": "alim",
  "lastError": "",
  "errorAt": ""
}
```

On error:

```json
{
  "name": "nodejs",
  "version": "unknown",
  "method": "chocolatey",
  "installedAt": "2026-04-06T15:30:00.0000000+08:00",
  "installedBy": "alim",
  "lastError": "choco install failed: exit code 1",
  "errorAt": "2026-04-06T15:32:00.0000000+08:00"
}
```

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Tool identifier (matches filename) |
| `version` | string | Exact version string from the tool's CLI |
| `method` | string | Install method: `chocolatey`, `npm`, `winget`, `dotnet-tool`, `msix`, `self`, `system` |
| `installedAt` | string | ISO 8601 timestamp of last install/upgrade |
| `installedBy` | string | Windows username that ran the script |
| `lastError` | string | Empty on success; error message on failure |
| `errorAt` | string | ISO 8601 timestamp of last error (empty if none) |

---

## Functions

All functions live in `scripts/shared/installed.ps1`, auto-loaded by `logging.ps1`.

| Function | Purpose |
|----------|---------|
| `Get-InstalledRecord` | Reads `.installed/<name>.json`, returns parsed object or `$null` |
| `Test-AlreadyInstalled` | Compares name + version; if previous run had error, shows friendly retry message and returns `$false` |
| `Save-InstalledRecord` | Writes/overwrites `.installed/<name>.json` after successful install (clears `lastError`) |
| `Save-InstalledError` | Records an error in `.installed/<name>.json` so the next run knows what went wrong |

---

## Usage Pattern

Every install helper follows this pattern:

```powershell
# 1. Check if tool exists on system
$existing = Get-Command node -ErrorAction SilentlyContinue
if ($existing) {
    $currentVersion = & node --version 2>$null

    # 2. Check tracking -- skip entirely if version matches
    $isAlreadyTracked = Test-AlreadyInstalled -Name "nodejs" -CurrentVersion $currentVersion
    if ($isAlreadyTracked) {
        Write-Log "Node.js $currentVersion already installed" -Level "info"
        return
    }

    # 3. Proceed with upgrade...
    Upgrade-ChocoPackage -PackageName "nodejs-lts"
    $newVersion = & node --version 2>$null

    # 4. Save tracking record
    Save-InstalledRecord -Name "nodejs" -Version $newVersion
}
else {
    # Fresh install...
    Install-ChocoPackage -PackageName "nodejs-lts"
    $installedVersion = & node --version 2>$null
    Save-InstalledRecord -Name "nodejs" -Version $installedVersion
}
```

---

## Scripts Using Tracking

| Script | Tracking Name(s) |
|--------|-------------------|
| 01 - VS Code | `vscode-stable`, `vscode-insiders` |
| 02 - Package Managers | `chocolatey` |
| 03 - Node.js | `nodejs`, `yarn`, `bun` |
| 04 - pnpm | `pnpm` |
| 05 - Python | `python` |
| 06 - Go | `golang` |
| 07 - Git | `git`, `git-lfs`, `github-cli` |
| 08 - GitHub Desktop | `github-desktop` |
| 09 - C++ | `mingw` |
| 14 - Winget | `winget` |
| 16 - PHP | `php` |
| 17 - PowerShell | `powershell` |
| databases | `mysql`, `mariadb`, `postgresql`, `sqlite`, `mongodb`, `couchdb`, `redis`, `cassandra`, `neo4j`, `elasticsearch`, `duckdb`, `litedb` |

---

## Auto-Loading

`installed.ps1` is automatically sourced by `logging.ps1` (which every
script already loads). No manual dot-sourcing needed in `run.ps1` files.

---

## Design Decisions

| Decision | Rationale |
|----------|-----------|
| Root-level `.installed/` | Consistent with `.logs/` and `.resolved/` |
| One JSON per tool | Simple, independent, easy to inspect or delete |
| Exact version match | If version differs, assume upgrade is needed |
| Auto-load via logging.ps1 | Zero changes to existing run.ps1 files |
| Overwrite on re-install | Each successful install updates the tracking file |
| Delete to force re-install | User can delete a single JSON to force that tool's reinstall |
