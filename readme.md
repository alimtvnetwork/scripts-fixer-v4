# Windows Dev Environment Setup Scripts

A collection of PowerShell scripts that automate Windows development environment
configuration -- from VS Code settings to installing Go, Node.js, Python, and pnpm.

## Quick Start

```powershell
# Run everything (requires admin)
.\scripts\08-install-all-dev-tools\run.ps1

# Or run individual scripts
.\scripts\03-install-package-managers\run.ps1
.\scripts\04-install-golang\run.ps1

# Get help for any script
.\scripts\04-install-golang\run.ps1 -Help
```

## Scripts

| # | Folder | Purpose | Admin |
|---|--------|---------|-------|
| 01 | `01-vscode-context-menu-fix` | Add/fix VS Code right-click context menu entries | Yes |
| 02 | `02-vscode-settings-sync` | Import VS Code settings, keybindings, and extensions | No |
| 03 | `03-install-package-managers` | Install/update Chocolatey and Winget | Yes |
| 04 | `04-install-golang` | Install Go, configure GOPATH and go env | Yes |
| 05 | `05-install-nodejs` | Install Node.js (LTS), configure npm prefix | Yes |
| 06 | `06-install-python` | Install Python, configure pip user site | Yes |
| 07 | `07-install-pnpm` | Install pnpm, configure global store | No |
| 08 | `08-install-all-dev-tools` | Orchestrator: runs 03-07 in sequence | Yes |

## Dev Directory

Scripts 03-08 install tools into a shared dev directory (default `E:\dev`):

```
E:\dev\
  go\          # GOPATH (bin, pkg/mod, cache/build)
  nodejs\      # npm global prefix
  python\      # PYTHONUSERBASE (Scripts/)
  pnpm\        # pnpm store
```

The orchestrator (script 08) resolves this path once and passes it to all
child scripts via `$env:DEV_DIR`.

## Shared Helpers

Reusable utilities in `scripts/shared/`:

| File | Purpose |
|------|---------|
| `logging.ps1` | Console output with status badges, transcript logging |
| `json-utils.ps1` | File backups, hashtable conversion, deep JSON merge |
| `resolved.ps1` | Persist runtime state to `.resolved/` |
| `cleanup.ps1` | Wipe `.resolved/` contents |
| `git-pull.ps1` | Git pull with skip guard |
| `help.ps1` | Formatted `--help` output |
| `path-utils.ps1` | Safe PATH manipulation with dedup |
| `choco-utils.ps1` | Chocolatey install/upgrade wrappers |
| `dev-dir.ps1` | Dev directory resolution and creation |

## Project Structure

```
scripts/
  shared/              # Reusable helpers
  01-.../              # VS Code context menu
  02-.../              # VS Code settings sync
  03-.../              # Package managers
  04-.../              # Go
  05-.../              # Node.js
  06-.../              # Python
  07-.../              # pnpm
  08-.../              # Orchestrator
spec/                  # Specifications per script
suggestions/           # Improvement ideas
.resolved/             # Runtime state (git-ignored)
```

## Adding a New Script

1. Create folder `scripts/NN-name/` with `run.ps1`, `config.json`,
   `log-messages.json`, and `helpers/`
2. Dot-source shared helpers from `scripts/shared/`
3. Support `-Help` flag using `Show-ScriptHelp`
4. Save state via `Save-ResolvedData`
5. Add spec in `spec/NN-name/readme.md`
6. Register in script 08's `config.json` if it should be orchestrated
