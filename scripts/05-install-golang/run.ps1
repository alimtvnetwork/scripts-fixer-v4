# --------------------------------------------------------------------------
#  Script 04 -- Install Golang
#  Installs Go via Chocolatey, configures GOPATH, PATH, and go env settings.
# --------------------------------------------------------------------------
param(
    [Parameter(Position = 0)]
    [string]$Command = "all",

    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$sharedDir = Join-Path (Split-Path -Parent $scriptDir) "shared"

# -- Dot-source shared helpers ------------------------------------------------
. (Join-Path $sharedDir "logging.ps1")
. (Join-Path $sharedDir "resolved.ps1")
. (Join-Path $sharedDir "git-pull.ps1")
. (Join-Path $sharedDir "help.ps1")
. (Join-Path $sharedDir "choco-utils.ps1")
. (Join-Path $sharedDir "path-utils.ps1")
. (Join-Path $sharedDir "dev-dir.ps1")

# -- Dot-source script helpers ------------------------------------------------
. (Join-Path $scriptDir "helpers\golang.ps1")

# -- Load config & log messages -----------------------------------------------
$config      = Import-JsonConfig (Join-Path $scriptDir "config.json")
$logMessages = Import-JsonConfig (Join-Path $scriptDir "log-messages.json")

# -- Help ---------------------------------------------------------------------
if ($Help -or $Command -eq "--help") {
    Show-ScriptHelp -LogMessages $logMessages
    return
}

# -- Banner --------------------------------------------------------------------
Write-Banner -Title $logMessages.scriptName -Version $logMessages.version

# -- Git pull ------------------------------------------------------------------
Invoke-GitPull

# -- Disabled check ------------------------------------------------------------
$isDisabled = -not $config.enabled
if ($isDisabled) {
    Write-Log $logMessages.messages.scriptDisabled -Level "warn"
    return
}

# -- Assert admin --------------------------------------------------------------
$hasAdminRights = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $hasAdminRights) {
    Write-Log $logMessages.messages.notAdmin -Level "error"
    Write-Host "  Tip: Right-click PowerShell -> 'Run as Administrator'" -ForegroundColor Yellow
    return
}

# -- Assert Chocolatey (skip for configure-only) -------------------------------
$isConfigureOnly = $Command.ToLower() -eq "configure"
if (-not $isConfigureOnly) {
    Assert-Choco
}

# -- Execute subcommand --------------------------------------------------------
Write-Log "Command: $Command" -Level "info"
$isSuccess = Invoke-GoSetup -Config $config -ScriptDir $scriptDir -Command $Command.ToLower()

# -- Summary -------------------------------------------------------------------
if ($isSuccess) {
    Write-Log $logMessages.messages.done -Level "success"
} else {
    Write-Log "Completed with some warnings -- check output above." -Level "warn"
}

Write-Log "Go setup complete." -Level "success"
