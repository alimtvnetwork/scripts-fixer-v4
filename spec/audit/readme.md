# Spec: Audit Mode

## Overview

A dedicated audit script that scans the entire project for stale IDs,
mismatched folder names, missing cross-references, and renumbering
inconsistencies. Designed to run after any renumbering or restructuring.

## Checks Performed

| # | Check | Description |
|---|-------|-------------|
| 1 | **Registry vs folders** | Every ID in `scripts/registry.json` must map to an existing folder under `scripts/`. Every numbered folder must appear in the registry. |
| 2 | **Orchestrator config vs registry** | Every ID in `scripts/12-install-all-dev-tools/config.json` `sequence` and `scripts` must exist in the registry. |
| 3 | **Orchestrator groups vs scripts** | Every ID referenced in `config.json` `groups[].ids` must exist in the `scripts` block. |
| 4 | **Spec folder coverage** | Every numbered script folder must have a matching `spec/<folder>/readme.md`. |
| 5 | **Config + log-messages existence** | Every script folder must contain `config.json` and `log-messages.json`. |
| 6 | **Stale ID references in specs** | Scan `spec/**/*.md` for patterns like `Script NN` or `scripts/NN-` that reference non-existent IDs. |
| 7 | **Stale ID references in suggestions** | Scan `suggestions/**/*.md` for the same stale-reference patterns. |
| 8 | **Stale ID references in PowerShell** | Scan `scripts/**/*.ps1` for hardcoded folder references like `01-install-vscode` and verify they match registry entries. |

## Usage

```powershell
.\run.ps1 -I 13                   # Run full audit
.\run.ps1 -I 13 -- -Help          # Show help
```

## Output

- Each check prints PASS or FAIL with details
- Exit summary shows total pass/fail counts
- Non-zero exit code if any check fails