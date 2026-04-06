# Changelog

All notable changes to this project are documented in this file.

---

## [v0.4.1] -- 2026-04-07

**Crash-safe error logging, VS Code/pwsh detection fallbacks, and full-path error diagnostics**

### Added

- `try/catch/finally` wrapper in all 31 `run.ps1` files -- `Save-LogFile` now always runs, even on unhandled exceptions
- Warnings (warn-level) now captured in error log files alongside errors, with separate `errors` and `warnings` arrays
- `warnCount` field added to error log JSON schema
- 4-tier VS Code exe fallback chain: config paths → Chocolatey shim/lib → `Get-Command` → `where.exe` (script 10)
- Chocolatey shim fallback for `pwsh.exe` detection (script 31)
- Detailed per-step failure logging for all fallback paths in scripts 10 and 31

### Changed

- `fileExistsAtPath` log message now includes the full file path being checked, not just True/False
- File-not-found checks in scripts 10 and 31 now log at error/warn level instead of info (captured in error logs)
- `Get-InstalledDir` function replaces `$script:_InstalledDir` variable for robust sourcing context
- `Save-InstalledRecord` accepts empty version strings gracefully (falls back to `'unknown'`)
- Error log creation trigger expanded: any warn OR fail event now generates an error log file

### Fixed

- `$script:_InstalledDir` variable not set error -- replaced with `Get-InstalledDir` function that works regardless of dot-sourcing context
- Empty version string error in `Save-InstalledRecord` when `choco list` returns no match
- Missing error log files when scripts crashed with unhandled exceptions before `Save-LogFile` could run
- VS Code exe not found after Chocolatey install because `config.json` only had user/system paths, not choco paths

### Docs

- Issue 4 added to `scripts/10-vscode-context-menu-fix/issues.md` documenting Chocolatey path detection root cause
- `spec/shared/logging.md` updated with warn-level capture, new error log schema, and crash-safe `try/catch/finally` pattern
- `spec/shared/installed.md` updated with `Get-InstalledDir`, empty version fallback, and Error Tracking section

---

## [v0.4.0] -- 2026-04-06

**Error tracking, registry API migration, database menu option, and spec updates**

### Added

- `Save-InstalledError` catch blocks in all 13 install helper scripts (vscode, choco, nodejs, pnpm, python, golang, git, github-desktop, mingw, winget, php, powershell, databases)
- All Databases Only option (`mode: alldb`) as option 3 in script 12 quick menu
- Error Tracking section in `spec/shared/installed.md` with field docs, JSON examples, and retry behaviour
- `Save-InstalledError` column in spec tracking table showing coverage across all scripts

### Changed

- Scripts 10 and 31 migrated from `reg.exe` to .NET `Microsoft.Win32.Registry` API to fix Invalid syntax errors with nested quotes
- Script 12 questionnaire reordered: Install All (1), Dev Tools Only (2), All Databases Only (3), Custom (4)

### Fixed

- Registry command failures in scripts 10 (VS Code context menu) and 31 (PowerShell context menu) caused by `cmd.exe /c` parsing of nested quotes in `pwsh.exe -Command` strings

### Docs

- Updated `spec/shared/installed.md` with error JSON schema fields (`lastError`, `errorAt`), recovery examples, and retry behaviour
- Updated `scripts/10-vscode-context-menu-fix/issues.md` with root cause analysis and .NET API migration notes

---

## [v0.3.0] -- 2026-04-05

**Database scripts, installation tracking, front-loaded questionnaire, shared helpers, and structured logging**

### Added

- Database installation scripts (18-29): MySQL, MariaDB, PostgreSQL, SQLite, MongoDB, CouchDB, Redis, Cassandra, Neo4j, Elasticsearch, DuckDB, LiteDB
- Database orchestrator (`scripts/databases/`) with interactive menu, `-All`, `-Only`, `-Skip`, `-DryRun` flags
- Generic `Install-Database` function in `scripts/databases/helpers/install-db.ps1` (choco and dotnet-tool methods)
- Installation tracking via `.installed/` folder with per-tool JSON files (name, version, method, timestamps, error fields)
- Shared `installed.ps1` with `Test-AlreadyInstalled`, `Save-InstalledRecord`, `Save-InstalledError`, `Get-InstalledRecord`
- Front-loaded questionnaire in script 12: dev dir, VS Code editions, sync mode, Git name/email asked upfront
- Quick menu in script 12: Install All Dev (1), All Dev + All DBs (2), Custom (3)
- `-D` / `-Defaults` flag for zero-prompt runs with default answers
- `.resolved/` folder pattern with `Save-ResolvedData` and `Get-ResolvedDir` shared helpers
- Structured JSON logging system: `Initialize-Logging`, `Write-Log` event collection, `Save-LogFile` to `.logs/`
- Error log auto-creation when fail-level events are recorded
- Shared helpers: `choco-utils.ps1`, `path-utils.ps1`, `dev-dir.ps1`
- Script 14 (winget): detection, install via MSIX, PATH refresh
- Script 15 (windows-tweaks): system tweaks with confirmation skip under orchestrator
- Script 16 (PHP): Chocolatey-based install with upgrade support
- Script 17 (PowerShell): pwsh install/upgrade via Chocolatey
- Script 31 (pwsh-context-menu): PowerShell Here context menu entries for folders, backgrounds, and admin mode
- Audit script (`scripts/audit/`): system checks and validation
- `install-keywords.json` mapping natural-language keywords to script IDs
- Interactive menu in script 12: lettered group shortcuts, CSV/space number input, loop-back after install

### Changed

- All install helpers now use `Test-AlreadyInstalled` to skip redundant installs when version matches
- `Write-Banner` auto-reads `scripts/version.json` for project version display
- Logging moved from `scripts/logs/` to `.logs/` at project root
- Version numbers in `Write-Log` output highlighted in Yellow
- Config files are declarative input only -- runtime state goes to `.resolved/`

### Docs

- `spec/shared/installed.md`: installation tracking specification
- `spec/shared/logging.md`: structured logging specification
- Spec docs for all new scripts (14-29, 31, audit, databases)
- Memory files for database-scripts, installed-tracking, interactive-menu, questionnaire, resolved-folder, shared-helpers, logging

---

## [v0.2.0] -- 2026-04-03

Initial tagged release (no changelog recorded).

---

## [v0.1.0] -- 2026-04-03

Initial tagged release (no changelog recorded).
