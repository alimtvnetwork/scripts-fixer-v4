# Spec: Script 12 -- Install All Dev Tools

## Purpose

Orchestrator that resolves the dev directory once, sets `$env:DEV_DIR`,
then runs scripts 01-11 in sequence. Supports an interactive grouped menu
with lettered group shortcuts, CSV number input, and loop-back behavior,
plus `-All`, `-Skip`, and `-Only` flag-based modes.

## Usage

```powershell
.\run.ps1                    # Interactive menu: pick what to install
.\run.ps1 -All               # Run all enabled scripts without prompting
.\run.ps1 -Skip "06,08"     # Skip specific scripts
.\run.ps1 -Only "03,05"     # Run only specific scripts
.\run.ps1 -DryRun            # Preview what would run
.\run.ps1 -Help             # Show usage
```

## config.json

| Key | Type | Purpose |
|-----|------|---------|
| `devDir.mode` | string | Resolution mode (json-or-prompt) |
| `devDir.default` | string | Default dev directory path |
| `devDir.override` | string | Hard override (skips prompt) |
| `groups[].label` | string | Display name for the group |
| `groups[].letter` | string | Shortcut letter (a, b, c...) |
| `groups[].ids` | array | Script IDs in this group |
| `groups[].checkedByDefault` | bool | Selection state on menu open |
| `scripts.<id>.enabled` | bool | Toggle per script |
| `scripts.<id>.folder` | string | Script folder name |
| `scripts.<id>.name` | string | Display name |
| `scripts.<id>.desc` | string | Short description |
| `sequence` | array | Execution order |

## Available Scripts

| ID | Name | Description |
|----|------|-------------|
| 01 | VS Code | Install Visual Studio Code (Stable/Insiders) |
| 02 | Package Managers | Install Chocolatey and Winget |
| 03 | Node.js + Yarn + Bun | Install Node.js LTS, Yarn, Bun, verify npx |
| 04 | pnpm | Install pnpm, configure global store |
| 05 | Python | Install Python, configure pip user site |
| 06 | Go | Install Go, configure GOPATH and go env |
| 07 | Git + LFS + gh | Install Git, Git LFS, GitHub CLI |
| 08 | GitHub Desktop | Install GitHub Desktop |
| 09 | C++ (MinGW-w64) | Install MinGW-w64 C++ compiler |
| 10 | VSCode Context Menu | Add/repair VSCode right-click entries |
| 11 | VSCode Settings Sync | Sync settings, keybindings, extensions |

## Interactive Menu

When run with no flags, the script displays a numbered list with **all
items unchecked by default**. The user can:

- Type **numbers** (CSV or space-separated): `1,2,5` or `1 2 5` to toggle
- Type a **group letter** (`a`, `b`, `c`...) to select a predefined group
- Type `A` to select all, `N` to deselect all
- Press **Enter** to install selected items
- Type `Q` to quit without installing

After installation completes and the summary is displayed, the menu
**loops back** so the user can install more tools without restarting.

### Example Menu

```
  Install All Dev Tools -- Interactive Menu
  ==========================================

  [ ] 1.  VS Code                      Install Visual Studio Code
  [ ] 2.  Package Managers              Install Chocolatey and Winget
  [ ] 3.  Node.js + Yarn + Bun          Install Node.js LTS, Yarn, Bun
  [ ] 4.  pnpm                          Install pnpm, configure store
  [ ] 5.  Python                        Install Python, configure pip
  [ ] 6.  Go                            Install Go, configure GOPATH
  [ ] 7.  Git + LFS + gh                Install Git, Git LFS, GitHub CLI
  [ ] 8.  GitHub Desktop                Install GitHub Desktop
  [ ] 9.  C++ (MinGW-w64)               Install MinGW-w64 C++ compiler
  [ ] 10. VSCode Context Menu           Add/repair right-click entries
  [ ] 11. VSCode Settings Sync          Sync settings, keybindings

  Quick groups:
    a. All Core (01-09)          b. Dev Runtimes (03-08)
    c. JS Stack (03-04)          d. Languages (05-06)
    e. Git Tools (07-08)         f. Web Dev (03,04,06,08)

  Enter numbers (1,2,5), group letter (a-f), A=all, N=none, Q=quit, Enter=run:
```

### Loop-Back Flow

1. User selects items and presses Enter
2. Selected scripts run in sequence
3. Summary is displayed
4. Menu re-appears with all items unchecked
5. User can select more or press Q to exit

## Flow

1. Assert admin privileges
2. Resolve dev directory (env > config override > prompt > default)
3. Create dev directory structure
4. Set `$env:DEV_DIR` for child scripts
5. Show interactive menu (loop)
   a. Display numbered list + group shortcuts
   b. Accept input: numbers, group letters, A/N/Q
   c. On Enter: run selected, show summary, loop back
   d. On Q: exit
6. Save resolved state

## Summary Output

```
--- Summary ---
  [OK]   01 - VS Code
  [OK]   02 - Package Managers
  [OK]   03 - Node.js + Yarn + Bun
  [SKIP] 04 - pnpm
  [OK]   07 - Git + LFS + gh
```
