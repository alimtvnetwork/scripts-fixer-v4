<#
.SYNOPSIS
    Root-level script dispatcher. Runs a numbered script after pulling latest changes.

.DESCRIPTION
    Performs a git pull via the shared helper, sets $env:SCRIPTS_ROOT_RUN = "1"
    so child scripts skip their own git pull, then delegates to
    scripts/<NN>-*/run.ps1 based on the -I parameter.

.PARAMETER I
    The script number to run (e.g. 1, 2, 3). Maps to folders like 01-*, 02-*, etc.

.EXAMPLE
    .\run.ps1 -I 1    # git pull, then run scripts/01-*/run.ps1
    .\run.ps1 -I 2    # git pull, then run scripts/02-*/run.ps1

.NOTES
    Author : Lovable AI
    Version: 2.0.0
#>

param(
    [Parameter(Mandatory = $true)]
    [int]$I,

    [switch]$Merge
)

$ErrorActionPreference = "Stop"
$RootDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# ── Load shared helper ───────────────────────────────────────────────
$sharedGitPull = Join-Path $RootDir "scripts\shared\git-pull.ps1"
if (-not (Test-Path $sharedGitPull)) {
    Write-Host "  [ FAIL  ] " -ForegroundColor Red -NoNewline
    Write-Host "Shared helper not found: $sharedGitPull"
    exit 1
}
. $sharedGitPull

# ── Resolve Script (early, so we can clean logs before git output) ───
$prefix = "{0:D2}" -f $I
$pattern = Join-Path $RootDir "scripts/$prefix-*"
$scriptDir = Get-Item $pattern -ErrorAction SilentlyContinue | Select-Object -First 1

if (-not $scriptDir) {
    Write-Host ""
    Write-Host "  [ FAIL  ] " -ForegroundColor Red -NoNewline
    Write-Host "No script folder found matching: scripts/$prefix-*"
    exit 1
}

$scriptFile = Join-Path $scriptDir.FullName "run.ps1"

if (-not (Test-Path $scriptFile)) {
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
