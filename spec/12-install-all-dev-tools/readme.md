# Spec: Script 04 -- Install All Dev Tools

## Purpose

Orchestrator that resolves the dev directory once, sets `$env:DEV_DIR`,
then runs all numbered scripts (01-03, 05-10) in sequence. Supports
`--skip` and `--only` filters, plus an interactive picker menu.

## Usage

```powershell
.\run.ps1                    # Interactive menu: pick what to install
.\run.ps1 -All               # Run all enabled scripts without prompting
.\run.ps1 -Skip "06,08"     # Skip Node.js and pnpm
.\run.ps1 -Only "03,05"     # Run only package managers + Go
.\run.ps1 -Help             # Show usage
```

## config.json

| Key | Type | Purpose |
|-----|------|---------|
| `devDir.mode` | string | Resolution mode (json-or-prompt) |
| `devDir.default` | string | Default dev directory path |
| `devDir.override` | string | Hard override (skips prompt) |
| `scripts.<id>.enabled` | bool | Toggle per script |
| `scripts.<id>.folder` | string | Script folder name |
| `scripts.<id>.name` | string | Display name |
| `scripts.<id>.desc` | string | Short description |
| `sequence` | array | Execution order |

## Available Scripts

| ID | Name | Description |
|----|------|-------------|
| 01 | VSCode Context Menu | Add/repair VSCode right-click context menu entries |
| 02 | VSCode Settings Sync | Sync VSCode settings, keybindings, and extensions |
| 03 | Package Managers | Install Chocolatey and Winget |
| 05 | Go | Install Go, configure GOPATH and go env |
| 06 | Node.js | Install Node.js LTS, configure npm prefix |
| 07 | Python | Install Python, configure pip user site |
| 08 | pnpm | Install pnpm, configure global store |
| 09 | Git + LFS + gh | Install Git, Git LFS, GitHub CLI, configure settings |
| 10 | GitHub Desktop | Install GitHub Desktop |

## Sequence

Default order: `01 (VSCode Context Menu) > 02 (VSCode Settings Sync) > 03 (Package Managers) > 09 (Git + LFS + gh) > 05 (Go) > 06 (Node.js) > 07 (Python) > 08 (pnpm) > 10 (GitHub Desktop)`

## Interactive Menu

When run with no flags (or explicitly with `-Menu`), the script shows a
numbered list of available scripts. The user toggles selections by typing
numbers (space-separated), then presses Enter to run selected scripts.

```
  Install All Dev Tools -- Interactive Menu
  ==========================================

  [x] 1. VSCode Context Menu      Add/repair right-click entries
  [x] 2. VSCode Settings Sync     Sync settings, keybindings, extensions
  [x] 3. Package Managers         Install Chocolatey and Winget
  [x] 4. Git + LFS + gh           Install Git, Git LFS, GitHub CLI
  [x] 5. Go                       Install Go, configure GOPATH
  [x] 6. Node.js                  Install Node.js LTS
  [x] 7. Python                   Install Python, configure pip
  [x] 8. pnpm                     Install pnpm, configure store
  [x] 9. GitHub Desktop           Install GitHub Desktop

  Toggle by number (e.g. "2 5 8"), A=all, N=none, Enter=run selected:
```

## Flow

1. Assert admin privileges
2. Resolve dev directory (env > config override > prompt > default)
3. Create dev directory structure
4. Set `$env:DEV_DIR` for child scripts
5. If interactive mode: show picker, get user selections
6. Build filtered script list (apply --skip / --only / picker)
7. Run each script's `run.ps1` in sequence
8. Print summary table with status badges
9. Save resolved state

## Summary Output

```
--- Summary ---
  [OK]   01 - VSCode Context Menu
  [OK]   02 - VSCode Settings Sync
  [OK]   03 - Package Managers
  [OK]   09 - Git + LFS + gh
  [OK]   05 - Go
  [SKIP] 06 - Node.js
  [OK]   07 - Python
  [SKIP] 08 - pnpm
  [OK]   10 - GitHub Desktop
```
