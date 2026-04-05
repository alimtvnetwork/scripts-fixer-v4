# Spec: Script 30 -- Install Databases

## Purpose

Interactive database installer supporting SQL, NoSQL (document, key-value,
column, graph), file-based/embedded, and search engine databases. Databases
are installed via Chocolatey (or dotnet tool for LiteDB). Supports three
install location modes: dev directory, custom path, or system default.

---

## Usage

### From script folder (scripts/databases/)

```powershell
.\run.ps1                          # Interactive menu: pick databases to install
.\run.ps1 -All                     # Install all enabled databases
.\run.ps1 -Only mysql,redis        # Install specific databases only
.\run.ps1 -Skip cassandra,neo4j    # Skip specific databases
.\run.ps1 -DryRun                  # Preview what would be installed
.\run.ps1 -Help                    # Show usage
```

### From root dispatcher (project root)

```powershell
.\run.ps1 install databases        # Open interactive database menu (script 30)
.\run.ps1 install db               # Same (alias)
.\run.ps1 -Install databases       # Same via named parameter

.\run.ps1 install mysql            # Direct install: MySQL (script 18)
.\run.ps1 install sqlite           # Direct install: SQLite + DB Browser for SQLite (script 21)
.\run.ps1 install mongodb,redis    # Direct install: MongoDB + Redis (scripts 22, 24)
.\run.ps1 -Install postgresql      # Named parameter style
```

> **Tip:** `databases` and `db` open the interactive menu (script 30).
> Individual DB keywords (e.g. `mysql`, `sqlite`) run the standalone
> scripts directly (18-29) -- they skip the menu entirely.

---

## Two Ways to Install Databases

The root dispatcher exposes database installs in two ways:

### 1. Interactive DB menu (script 30)

Keywords `databases` or `db` launch the full interactive menu where the
user can pick individual databases, quick groups, or all.

```powershell
.\run.ps1 install databases
.\run.ps1 install db
.\run.ps1 -Install databases
```

### 2. Direct DB installs via individual keywords

Each database has its own keyword that maps to a standalone script (18-29).
These run without the interactive menu.

```powershell
.\run.ps1 install mysql             # -> script 18
.\run.ps1 install sqlite            # -> script 21 (SQLite CLI + DB Browser)
.\run.ps1 install mongodb,redis     # -> scripts 22, 24 in order
.\run.ps1 -Install postgresql       # -> script 20
```

This gives users both a guided DB menu and quick one-line installs.

---

## Supported Databases

### Relational (SQL)

| Key        | Name       | Script ID | Choco Package | Description |
|------------|------------|-----------|---------------|-------------|
| mysql      | MySQL      | 18        | mysql         | Popular open-source RDBMS |
| mariadb    | MariaDB    | 19        | mariadb       | MySQL-compatible fork |
| postgresql | PostgreSQL | 20        | postgresql    | Advanced open-source RDBMS |
| sqlite     | SQLite     | 21        | sqlite        | File-based embedded SQL database |

> **SQLite note:** Script 21 also installs **DB Browser for SQLite**
> (`sqlitebrowser` via Chocolatey) for GUI access. See
> [spec/21-install-sqlite](../21-install-sqlite/readme.md) for details.

### NoSQL -- Document

| Key     | Name    | Script ID | Choco Package | Description |
|---------|---------|-----------|---------------|-------------|
| mongodb | MongoDB | 22        | mongodb       | Document-oriented NoSQL database |
| couchdb | CouchDB | 23        | couchdb       | Apache document DB with REST API |

### NoSQL -- Key-Value

| Key   | Name  | Script ID | Choco Package | Description |
|-------|-------|-----------|---------------|-------------|
| redis | Redis | 24        | redis-64      | In-memory key-value store / cache |

### NoSQL -- Column

| Key       | Name             | Script ID | Choco Package | Description |
|-----------|------------------|-----------|---------------|-------------|
| cassandra | Apache Cassandra | 25        | cassandra     | Wide-column distributed database |

### NoSQL -- Graph

| Key   | Name  | Script ID | Choco Package | Description |
|-------|-------|-----------|---------------|-------------|
| neo4j | Neo4j | 26        | neo4j-community | Graph database |

### Search Engine

| Key           | Name          | Script ID | Choco Package   | Description |
|---------------|---------------|-----------|-----------------|-------------|
| elasticsearch | Elasticsearch | 27        | elasticsearch   | Full-text search and analytics |

### File-Based / Embedded

| Key    | Name   | Script ID | Install Method | Description |
|--------|--------|-----------|----------------|-------------|
| sqlite | SQLite | 21        | Choco: `sqlite` + `sqlitebrowser` | SQLite CLI plus DB Browser for SQLite |
| duckdb | DuckDB | 28        | Choco: `duckdb` | Analytical columnar file database |
| litedb | LiteDB | 29        | dotnet tool: `LiteDB.Shell` | .NET embedded NoSQL file database |

---

## Install Path Options

When running interactively, the user is prompted to choose:

1. **Dev directory** (default) -- installs to `E:\dev\databases\<db>`
2. **Custom path** -- user enters any path, databases go into `<path>\databases\<db>`
3. **System default** -- installs to the default system location (e.g. `C:\Program Files`)

If the configured default drive is invalid or missing, the shared dev-dir
helper falls back to a safe local path such as `C:\dev`.

The dev directory path (`E:\dev`) is configurable in `config.json` under
`devDir.default` and `devDir.override`.

---

## config.json

| Key | Type | Purpose |
|-----|------|---------|
| `devDir.mode` | string | Resolution mode (`json-or-prompt`) |
| `devDir.default` | string | Default dev directory path |
| `devDir.override` | string | Hard override (skips prompt) |
| `installMode.default` | string | Default install mode (`devDir` / `custom` / `system`) |
| `databases.<key>.enabled` | bool | Toggle per database |
| `databases.<key>.scriptId` | string | Individual script ID |
| `databases.<key>.folder` | string | Individual script folder name |
| `databases.<key>.name` | string | Display name |
| `databases.<key>.desc` | string | Short description |
| `databases.<key>.type` | string | Category (`sql`, `nosql-document`, `file-based`, etc.) |
| `groups[].letter` | string | Shortcut letter |
| `groups[].label` | string | Group display name |
| `groups[].ids` | array | Database keys in this group |
| `sequence` | array | Execution order (all database keys) |

---

## Interactive Menu

```text
  Install Databases -- Interactive Menu
  ===========================================

    Relational (SQL)
    [ ] 1.  MySQL                   Popular open-source relational database
    [ ] 2.  MariaDB                 MySQL-compatible fork with extra features
    [ ] 3.  PostgreSQL              Advanced open-source relational database
    [ ] 4.  SQLite                  SQLite CLI + DB Browser for SQLite

    NoSQL -- Document
    [ ] 5.  MongoDB                 Document-oriented NoSQL database
    [ ] 6.  CouchDB                 Apache document database with REST API

    NoSQL -- Key-Value
    [ ] 7.  Redis                   In-memory key-value store and cache

    NoSQL -- Column
    [ ] 8.  Apache Cassandra        Wide-column distributed NoSQL database

    NoSQL -- Graph
    [ ] 9.  Neo4j                   Graph database for connected data

    Search Engine
    [ ] 10. Elasticsearch           Full-text search and analytics engine

    File-Based / Embedded
    [ ] 11. DuckDB                  Analytical file-based columnar database
    [ ] 12. LiteDB                  .NET embedded NoSQL file-based database

  Quick groups:
    a. All SQL                          b. All NoSQL
    c. File-Based                       d. Popular Stack
    e. Search + Analytics

  Enter numbers (1,2,5), group letter (a-e), A=all, N=none, Q=quit, Enter=run:
```

---

## Execution Flow

### Interactive mode (default)

```
run.ps1 (no flags)
  |
  +-- Assert admin
  +-- Resolve dev directory (with safe fallback)
  +-- Show interactive menu
  |     |
  |     +-- User picks numbers, groups, or A=all
  |     +-- User presses Enter to confirm
  |
  +-- Prompt for install path (dev dir / custom / system)
  +-- For each selected DB in sequence order:
  |     +-- Invoke-DbScript -> <folder>/run.ps1
  |     +-- Record result (ok / fail / skip)
  |
  +-- Show summary ([OK] / [FAIL] / [SKIP] per DB)
  +-- Save resolved state
  +-- Loop back to menu (press Q to exit)
```

### Non-interactive mode (-All or -Only)

```
run.ps1 -All (or -Only mysql,redis)
  |
  +-- Assert admin
  +-- Resolve dev directory
  +-- Build filtered sequence from flags
  +-- For each DB in sequence:
  |     +-- Invoke-DbScript -> <folder>/run.ps1
  |     +-- Record result
  |
  +-- Show summary
```

### DryRun mode

```
run.ps1 -DryRun
  |
  +-- Same as above but prints [DRY] Would run: ...
  +-- No actual installs
```

---

## Loop-Back Flow

1. User selects databases and presses Enter
2. User chooses install path (dev dir / custom / system)
3. Selected databases install in sequence
4. Summary is displayed
5. Menu re-appears for more installations
6. Press Q to exit

---

## Keyword-to-Script Mapping (install-keywords.json)

| Keyword | Script ID | Notes |
|---------|-----------|-------|
| `databases`, `db` | 30 | Opens interactive menu |
| `mysql` | 18 | Direct install |
| `mariadb` | 19 | Direct install |
| `postgresql`, `postgres`, `psql` | 20 | Direct install |
| `sqlite` | 21 | Installs SQLite CLI + DB Browser for SQLite |
| `mongodb`, `mongo` | 22 | Direct install |
| `couchdb` | 23 | Direct install |
| `redis` | 24 | Direct install |
| `cassandra` | 25 | Direct install |
| `neo4j` | 26 | Direct install |
| `elasticsearch` | 27 | Direct install |
| `duckdb` | 28 | Direct install |
| `litedb` | 29 | Direct install |
