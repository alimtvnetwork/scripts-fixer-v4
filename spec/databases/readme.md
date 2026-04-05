# Spec: Script 30 -- Install Databases

## Purpose

Interactive database installer supporting SQL, NoSQL (document, key-value,
column, graph), file-based/embedded, and search engine databases. Databases
are installed via Chocolatey (or dotnet tool for LiteDB). Supports three
install location modes: dev directory, custom path, or system default.

## Usage

```powershell
.\run.ps1                          # Interactive menu: pick databases to install
.\run.ps1 -All                     # Install all enabled databases
.\run.ps1 -Only mysql,redis        # Install specific databases only
.\run.ps1 -Skip cassandra,neo4j    # Skip specific databases
.\run.ps1 -DryRun                  # Preview what would be installed
.\run.ps1 -Help                    # Show usage
```

From root dispatcher:

```powershell
.\run.ps1 install databases        # Interactive database menu
.\run.ps1 install mysql            # Install MySQL
.\run.ps1 install postgresql       # Install PostgreSQL
.\run.ps1 install sqlite           # Install SQLite + DB Browser for SQLite
.\run.ps1 install mongodb,redis    # Install MongoDB + Redis
.\run.ps1 -Install databases       # Same interactive database menu
```

## Supported Databases

### Relational (SQL)

| Key        | Name       | Script ID | Description |
|------------|------------|-----------|-------------|
| mysql      | MySQL      | 18        | Popular open-source RDBMS |
| mariadb    | MariaDB    | 19        | MySQL-compatible fork |
| postgresql | PostgreSQL | 20        | Advanced open-source RDBMS |
| sqlite     | SQLite     | 21        | File-based embedded SQL database + DB Browser for SQLite |

### NoSQL -- Document

| Key     | Name    | Script ID | Description |
|---------|---------|-----------|-------------|
| mongodb | MongoDB | 22        | Document-oriented NoSQL database |
| couchdb | CouchDB | 23        | Apache document DB with REST API |

### NoSQL -- Key-Value

| Key   | Name  | Script ID | Description |
|-------|-------|-----------|-------------|
| redis | Redis | 24        | In-memory key-value store / cache |

### NoSQL -- Column

| Key       | Name             | Script ID | Description |
|-----------|------------------|-----------|-------------|
| cassandra | Apache Cassandra | 25        | Wide-column distributed database |

### NoSQL -- Graph

| Key   | Name  | Script ID | Description |
|-------|-------|-----------|-------------|
| neo4j | Neo4j | 26        | Graph database |

### Search Engine

| Key           | Name          | Script ID | Description |
|---------------|---------------|-----------|-------------|
| elasticsearch | Elasticsearch | 27        | Full-text search and analytics |

### File-Based / Embedded

| Key    | Name   | Script ID | Description |
|--------|--------|-----------|-------------|
| sqlite | SQLite | 21        | SQLite CLI plus DB Browser for SQLite |
| duckdb | DuckDB | 28        | Analytical columnar file database |
| litedb | LiteDB | 29        | .NET embedded NoSQL file database |

## Database Install Section

The root dispatcher exposes database installs in two ways:

1. **Interactive DB section** via script **30**
   - `install databases`
   - `install db`
2. **Direct DB installs** via individual script keywords
   - `install mysql`
   - `install sqlite`
   - `install mongodb,redis`

This gives users both a guided DB menu and quick one-line installs.

## Install Path Options

When running interactively, the user is prompted to choose:

1. **Dev directory** (default) -- installs to `E:\dev\databases\<db>`
2. **Custom path** -- user enters any path, databases go into `<path>\databases\<db>`
3. **System default** -- installs to the default system location (e.g. `C:\Program Files`)

If the configured default drive is invalid or missing, the shared dev-dir helper
falls back to a safe local path such as `C:\dev`.

The dev directory path (`E:\dev`) is configurable in `config.json` under
`devDir.default` and `devDir.override`.

## config.json

| Key | Type | Purpose |
|-----|------|---------|
| `devDir.mode` | string | Resolution mode (json-or-prompt) |
| `devDir.default` | string | Default dev directory path |
| `devDir.override` | string | Hard override (skips prompt) |
| `installMode.default` | string | Default install mode (devDir/custom/system) |
| `databases.<key>.enabled` | bool | Toggle per database |
| `databases.<key>.scriptId` | string | Individual script ID |
| `databases.<key>.folder` | string | Individual script folder |
| `databases.<key>.name` | string | Display name |
| `databases.<key>.desc` | string | Short description |
| `databases.<key>.type` | string | Category (sql, nosql-document, etc.) |
| `groups[].letter` | string | Shortcut letter |
| `groups[].label` | string | Group display name |
| `groups[].ids` | array | Database keys in this group |
| `sequence` | array | Execution order |

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

## Loop-Back Flow

1. User selects databases and presses Enter
2. User chooses install path (dev dir / custom / system)
3. Selected databases install in sequence
4. Summary is displayed
5. Menu re-appears for more installations
6. Press Q to exit
