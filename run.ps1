<#
.SYNOPSIS
    Root-level script dispatcher. Runs a numbered script after pulling latest changes.

.DESCRIPTION
    Performs a git pull via the shared helper, sets $env:SCRIPTS_ROOT_RUN = "1"
    so child scripts skip their own git pull, then delegates to
    scripts/<NN>-*/run.ps1 based on the -I parameter.

    Use -Clean to wipe all .resolved/ data before running, forcing fresh detection.
    Use -CleanOnly to wipe .resolved/ without running any script.
    Use -Help to see all available scripts and usage information.

.PARAMETER I
    The script number to run (e.g. 1, 2, 3). Maps to folders like 01-*, 02-*, etc.

.PARAMETER Clean
    Wipe all .resolved/ data before running the script.

.PARAMETER CleanOnly
    Wipe all .resolved/ data and exit without running any script.

.PARAMETER Help
    Show usage information and list all available scripts.

.EXAMPLE
    .\run.ps1 -I 1            # git pull, then run scripts/01-*/run.ps1
    .\run.ps1 -I 2 -Merge     # git pull, then run scripts/02-*/run.ps1 with merge
    .\run.ps1 -I 1 -Clean     # wipe .resolved/, then run scripts/01-*/run.ps1
    .\run.ps1 -CleanOnly       # wipe .resolved/ and exit
    .\run.ps1 -Help            # show all available scripts

.NOTES
    Author : Lovable AI
    Version: 4.0.0
#>

param(
    [int]$I,

    [switch]$Merge,

    [switch]$Clean,

    [switch]$CleanOnly,

    [switch]$Help
)

$ErrorActionPreference = "Stop"
$RootDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# ── Help ─────────────────────────────────────────────────────────────
if ($Help) {
    Write-Host ""
    Write-Host "  Dev Tools Setup Scripts" -ForegroundColor Cyan
    Write-Host "  =======================" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Usage:" -ForegroundColor Yellow
    Write-Host "    .\run.ps1 -I <number>          Run a specific script"
    Write-Host "    .\run.ps1 -I <number> -Merge   Run with merge flag"
    Write-Host "    .\run.ps1 -I <number> -Clean   Wipe cache, then run"
    Write-Host "    .\run.ps1 -CleanOnly            Wipe all cached data"
    Write-Host "    .\run.ps1 -Help                 Show this help"
    Write-Host ""
    Write-Host "  Available Scripts:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "    01  VSCode Context Menu Fix     " -NoNewline; Write-Host "Add/repair VSCode right-click context menu entries" -ForegroundColor DarkGray
    Write-Host "    02  VSCode Settings Sync        " -NoNewline; Write-Host "Sync VSCode settings, keybindings, and extensions" -ForegroundColor DarkGray
    Write-Host "    03  Package Managers             " -NoNewline; Write-Host "Install Chocolatey and Winget" -ForegroundColor DarkGray
    Write-Host "    04  Install All Dev Tools        " -NoNewline; Write-Host "Orchestrator: runs scripts 03, 05-10 in sequence" -ForegroundColor DarkGray
    Write-Host "    05  Install Golang               " -NoNewline; Write-Host "Install Go, configure GOPATH and go env" -ForegroundColor DarkGray
    Write-Host "    06  Install Node.js              " -NoNewline; Write-Host "Install Node.js LTS, configure npm prefix" -ForegroundColor DarkGray
    Write-Host "    07  Install Python               " -NoNewline; Write-Host "Install Python, configure pip user site" -ForegroundColor DarkGray
    Write-Host "    08  Install pnpm                 " -NoNewline; Write-Host "Install pnpm, configure global store" -ForegroundColor DarkGray
    Write-Host "    09  Install Git + LFS + gh       " -NoNewline; Write-Host "Install Git, Git LFS, GitHub CLI, configure settings" -ForegroundColor DarkGray
    Write-Host "    10  Install GitHub Desktop       " -NoNewline; Write-Host "Install GitHub Desktop via Chocolatey" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Script 04 (Install All) Options:" -ForegroundColor Yellow
    Write-Host "    .\run.ps1 -I 4                          Run all enabled scripts"
    Write-Host "    .\run.ps1 -I 4 -- --skip 06,08          Skip Node.js and pnpm"
    Write-Host "    .\run.ps1 -I 4 -- --only 03,05          Run only Package Managers + Go"
    Write-Host ""
    Write-Host "  Each script also supports -Help for its own usage:" -ForegroundColor Yellow
    Write-Host "    .\run.ps1 -I 5 -- -Help                 Show Go install help"
    Write-Host ""
    exit 0
}

# ── Handle -CleanOnly (no -I required) ───────────────────────────────
if ($CleanOnly) {
    $resolvedDir = Join-Path $RootDir ".resolved"
    if (Test-Path $resolvedDir) {
        Get-ChildItem -Path $resolvedDir -Recurse -Force | Remove-Item -Recurse -Force
        Write-Host "  [ CLEAN ] " -ForegroundColor Green -NoNewline
        Write-Host "All .resolved/ data wiped"
    } else {
        Write-Host "  [ SKIP  ] " -ForegroundColor DarkGray -NoNewline
        Write-Host "Nothing to clean -- .resolved/ does not exist"
    }
    exit 0
}

# ── Validate -I is provided ──────────────────────────────────────────
$isMissingParam = -not $I
if ($isMissingParam) {
    Write-Host "  [ FAIL  ] " -ForegroundColor Red -NoNewline
    Write-Host "Missing -I parameter. Usage: .\run.ps1 -I <number>"
    Write-Host ""
    Write-Host "  Run .\run.ps1 -Help to see all available scripts" -ForegroundColor Cyan
    exit 1
}

# ── Handle -Clean ────────────────────────────────────────────────────
if ($Clean) {
    $resolvedDir = Join-Path $RootDir ".resolved"
    if (Test-Path $resolvedDir) {
        Get-ChildItem -Path $resolvedDir -Recurse -Force | Remove-Item -Recurse -Force
        Write-Host "  [ CLEAN ] " -ForegroundColor Green -NoNewline
        Write-Host "All .resolved/ data wiped -- fresh detection will run"
    } else {
        Write-Host "  [ SKIP  ] " -ForegroundColor DarkGray -NoNewline
        Write-Host "Nothing to clean -- .resolved/ does not exist"
    }
    Write-Host ""
}

# ── Load shared helper ───────────────────────────────────────────────
$sharedGitPull = Join-Path $RootDir "scripts\shared\git-pull.ps1"
$isHelperMissing = -not (Test-Path $sharedGitPull)
if ($isHelperMissing) {
    Write-Host "  [ FAIL  ] " -ForegroundColor Red -NoNewline
    Write-Host "Shared helper not found: $sharedGitPull"
    exit 1
}
. $sharedGitPull

# ── Resolve Script (early, so we can clean logs before git output) ───
$prefix = "{0:D2}" -f $I
$pattern = Join-Path $RootDir "scripts/$prefix-*"
$scriptDir = Get-Item $pattern -ErrorAction SilentlyContinue | Select-Object -First 1

$isScriptMissing = -not $scriptDir
if ($isScriptMissing) {
    Write-Host ""
    Write-Host "  [ FAIL  ] " -ForegroundColor Red -NoNewline
    Write-Host "No script folder found matching: scripts/$prefix-*"
    Write-Host "  Run .\run.ps1 -Help to see all available scripts" -ForegroundColor Cyan
    exit 1
}

$scriptFile = Join-Path $scriptDir.FullName "run.ps1"

$isRunFileMissing = -not (Test-Path $scriptFile)
if ($isRunFileMissing) {
    Write-Host ""
    Write-Host "  [ FAIL  ] " -ForegroundColor Red -NoNewline
    Write-Host "run.ps1 not found in $($scriptDir.Name)"
    exit 1
}

# ── Clean & create logs folder ───────────────────────────────────────
$logsDir = Join-Path $scriptDir.FullName "logs"
if (Test-Path $logsDir) {
    Remove-Item -Path $logsDir -Recurse -Force -ErrorAction SilentlyContinue
}
New-Item -Path $logsDir -ItemType Directory -Force | Out-Null
Write-Host "  [ CLEAN ] " -ForegroundColor DarkGray -NoNewline
Write-Host "Cleaned logs/ in $($scriptDir.Name)"

# ── Git Pull ─────────────────────────────────────────────────────────
Invoke-GitPull -RepoRoot $RootDir

# ── Set flag so child scripts skip git pull ──────────────────────────
$env:SCRIPTS_ROOT_RUN = "1"

# ── Delegate ─────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  [ RUN   ] " -ForegroundColor Magenta -NoNewline
Write-Host "Executing: $($scriptDir.Name)\run.ps1"
Write-Host ""

$scriptArgs = @{}
if ($Merge) { $scriptArgs["Merge"] = $true }

& $scriptFile @scriptArgs

# ── Clean up env flag ────────────────────────────────────────────────
Remove-Item Env:\SCRIPTS_ROOT_RUN -ErrorAction SilentlyContinue
