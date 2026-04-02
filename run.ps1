<#
.SYNOPSIS
    Root-level script dispatcher. Runs a numbered script after pulling latest changes.

.DESCRIPTION
    Performs a git pull, then delegates to the script in scripts/<NN>-*/run.ps1
    based on the -I parameter.

.PARAMETER I
    The script number to run (e.g. 1, 2, 3). Maps to folders like 01-*, 02-*, etc.

.EXAMPLE
    .\run.ps1 -I 1    # git pull, then run scripts/01-*/run.ps1
    .\run.ps1 -I 2    # git pull, then run scripts/02-*/run.ps1

.NOTES
    Author : Lovable AI
    Version: 1.0.0
#>

param(
    [Parameter(Mandatory = $true)]
    [int]$I,

    [switch]$Merge
)

$ErrorActionPreference = "Stop"
$RootDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# ── Git Pull ─────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  [  GIT  ] " -ForegroundColor Cyan -NoNewline
Write-Host "Pulling latest changes..."

try {
    Push-Location $RootDir
    $gitOutput = git pull 2>&1
    Pop-Location
    Write-Host "  [  OK   ] " -ForegroundColor Green -NoNewline
    Write-Host $gitOutput
} catch {
    Pop-Location
    Write-Host "  [ WARN  ] " -ForegroundColor Yellow -NoNewline
    Write-Host "git pull failed: $_  (continuing anyway)"
}

# ── Resolve Script ───────────────────────────────────────────────────
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

# ── Delegate ─────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  [ RUN   ] " -ForegroundColor Magenta -NoNewline
Write-Host "Executing: $($scriptDir.Name)\run.ps1"
Write-Host ""

$scriptArgs = @{}
if ($Merge) { $scriptArgs["Merge"] = $true }

& $scriptFile @scriptArgs
