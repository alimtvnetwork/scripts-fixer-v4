# --------------------------------------------------------------------------
#  Script 03 -- Install Package Managers
#  Installs and updates Chocolatey and Winget package managers.
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

# Expose for helpers that reference $script:ScriptDir
$script:ScriptDir = $scriptDir

# -- Dot-source shared helpers ------------------------------------------------
. (Join-Path $sharedDir "logging.ps1")
. (Join-Path $sharedDir "resolved.ps1")
. (Join-Path $sharedDir "git-pull.ps1")
. (Join-Path $sharedDir "help.ps1")
. (Join-Path $sharedDir "choco-utils.ps1")

# -- Dot-source script helpers ------------------------------------------------
. (Join-Path $scriptDir "helpers\choco.ps1")
. (Join-Path $scriptDir "helpers\winget.ps1")

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
$isNotAdmin = -not $hasAdminRights
if ($isNotAdmin) {
    Write-Log $logMessages.messages.notAdmin -Level "error"
    Write-Host "  Tip: Right-click PowerShell -> 'Run as Administrator'" -ForegroundColor Yellow
    return
}

# -- Execute subcommand --------------------------------------------------------
$isAllSuccessful = $true

switch ($Command.ToLower()) {
    "choco" {
        Write-Log $logMessages.messages.commandChoco -Level "info"
        $ok = Install-Chocolatey -Config $config.chocolatey -LogMessages $logMessages
        $hasFailed = -not $ok
        if ($hasFailed) { $isAllSuccessful = $false }
    }
    "winget" {
        Write-Log $logMessages.messages.commandWinget -Level "info"
        $ok = Install-Winget -Config $config.winget -LogMessages $logMessages
        $hasFailed = -not $ok
        if ($hasFailed) { $isAllSuccessful = $false }
    }
    default {
        Write-Log $logMessages.messages.commandAll -Level "info"
        $ok = Install-Chocolatey -Config $config.chocolatey -LogMessages $logMessages
        $hasFailed = -not $ok
        if ($hasFailed) { $isAllSuccessful = $false }
        $ok = Install-Winget -Config $config.winget -LogMessages $logMessages
        $hasFailed = -not $ok
        if ($hasFailed) { $isAllSuccessful = $false }
    }
}

# -- Summary -------------------------------------------------------------------
if ($isAllSuccessful) {
    Write-Log $logMessages.messages.done -Level "success"
} else {
    Write-Log $logMessages.messages.completedWithWarnings -Level "warn"
}

Write-Log $logMessages.messages.setupComplete -Level "success"
