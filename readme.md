<div align="center">

# Dev Tools Setup Scripts

**Automated Windows development environment configuration**

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue?logo=powershell&logoColor=white)](https://docs.microsoft.com/powershell/)
[![Windows](https://img.shields.io/badge/Windows-10%2F11-0078D6?logo=windows&logoColor=white)](https://www.microsoft.com/windows)
[![Scripts](https://img.shields.io/badge/Scripts-15-green)](scripts/)
[![License](https://img.shields.io/badge/License-MIT-yellow)](LICENSE)

*One command to set up your entire dev environment. No manual installs. No guesswork.*

</div>

---

## Quick Start

```powershell
# Interactive menu -- pick what to install
.\run.ps1 -d

# Install a specific tool
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

A modular collection of **15 PowerShell scripts** that automate everything from installing VS Code and Git to configuring Go, Python, Node.js, and C++ -- all from a single root dispatcher with an interactive menu.

### Core Tools (01-09)

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

### Optional (10-11)

| ID | Script | What It Does | Admin |
|----|--------|--------------|-------|
| 10 | **VSCode Context Menu Fix** | Add/repair VS Code right-click context menu entries | Yes |
| 11 | **VSCode Settings Sync** | Sync VS Code settings, keybindings, and extensions | No |

### Orchestrator

| ID | Script | What It Does | Admin |
|----|--------|--------------|-------|
| 12 | **Install All Dev Tools** | Interactive grouped menu with CSV input, group shortcuts, and loop-back | Yes |

### Utilities

| ID | Script | What It Does | Admin |
|----|--------|--------------|-------|
| 13 | **Audit Mode** | Scan configs, specs, and suggestions for stale IDs or references | No |
| 14 | **Install Winget** | Install/verify Winget package manager (standalone) | Yes |
| 15 | **Windows Tweaks** | Launch Chris Titus Windows Utility for system tweaks and debloating | Yes |

---

## Root Dispatcher

The root `run.ps1` is the **single entry point** for all scripts. It handles git pull, log cleanup, environment flags, and cache management before delegating.

```powershell
.\run.ps1                           # Show help (after git pull)
.\run.ps1 -I <number>               # Run a specific script
.\run.ps1 -I <number> -Clean        # Wipe cache, then run
.\run.ps1 -CleanOnly                # Wipe all cached data
```

### Shortcut Flags

| Flag | Equivalent | Description |
|------|-----------|-------------|
| `-d` | `-I 12` | Interactive dev tools menu |
| `-a` | `-I 13` | Audit mode |
| `-v` | `-I 1` | Install VS Code |
| `-w` | `-I 14` | Install Winget |
| `-t` | `-I 15` | Windows tweaks |

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

## Project Structure

```
run.ps1                    # Root dispatcher (single entry point)
scripts/
  registry.json            # Maps IDs to folder names
  shared/                  # Reusable helpers (logging, JSON, PATH, etc.)
  01-install-vscode/       # VS Code
  02-install-package-managers/  # Chocolatey
  03-install-nodejs/       # Node.js + Yarn + Bun
  04-install-pnpm/         # pnpm
  05-install-python/       # Python
  06-install-golang/       # Go
  07-install-git/          # Git + LFS + gh
  08-install-github-desktop/  # GitHub Desktop
  09-install-cpp/          # C++ (MinGW-w64)
  10-vscode-context-menu-fix/  # VSCode context menu
  11-vscode-settings-sync/    # VSCode settings sync
  12-install-all-dev-tools/   # Orchestrator (interactive menu)
  audit/                   # Audit scanner
  14-install-winget/       # Winget (standalone)
  15-windows-tweaks/       # Chris Titus Windows Utility
spec/                      # Specifications per script
suggestions/               # Improvement ideas
.resolved/                 # Runtime state (git-ignored)
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
| `logging.ps1` | Console output with colorful status badges, transcript logging |
| `json-utils.ps1` | File backups, hashtable conversion, deep JSON merge |
| `resolved.ps1` | Persist runtime state to `.resolved/` |
| `cleanup.ps1` | Wipe `.resolved/` contents |
| `git-pull.ps1` | Git pull with skip guard (`$env:SCRIPTS_ROOT_RUN`) |
| `help.ps1` | Formatted `-Help` output from log-messages.json |
| `path-utils.ps1` | Safe PATH manipulation with dedup |
| `choco-utils.ps1` | Chocolatey install/upgrade wrappers |
| `dev-dir.ps1` | Dev directory resolution and creation |

---

## Adding a New Script

1. Create folder `scripts/NN-name/` with `run.ps1`, `config.json`, `log-messages.json`, and `helpers/`
2. Dot-source shared helpers from `scripts/shared/`
3. Support `-Help` flag using `Show-ScriptHelp`
4. Save state via `Save-ResolvedData`
5. Add spec in `spec/NN-name/readme.md`
6. Register in `scripts/registry.json`
7. Add to script 12's `config.json` if it should be orchestrated

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
