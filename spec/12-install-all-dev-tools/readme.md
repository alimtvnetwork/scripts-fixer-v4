# Spec: Script 12 -- Install All Dev Tools

## Purpose

Orchestrator that front-loads all configuration questions, then runs
selected scripts unattended. Supports three interactive modes plus
flag-based CLI modes.

## Usage

```powershell
.\run.ps1                    # Interactive: quick menu + questionnaire
.\run.ps1 -D                 # All Dev with all default answers (zero prompts)
.\run.ps1 -Defaults          # Same as -D (full name)
.\run.ps1 -D -Only "03,05"  # Defaults mode for specific scripts only
.\run.ps1 -All               # Run all enabled scripts without prompting
.\run.ps1 -Skip "06,08"     # Skip specific scripts
.\run.ps1 -Only "03,05"     # Run only specific scripts
.\run.ps1 -DryRun            # Preview what would run
.\run.ps1 -Help             # Show usage
```

## Interactive Flow

### Step 1: Quick Menu

```
  What would you like to install?
  ================================

    [1] All Dev Tools (VS Code, Node.js, Python, Go, Git, C++, PHP, PowerShell)
    [2] All Dev Tools + All Databases (everything above + MySQL, PostgreSQL, MongoDB, etc.)
    [3] Custom (pick individual tools from the full list)
    [Q] Quit

  Choose [1/2/3/Q] (default: 1):
```

| Choice | Mode | Scripts |
|--------|------|---------|
| 1 | `alldev` | 01-11, 16-17, 31 (all dev tools, no databases) |
| 2 | `alldev+db` | 01-11, 16-17, 18-29, 31 (everything) |
| 3 | `custom` | Full interactive checkbox menu (same as before) |
| Q | `quit` | Exit |

### Step 2: Questionnaire (front-loaded)

All configuration questions are asked **before any scripts run**. Answers
are stored in environment variables so child scripts skip their own prompts.

| Question | Env Var | Options |
|----------|---------|---------|
| Dev directory path | `$env:DEV_DIR` | Custom path or default (E:\dev) |
| VS Code editions | `$env:VSCODE_EDITIONS` | stable / insiders / stable,insiders |
| VS Code settings sync | `$env:VSCODE_SYNC_MODE` | overwrite / merge / skip |
| Git user.name | `$env:GIT_USER_NAME` | Full name (auto-detected if already set) |
| Git user.email | `$env:GIT_USER_EMAIL` | Email (auto-detected if already set) |

The orchestrator also sets `$env:SCRIPTS_ROOT_RUN = "1"` so child scripts
know they are running under Script 12 and should use defaults instead of
prompting.

## Environment Variable Injection

Child scripts check these env vars and skip their own `Read-Host` prompts
when values are already set by the questionnaire:

| Env Var | Consumed By | Effect |
|---------|-------------|--------|
| `$env:DEV_DIR` | `shared/dev-dir.ps1`, `06-golang` | Skips dev-directory prompt, sets GOPATH |
| `$env:VSCODE_EDITIONS` | `01-install-vscode` | Skips edition selection prompt |
| `$env:VSCODE_SYNC_MODE` | `11-vscode-settings-sync` | Skips sync-mode prompt (overwrite/merge/skip) |
| `$env:GIT_USER_NAME` | `07-install-git` | Skips user.name prompt |
| `$env:GIT_USER_EMAIL` | `07-install-git` | Skips user.email prompt |
| `$env:SCRIPTS_ROOT_RUN` | `09-cpp`, `15-windows-tweaks` | Uses defaults, skips confirmations |

### Step 3: Unattended Execution

Scripts run in sequence with no interactive prompts. Each reads its
configuration from the environment variables set in Step 2.

### Step 4: Summary + Loop Back

After all scripts complete, the summary is displayed and the quick menu
re-appears so the user can install more or quit.

## Custom Menu (Option 3)

When "Custom" is selected, the full interactive checkbox menu appears:

- Type **numbers** (CSV or space-separated): `1,2,5` or `1 2 5` to toggle
- Type a **group letter** (`a`-`n`) to select a predefined group
- Type `A` to select all, `N` to deselect all
- Press **Enter** to run selected items
- Type `Q` to quit

## Database Installation

Database scripts (18-29) install via Chocolatey to the **system default
location** (not custom directories, which requires Chocolatey Business).
Environment variables and symlinks are used to link databases to the dev
directory post-install.

## config.json

| Key | Type | Purpose |
|-----|------|---------|
| `devDir.mode` | string | Resolution mode (json-or-prompt) |
| `devDir.default` | string | Default dev directory path |
| `devDir.override` | string | Hard override (skips prompt) |
| `groups[].label` | string | Display name for the group |
| `groups[].letter` | string | Shortcut letter (a-n) |
| `groups[].ids` | array | Script IDs in this group |
| `scripts.<id>.enabled` | bool | Toggle per script |
| `scripts.<id>.folder` | string | Script folder name |
| `scripts.<id>.name` | string | Display name |
| `scripts.<id>.desc` | string | Short description |
| `sequence` | array | Execution order |

## Available Scripts

| ID | Name | Description |
|----|------|-------------|
| 01 | VS Code | Install Visual Studio Code (Stable/Insiders) |
| 02 | Chocolatey | Install Chocolatey package manager |
| 03 | Node.js + Yarn + Bun | Install Node.js LTS, Yarn, Bun, verify npx |
| 04 | pnpm | Install pnpm, configure global store |
| 05 | Python | Install Python, configure pip user site |
| 06 | Go | Install Go, configure GOPATH and go env |
| 07 | Git + LFS + gh | Install Git, Git LFS, GitHub CLI |
| 08 | GitHub Desktop | Install GitHub Desktop |
| 09 | C++ (MinGW-w64) | Install MinGW-w64 C++ compiler |
| 10 | VSCode Context Menu | Add/repair VSCode right-click entries |
| 11 | VSCode Settings Sync | Sync settings, keybindings, extensions |
| 16 | PHP | Install PHP via Chocolatey |
| 17 | PowerShell (latest) | Install latest PowerShell via Winget/Chocolatey |
| 18 | MySQL | Popular open-source relational database |
| 19 | MariaDB | MySQL-compatible fork with extra features |
| 20 | PostgreSQL | Advanced open-source relational database |
| 21 | SQLite | File-based embedded SQL database |
| 22 | MongoDB | Document-oriented NoSQL database |
| 23 | CouchDB | Apache document database with REST API |
| 24 | Redis | In-memory key-value store and cache |
| 25 | Apache Cassandra | Wide-column distributed NoSQL database |
| 26 | Neo4j | Graph database for connected data |
| 27 | Elasticsearch | Full-text search and analytics engine |
| 28 | DuckDB | Analytical file-based columnar database |
| 29 | LiteDB | .NET embedded NoSQL file-based database |
| 31 | PowerShell Context Menu | Add PowerShell right-click context menu |

## Summary Output

```
--- Summary ---
  [OK]   01 - VS Code
  [OK]   02 - Package Managers
  [OK]   03 - Node.js + Yarn + Bun
  [SKIP] 04 - pnpm
  [OK]   07 - Git + LFS + gh
```

## Helpers

| File | Functions | Purpose |
|------|-----------|---------|
| `orchestrator.ps1` | (loader) | Dot-sources all helper files |
| `resolve.ps1` | `Resolve-ScriptList` | Builds script list from config with skip/only filters |
| `menu.ps1` | `Show-InteractiveMenu`, `Show-DryRun` | Full checkbox menu for custom mode |
| `execution.ps1` | `Invoke-ScriptSequence` | Runs scripts in sequence, captures results |
| `summary.ps1` | `Show-Summary` | Displays formatted summary table |
| `questionnaire.ps1` | `Show-QuickMenu`, `Invoke-Questionnaire`, `Get-ScriptListForMode` | Quick 3-option menu and front-loaded questions |
