<#
.SYNOPSIS
    Loads shared logging helpers from scripts/shared/logging.ps1.
#>

$sharedLogging = Join-Path $PSScriptRoot "..\..\shared\logging.ps1"
if (Test-Path $sharedLogging) {
    . $sharedLogging
} else {
    Write-Host "  [ FAIL ] Shared logging helper not found: $sharedLogging" -ForegroundColor Red
    exit 1
}
