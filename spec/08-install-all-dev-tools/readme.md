# Spec: Script 08 -- Install All Dev Tools

## Purpose

Orchestrator that resolves the dev directory once, sets `$env:DEV_DIR`,
then runs scripts 03-10 in sequence. Supports `--skip` and `--only` filters.

## Usage

```powershell
.\run.ps1                    # Run all enabled scripts
.\run.ps1 -Skip "05,07"     # Skip Node.js and pnpm
.\run.ps1 -Only "03,04"     # Run only package managers + Go
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
| `sequence` | array | Execution order |

## Flow

1. Assert admin privileges
2. Resolve dev directory (env > config override > prompt > default)
3. Create dev directory structure
4. Set `$env:DEV_DIR` for child scripts
5. Build filtered script list (apply --skip / --only)
6. Run each script's `run.ps1` in sequence
7. Print summary table with status badges
8. Save resolved state

## Summary Output

```
--- Summary ---
  [OK]   03 - Package Managers
  [OK]   04 - Go
  [SKIP] 05 - Node.js
  [OK]   06 - Python
  [SKIP] 07 - pnpm
```
