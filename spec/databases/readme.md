# Spec: Script 18 -- Install Databases

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
.\run.ps1 -Install mysql           # Install MySQL
.\run.ps1 -Install postgresql      # Install PostgreSQL
.\run.ps1 -Install mongodb,redis   # Install MongoDB + Redis
.\run.ps1 -Install databases       # Interactive database menu
```

## Supported Databases

### Relational (SQL)

| Key        | Name       | Choco Package | Description                          |
|------------|------------|---------------|--------------------------------------|
| mysql      | MySQL      | mysql         | Popular open-source RDBMS            |
| mariadb    | MariaDB    | mariadb       | MySQL-compatible fork                |
| postgresql | PostgreSQL | postgresql    | Advanced open-source RDBMS           |
| sqlite     | SQLite     | sqlite        | File-based embedded SQL database     |

### NoSQL -- Document

| Key     | Name    | Choco Package | Description                      |
|---------|---------|---------------|----------------------------------|
| mongodb | MongoDB | mongodb       | Document-oriented NoSQL database |
| couchdb | CouchDB | couchdb      | Apache document DB with REST API |

### NoSQL -- Key-Value

| Key   | Name  | Choco Package | Description                       |
|-------|-------|---------------|-----------------------------------|
| redis | Redis | redis-64      | In-memory key-value store / cache |

### NoSQL -- Column

| Key       | Name             | Choco Package | Description                      |
|-----------|------------------|---------------|----------------------------------|
| cassandra | Apache Cassandra | cassandra     | Wide-column distributed database |

### NoSQL -- Graph

| Key   | Name  | Choco Package    | Description                  |
|-------|-------|------------------|------------------------------|
| neo4j | Neo4j | neo4j-community  | Graph database               |

### Search Engine

| Key           | Name          | Choco Package   | Description                      |
|---------------|---------------|-----------------|----------------------------------|
| elasticsearch | Elasticsearch | elasticsearch   | Full-text search and analytics   |

### File-Based / Embedded

| Key    | Name   | Install Method | Description                         |
|--------|--------|----------------|-------------------------------------|
| sqlite | SQLite | Chocolatey     | File-based embedded SQL database    |
| duckdb | DuckDB | Chocolatey     | Analytical columnar file database   |
| litedb | LiteDB | dotnet tool    | .NET embedded NoSQL file database   |

## Install Path Options

When running interactively, the user is prompted to choose:

1. **Dev directory** (default) -- installs to `E:\dev\databases\<db>`
2. **Custom path** -- user enters any path, databases go into `<path>\databases\<db>`
3. **System default** -- installs to the default system location (e.g. `C:\Program Files`)

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
| `databases.<key>.chocoPackage` | string | Chocolatey package name |
| `databases.<key>.verifyCommand` | string | CLI command to verify install |
| `databases.<key>.name` | string | Display name |
| `databases.<key>.desc` | string | Short description |
| `databases.<key>.type` | string | Category (sql, nosql-document, etc.) |
| `groups[].letter` | string | Shortcut letter |
| `groups[].label` | string | Group display name |
| `groups[].ids` | array | Database keys in this group |
| `sequence` | array | Execution order |

## Interactive Menu

```
  Install Databases -- Interactive Menu
  ===========================================

    Relational (SQL)
    [ ] 1.  MySQL                   Popular open-source relational database
    [ ] 2.  MariaDB                 MySQL-compatible fork with extra features
    [ ] 3.  PostgreSQL              Advanced open-source relational database
    [ ] 4.  SQLite                  File-based embedded SQL database

    NoSQL -- Document
    [ ] 5.  MongoDB                 Document-oriented NoSQL database
    [ ] 6.  CouchDB                Apache document database with REST API

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
