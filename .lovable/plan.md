
## Phase 1: Shared Infrastructure
- Create `scripts/shared/path-utils.ps1` (Add-ToUserPath, Add-ToMachinePath, Test-InPath)
- Create `scripts/shared/choco-utils.ps1` (Assert-Choco, Install-ChocoPackage, Upgrade-ChocoPackage)
- Create `scripts/shared/dev-dir.ps1` (Resolve-DevDir, Initialize-DevDir)
- Add `--help` support to existing scripts 01 and 02
- Update `spec/shared/readme.md` with new helpers
- Update memory with new shared helpers

## Phase 2: Script 03 (install-package-managers)
- Create folder structure, config.json, log-messages.json
- Create `helpers/choco.ps1` and `helpers/winget.ps1`
- Create `run.ps1` with subcommands (choco, winget, all, --help)
- Create `spec/03-install-package-managers/readme.md`

## Phase 3: Script 04 (install-golang)
- Copy user's uploaded files as reference
- Create folder structure, config.json (adapted from go-config.sample.json), log-messages.json
- Create `helpers/golang.ps1` (Resolve-Gopath, Set-GoEnv, Install/Upgrade logic)
- Create `run.ps1` with subcommands (install, configure, --help)
- Create spec

## Phase 4: Script 05 (install-nodejs)
- Create folder structure, config.json, log-messages.json
- Create `helpers/nodejs.ps1` (install via Choco, npm prefix config)
- Create `run.ps1` with subcommands
- Create spec

## Phase 5: Script 06 (install-python) + Script 07 (install-pnpm)
- Create both scripts (same pattern as 04/05)
- Python: Choco install + pip user site config
- pnpm: npm install + store-dir config + PATH
- Create specs for both

## Phase 6: Script 08 (install-all-dev-tools) + README
- Create orchestrator script with --skip, --only, --help
- Dev directory prompt/resolution
- Runs 03-07 in sequence, passes $env:DEV_DIR
- Update root `readme.md` with full project documentation
- Final memory updates
