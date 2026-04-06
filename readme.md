<div align="center">

# Dev Tools Setup Scripts

**Automated Windows development environment configuration**

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue?logo=powershell&logoColor=white)](https://docs.microsoft.com/powershell/)
[![Windows](https://img.shields.io/badge/Windows-10%2F11-0078D6?logo=windows&logoColor=white)](https://www.microsoft.com/windows)
[![Scripts](https://img.shields.io/badge/Scripts-31-green)](scripts/)
[![License](https://img.shields.io/badge/License-MIT-yellow)](LICENSE)
[![Changelog](https://img.shields.io/badge/Changelog-v0.5.0-orange)](CHANGELOG.md)

*One command to set up your entire dev environment. No manual installs. No guesswork.*

</div>

---

## Quick Start

```powershell
# Clone the repo
git clone https://github.com/alimtvnetwork/scripts-fixer-v4.git scripts-fixture
cd scripts-fixture
```

```powershell
# Interactive menu -- pick what to install
.\run.ps1 -d

# Install everything with default answers (no prompts)
.\run.ps1 -d -D

# Install by keyword
.\run.ps1 install nodejs,pnpm
.\run.ps1 install python,git

# Install a specific tool by ID
.\run.ps1 -I 3          # Node.js + Yarn + Bun
.\run.ps1 -I 7          # Git + LFS + gh

# Shortcuts
.\run.ps1 -v             # VS Code
.\run.ps1 -a             # Audit mode
.\run.ps1 -w             # Winget
.\run.ps1 -t             # Windows tweaks

# Show all available scripts
.\run.ps1
```

---

## What It Does

A modular collection of **31 PowerShell scripts** that automate everything from installing VS Code, Git, and databases to configuring Go, Python, Node.js, and C++ -- all from a single root dispatcher with an interactive menu and keyword install system.

### Core Tools (01-09, 16-17)

| ID | Script | What It Does | Admin |
|----|--------|--------------|-------|
| 01 | **Install VS Code** | Install Visual Studio Code (Stable or Insiders) | Yes |
| 02 | **Install Chocolatey** | Install and update the Chocolatey package manager | Yes |
| 03 | **Node.js + Yarn + Bun** | Install Node.js LTS, Yarn, Bun, verify npx | Yes |
| 04 | **pnpm** | Install pnpm, configure global store | No |
| 05 | **Python** | Install Python, configure pip user site | Yes |
| 06 | **Golang** | Install Go, configure GOPATH and go env | Yes |
| 07 | **Git + LFS + gh** | Install Git, Git LFS, GitHub CLI, configure settings | Yes |
| 08 | **GitHub Desktop** | Install GitHub Desktop via Chocolatey | Yes |
| 09 | **C++ (MinGW-w64)** | Install MinGW-w64 C++ compiler, verify g++/gcc/make | Yes |
| 16 | **PHP** | Install PHP via Chocolatey | Yes |
| 17 | **PowerShell (latest)** | Install latest PowerShell via Winget/Chocolatey | Yes |

### VS Code Extras (10-11)

| ID | Script | What It Does | Admin |
|----|--------|--------------|-------|
| 10 | **VSCode Context Menu Fix** | Add/repair VS Code right-click context menu entries | Yes |
| 11 | **VSCode Settings Sync** | Sync VS Code settings, keybindings, and extensions | No |

### Databases (18-29)

| ID | Script | What It Does | Admin |
|----|--------|--------------|-------|
| 18 | **MySQL** | Install MySQL -- popular open-source relational database | Yes |
| 19 | **MariaDB** | Install MariaDB -- MySQL-compatible fork | Yes |
| 20 | **PostgreSQL** | Install PostgreSQL -- advanced relational database | Yes |
| 21 | **SQLite** | Install SQLite + DB Browser for SQLite | Yes |
| 22 | **MongoDB** | Install MongoDB -- document-oriented NoSQL database | Yes |
| 23 | **CouchDB** | Install CouchDB -- Apache document database with REST API | Yes |
| 24 | **Redis** | Install Redis -- in-memory key-value store and cache | Yes |
| 25 | **Apache Cassandra** | Install Cassandra -- wide-column distributed NoSQL | Yes |
| 26 | **Neo4j** | Install Neo4j -- graph database for connected data | Yes |
| 27 | **Elasticsearch** | Install Elasticsearch -- full-text search and analytics | Yes |
| 28 | **DuckDB** | Install DuckDB -- analytical columnar database | Yes |
| 29 | **LiteDB** | Install LiteDB -- .NET embedded NoSQL file-based database | Yes |

### Orchestrators

| ID | Script | What It Does | Admin |
|----|--------|--------------|-------|
| 12 | **Install All Dev Tools** | Interactive grouped menu with CSV input, group shortcuts, and loop-back | Yes |
| 30 | **Install Databases** | Interactive database installer menu (SQL, NoSQL, graph, search) | Yes |

### Utilities

| ID | Script | What It Does | Admin |
|----|--------|--------------|-------|
| 13 | **Audit Mode** | Scan configs, specs, and suggestions for stale IDs or references | No |
| 14 | **Install Winget** | Install/verify Winget package manager (standalone) | Yes |
| 15 | **Windows Tweaks** | Launch Chris Titus Windows Utility for system tweaks and debloating | Yes |
| 31 | **PowerShell Context Menu** | Add "Open PowerShell Here" (normal + admin) to right-click menu | Yes |

---

## Root Dispatcher

The root `run.ps1` is the **single entry point** for all scripts. It handles git pull, log cleanup, environment flags, and cache management before delegating.

```powershell
.\run.ps1                           # Show help (after git pull)
.\run.ps1 -I <number>               # Run a specific script
.\run.ps1 -I <number> -D            # Run with all default answers (skip prompts)
.\run.ps1 -I <number> -Clean        # Wipe cache, then run
.\run.ps1 -CleanOnly                # Wipe all cached data
```

### Shortcut Flags

| Flag | Equivalent | Description |
|------|-----------|-------------|
| `-d` | `-I 12` | Interactive dev tools menu |
| `-D` | N/A | Use all default answers (skip prompts) |
| `-a` | `-I 13` | Audit mode |
| `-v` | `-I 1` | Install VS Code |
| `-w` | `-I 14` | Install Winget |
| `-t` | `-I 15` | Windows tweaks |

### Keyword Install

Install tools by human-friendly name instead of script ID:

```powershell
.\run.ps1 install vscode             # Install VS Code
.\run.ps1 install nodejs,pnpm        # Install Node.js + pnpm
.\run.ps1 install go,git,cpp         # Install Go, Git, C++
.\run.ps1 -Install python,php        # Named parameter style
.\run.ps1 install databases          # Interactive database menu
.\run.ps1 install mysql,redis        # Install specific databases
```

Keywords are case-insensitive, support comma/space separation, auto-deduplicate, and run in sorted order. See `scripts/shared/install-keywords.json` for the full keyword map.

---

## Interactive Menu (Script 12)

When you run `.\run.ps1 -d`, you get a full interactive menu with:

- **Individual selection** -- type script numbers: `1`, `3`, `7`
- **CSV input** -- type comma-separated IDs: `1,3,5,7`
- **Group shortcuts** -- press a letter to select a predefined group:

| Key | Group | Scripts |
|-----|-------|---------|
| `a` | All Core (01-09) | 01, 02, 03, 04, 05, 06, 07, 08, 09 |
| `b` | Dev Runtimes (03-08) | 03, 04, 05, 06, 07, 08 |
| `c` | JS Stack (03-04) | 03, 04 |
| `d` | Languages (05-06,16) | 05, 06, 16 |
| `e` | Git Tools (07-08) | 07, 08 |
| `f` | Web Dev (03,04,06,08,16) | 03, 04, 06, 08, 16 |
| `g` | All + Extras (01-11,16-17) | 01-11, 16, 17 |

- **Select All / None** -- `A` to select all, `N` to deselect all
- **Loop-back** -- after install + summary, returns to the menu
- **Quit** -- press `Q` to exit

---

## Dev Directory

Scripts install tools into a shared dev directory (default `E:\dev`):

```
E:\dev\
  go\          # GOPATH (bin, pkg/mod, cache/build)
  nodejs\      # npm global prefix
  python\      # PYTHONUSERBASE (Scripts/)
  pnpm\        # pnpm store
```

The orchestrator (script 12) resolves this path once and passes it to all child scripts via `$env:DEV_DIR`.

---

## Versioning

All scripts read their version from `scripts/version.json` (single source of truth). Use the bump script:

```powershell
.\bump-version.ps1 -Patch            # 0.3.0 -> 0.3.1
.\bump-version.ps1 -Minor            # 0.3.0 -> 0.4.0
.\bump-version.ps1 -Major            # 0.3.0 -> 1.0.0
.\bump-version.ps1 -Set "2.0.0"     # Explicit version
```

---

## Project Structure

```
run.ps1                        # Root dispatcher (single entry point)
bump-version.ps1               # Version bump utility
scripts/
  version.json                 # Centralized version (single source of truth)
  registry.json                # Maps IDs to folder names
  shared/                      # Reusable helpers (logging, JSON, PATH, etc.)
    install-keywords.json      # Keyword-to-script-ID mapping
  01-install-vscode/           # VS Code
  02-install-package-managers/ # Chocolatey
  03-install-nodejs/           # Node.js + Yarn + Bun
  04-install-pnpm/             # pnpm
  05-install-python/           # Python
  06-install-golang/           # Go
  07-install-git/              # Git + LFS + gh
  08-install-github-desktop/   # GitHub Desktop
  09-install-cpp/              # C++ (MinGW-w64)
  10-vscode-context-menu-fix/  # VSCode context menu
  11-vscode-settings-sync/     # VSCode settings sync
  12-install-all-dev-tools/    # Orchestrator (interactive menu)
  14-install-winget/           # Winget (standalone)
  15-windows-tweaks/           # Chris Titus Windows Utility
  16-install-php/              # PHP
  17-install-powershell/       # PowerShell (latest)
  18-install-mysql/            # MySQL
  19-install-mariadb/          # MariaDB
  20-install-postgresql/       # PostgreSQL
  21-install-sqlite/           # SQLite + DB Browser
  22-install-mongodb/          # MongoDB
  23-install-couchdb/          # CouchDB
  24-install-redis/            # Redis
  25-install-cassandra/        # Apache Cassandra
  26-install-neo4j/            # Neo4j
  27-install-elasticsearch/    # Elasticsearch
  28-install-duckdb/           # DuckDB
  29-install-litedb/           # LiteDB
  databases/                   # Database orchestrator menu
  31-pwsh-context-menu/        # PowerShell context menu
  audit/                       # Audit scanner
spec/                          # Specifications per script
suggestions/                   # Improvement ideas
.resolved/                     # Runtime state (git-ignored)
```

### Each Script Contains

```
scripts/NN-name/
  run.ps1                  # Entry point
  config.json              # External configuration
  log-messages.json        # All display strings
  helpers/                 # Script-specific functions
  logs/                    # Auto-created (gitignored)
```

---

## Shared Helpers

Reusable utilities in `scripts/shared/`:

| File | Purpose |
|------|---------|
| `logging.ps1` | Console output with colorful status badges, auto-version from `version.json` |
| `json-utils.ps1` | File backups, hashtable conversion, deep JSON merge |
| `resolved.ps1` | Persist runtime state to `.resolved/` |
| `cleanup.ps1` | Wipe `.resolved/` contents |
| `git-pull.ps1` | Git pull with skip guard (`$env:SCRIPTS_ROOT_RUN`) |
| `help.ps1` | Formatted `-Help` output from log-messages.json |
| `path-utils.ps1` | Safe PATH manipulation with dedup |
| `choco-utils.ps1` | Chocolatey install/upgrade wrappers |
| `dev-dir.ps1` | Dev directory resolution and creation |
| `install-keywords.json` | Keyword-to-script-ID mapping for `install` command |
| `log-viewer.ps1` | Log file viewer utility |

---

## Adding a New Script

1. Create folder `scripts/NN-name/` with `run.ps1`, `config.json`, `log-messages.json`, and `helpers/`
2. Dot-source shared helpers from `scripts/shared/`
3. Support `-Help` flag using `Show-ScriptHelp`
4. Save state via `Save-ResolvedData`
5. Add spec in `spec/NN-name/readme.md`
6. Register in `scripts/registry.json`
7. Add keywords in `scripts/shared/install-keywords.json`
8. Add to script 12's `config.json` if it should be orchestrated

---

## Recent Changes

### v0.4.1 -- Crash-Safe Error Logging

- **try/catch/finally wrapper** in all 31 `run.ps1` files -- `Save-LogFile` now always runs, even on unhandled exceptions
- **Warnings captured in error logs** alongside errors, with separate `errors` and `warnings` arrays in the JSON schema
- **4-tier VS Code exe fallback**: config paths → Chocolatey shim/lib → `Get-Command` → `where.exe` (script 10)
- **Chocolatey shim fallback** for `pwsh.exe` detection (script 31)
- **Full-path diagnostics** in `fileExistsAtPath` log messages (shows the path being checked, not just True/False)
- **Get-InstalledDir function** replaces `$script:_InstalledDir` variable -- fixes "variable not set" crash in all scripts
- **Save-InstalledRecord** handles empty version strings gracefully (falls back to `'unknown'`)

### v0.4.0 -- Error Tracking and Registry API Migration

- **Save-InstalledError** catch blocks added to all 13 install helper scripts for per-tool error tracking
- **All Databases Only** option added as quick menu choice in script 12
- **Scripts 10 and 31** migrated from `reg.exe` to .NET `Microsoft.Win32.Registry` API -- fixes nested-quote parsing failures
- **Error Tracking** section added to `spec/shared/installed.md` with field docs, JSON examples, and retry behaviour

---

## Prerequisites

- **Windows 10/11**
- **PowerShell 5.1+** (ships with Windows)
- **Administrator privileges** (for most scripts)
- **Internet access** (for package downloads)

---

## Author

<div align="center">

### Md. Alim Ul Karim

**Chief Software Engineer** | Riseup Asia LLC

</div>

A Software Architect and Chief Software Engineer with **20+ years** of professional experience across enterprise-scale systems. His technology stack spans **.NET/C# (18+ years)**, **JavaScript (10+ years)**, **TypeScript (6+ years)**, and **Golang (4+ years)**.

Recognized as a **top 1% talent at Crossover**, he has worked across AdTech, staff augmentation platforms, and full-stack enterprise architecture. He is also the **CEO of Riseup Asia LLC** and maintains an active presence on **Stack Overflow** (2,452+ reputation, member since 2010) and **LinkedIn** (12,500+ followers).

His published writings on clean function design and meaningful naming directly inform the coding principles encoded in this specification system.

| | |
|---|---|
| **Website** | [alimkarim.com](https://alimkarim.com) · [my.alimkarim.com](https://my.alimkarim.com) |
| **LinkedIn** | [linkedin.com/in/alimkarim](https://linkedin.com/in/alimkarim) |
| **Role** | Chief Software Engineer, Riseup Asia LLC |

---

<div align="center">

*Built with clean architecture, external configs, and colorful terminal output -- because dev tools setup should be effortless.*

</div>
