<#
.SYNOPSIS
    Root-level script dispatcher. Runs a numbered script after pulling latest changes.

.DESCRIPTION
    Performs a git pull via the shared helper, sets $env:SCRIPTS_ROOT_RUN = "1"
    so child scripts skip their own git pull, then delegates to
    scripts/<NN>-*/run.ps1 based on the -I parameter.

    When run with no parameters, performs a git pull and shows help.
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
    .\run.ps1                  # git pull, show help
    .\run.ps1 -d               # shortcut for -I 12 (interactive dev tools menu)
    .\run.ps1 -I 1            # git pull, then run scripts/01-*/run.ps1
    .\run.ps1 -I 2 -Merge     # git pull, then run scripts/02-*/run.ps1 with merge
    .\run.ps1 -I 12           # same as -d
    .\run.ps1 -I 1 -Clean     # wipe .resolved/, then run scripts/01-*/run.ps1
    .\run.ps1 -CleanOnly       # wipe .resolved/ and exit
    .\run.ps1 -Help            # show all available scripts

.NOTES
    Author : Lovable AI
    Version: 5.0.0
#>

param(
    [int]$I,

    [switch]$d,

    [switch]$a,

    [switch]$v,

    [switch]$Merge,

    [switch]$Clean,

    [switch]$CleanOnly,

    [switch]$Help
)

$ErrorActionPreference = "Stop"
$RootDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# ── Help function ────────────────────────────────────────────────────
function Show-RootHelp {
    Write-Host ""
    Write-Host "  Dev Tools Setup Scripts" -ForegroundColor Cyan
    Write-Host "  =======================" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Usage:" -ForegroundColor Yellow
    Write-Host "    .\run.ps1                           Show this help (after git pull)"
    Write-Host "    .\run.ps1 -d                         Shortcut for -I 12 (interactive menu)"
    Write-Host "    .\run.ps1 -a                         Shortcut for -I 13 (audit mode)"
    Write-Host "    .\run.ps1 -v                         Shortcut for -I 1  (install VS Code)"
    Write-Host "    .\run.ps1 -I <number>               Run a specific script"
    Write-Host "    .\run.ps1 -I <number> -Merge        Run with merge flag (script 02)"
    Write-Host "    .\run.ps1 -I <number> -Clean        Wipe cache, then run"
    Write-Host "    .\run.ps1 -CleanOnly                 Wipe all cached data"
    Write-Host "    .\run.ps1 -Help                      Show this help"
    Write-Host ""
    Write-Host "  Available Scripts:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "    ID  Name                          Description" -ForegroundColor DarkGray
    Write-Host "    --  ----------------------------  ------------------------------------------------" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "    Core Tools" -ForegroundColor Magenta
    Write-Host "    01  Install VS Code               " -NoNewline; Write-Host "Install Visual Studio Code (Stable/Insiders)" -ForegroundColor DarkGray
    Write-Host "    02  Package Managers              " -NoNewline; Write-Host "Install Chocolatey and Winget" -ForegroundColor DarkGray
    Write-Host "    03  Node.js + Yarn + Bun          " -NoNewline; Write-Host "Install Node.js LTS, Yarn, Bun, verify npx" -ForegroundColor DarkGray
    Write-Host "    04  pnpm                          " -NoNewline; Write-Host "Install pnpm, configure global store" -ForegroundColor DarkGray
    Write-Host "    05  Python                        " -NoNewline; Write-Host "Install Python, configure pip user site" -ForegroundColor DarkGray
    Write-Host "    06  Golang                        " -NoNewline; Write-Host "Install Go, configure GOPATH and go env" -ForegroundColor DarkGray
    Write-Host "    07  Git + LFS + gh                " -NoNewline; Write-Host "Install Git, Git LFS, GitHub CLI, configure settings" -ForegroundColor DarkGray
    Write-Host "    08  GitHub Desktop                " -NoNewline; Write-Host "Install GitHub Desktop via Chocolatey" -ForegroundColor DarkGray
    Write-Host "    09  C++ (MinGW-w64)               " -NoNewline; Write-Host "Install MinGW-w64 C++ compiler, verify g++/gcc/make" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "    Optional" -ForegroundColor Magenta
    Write-Host "    10  VSCode Context Menu Fix       " -NoNewline; Write-Host "Add/repair VSCode right-click context menu entries" -ForegroundColor DarkGray
    Write-Host "    11  VSCode Settings Sync          " -NoNewline; Write-Host "Sync VSCode settings, keybindings, and extensions" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "    Orchestrator" -ForegroundColor Magenta
    Write-Host "    12  Install All Dev Tools         " -NoNewline; Write-Host "Interactive grouped menu: pick tools or install everything" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "    Utilities" -ForegroundColor Magenta
    Write-Host "    13  Audit Mode                    " -NoNewline; Write-Host "Scan configs, specs, suggestions for stale IDs" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Script 12 (Install All Dev Tools):" -ForegroundColor Yellow
    Write-Host "    .\run.ps1 -I 12                         " -NoNewline; Write-Host "Interactive menu -- pick what to install" -ForegroundColor DarkGray
    Write-Host "    .\run.ps1 -I 12 -- -All                 " -NoNewline; Write-Host "Install everything without prompting" -ForegroundColor DarkGray
    Write-Host "    .\run.ps1 -I 12 -- -Skip 04,06          " -NoNewline; Write-Host "Skip pnpm and Go" -ForegroundColor DarkGray
    Write-Host "    .\run.ps1 -I 12 -- -Only 02,03          " -NoNewline; Write-Host "Run only Package Managers + Node.js" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Per-script help:" -ForegroundColor Yellow
    Write-Host "    .\run.ps1 -I <number> -- -Help          " -NoNewline; Write-Host "Show help for a specific script" -ForegroundColor DarkGray
    Write-Host ""
}

# ── No params = git pull + help ──────────────────────────────────────
$hasNoParams = -not $I -and -not $d -and -not $a -and -not $v -and -not $Help -and -not $CleanOnly -and -not $Clean
if ($hasNoParams) {
    # Load git pull helper and pull before showing help
    Remove-Item Env:\SCRIPTS_ROOT_RUN -ErrorAction SilentlyContinue
    $sharedGitPull = Join-Path $RootDir "scripts\shared\git-pull.ps1"
    $isHelperAvailable = Test-Path $sharedGitPull
    if ($isHelperAvailable) {
        . $sharedGitPull
        Invoke-GitPull -RepoRoot $RootDir
    }
    Show-RootHelp
    exit 0
}

# ── Help ─────────────────────────────────────────────────────────────
if ($Help) {
    Show-RootHelp
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

# ── Expand shortcuts ──────────────────────────────────────────────────
if ($d) { $I = 12 }
if ($a) { $I = 13 }
if ($v) { $I = 1 }

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

# ── Resolve Script from registry (exact folder match) ────────────────
$prefix = "{0:D2}" -f $I
$registryPath = Join-Path $RootDir "scripts\registry.json"
$isRegistryAvailable = Test-Path $registryPath

if ($isRegistryAvailable) {
    $registry = Get-Content $registryPath -Raw | ConvertFrom-Json
    $folderName = $registry.scripts.$prefix

    $isRegistered = [bool]$folderName
    if ($isRegistered) {
        $scriptDir = Get-Item (Join-Path $RootDir "scripts\$folderName") -ErrorAction SilentlyContinue
    }
} else {
    # Fallback: glob match (for repos without registry.json)
    $pattern = Join-Path $RootDir "scripts/$prefix-*"
    $scriptDir = @(Get-Item $pattern -ErrorAction SilentlyContinue |
        Where-Object { $_.PSIsContainer -and (Test-Path (Join-Path $_.FullName "run.ps1")) }) |
        Select-Object -First 1
}

$isScriptMissing = -not $scriptDir -or -not (Test-Path $scriptDir.FullName)
if ($isScriptMissing) {
    Write-Host ""
    Write-Host "  [ FAIL  ] " -ForegroundColor Red -NoNewline
    Write-Host "No script folder found for ID $prefix"
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
