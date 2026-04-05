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
  [ ] 2.  Chocolatey                   Install Chocolatey package manager
  [ ] 3.  Node.js + Yarn + Bun          Install Node.js LTS, Yarn, Bun
  [ ] 4.  pnpm                          Install pnpm, configure store
  [ ] 5.  Python                        Install Python, configure pip
  [ ] 6.  Go                            Install Go, configure GOPATH
  [ ] 7.  Git + LFS + gh                Install Git, Git LFS, GitHub CLI
  [ ] 8.  GitHub Desktop                Install GitHub Desktop
  [ ] 9.  C++ (MinGW-w64)               Install MinGW-w64 C++ compiler
  [ ] 10. VSCode Context Menu           Add/repair right-click entries
  [ ] 11. VSCode Settings Sync          Sync settings, keybindings
  [ ] 12. PHP                           Install PHP via Chocolatey
  [ ] 13. PowerShell (latest)           Install latest PowerShell
  [ ] 14. MySQL                         Open-source relational database
  [ ] 15. MariaDB                       MySQL-compatible fork
  [ ] 16. PostgreSQL                    Advanced relational database
  [ ] 17. SQLite                        File-based embedded SQL database
  [ ] 18. MongoDB                       Document-oriented NoSQL database
  [ ] 19. CouchDB                       Apache document database
  [ ] 20. Redis                         In-memory key-value store
  [ ] 21. Apache Cassandra              Wide-column NoSQL database
  [ ] 22. Neo4j                         Graph database
  [ ] 23. Elasticsearch                 Search and analytics engine
  [ ] 24. DuckDB                        Analytical columnar database
  [ ] 25. LiteDB                        .NET embedded NoSQL database

  Quick groups:
    a. All Core (01-09)               b. Dev Runtimes (03-08)
    c. JS Stack (03-04)               d. Languages (05-06,16)
    e. Git Tools (07-08)              f. Web Dev (03,04,06,08,16)
    g. All + Extras (01-11,16-17)     h. SQL DBs (18-21)
    i. NoSQL DBs (22-26)              j. All Databases (18-29)
    k. Backend Stack (03-04,06,18-20,24)
    l. Full Stack (03,04,06,07,16,18,20,22,24)
    m. Data Engineering (05,20,27,28)
    n. Everything (01-29)

  Enter numbers (1,2,5), group letter (a-n), A=all, N=none, Q=quit, Enter=run:
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
