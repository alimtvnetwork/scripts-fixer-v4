# --------------------------------------------------------------------------
#  Script 31 -- PowerShell Context Menu
#  Adds "Open PowerShell Here" (normal + admin) to the right-click menu.
# --------------------------------------------------------------------------
param(
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$sharedDir = Join-Path (Split-Path -Parent $scriptDir) "shared"

$script:ScriptDir = $scriptDir

# -- Dot-source shared helpers ------------------------------------------------
. (Join-Path $sharedDir "logging.ps1")
. (Join-Path $sharedDir "resolved.ps1")
. (Join-Path $sharedDir "git-pull.ps1")
. (Join-Path $sharedDir "help.ps1")

# -- Dot-source script helpers ------------------------------------------------
. (Join-Path $scriptDir "helpers\pwsh-menu.ps1")

# -- Load config & log messages -----------------------------------------------
$config      = Import-JsonConfig (Join-Path $scriptDir "config.json")
$logMessages = Import-JsonConfig (Join-Path $scriptDir "log-messages.json")

# -- Help ---------------------------------------------------------------------
if ($Help) {
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
    return
}

# -- Detect PowerShell exe -----------------------------------------------------
$pwshExe = Resolve-PwshPath `
    -PwshPaths       $config.pwshPaths `
    -VerifyCommand   $config.verifyCommand `
    -VersionFlag     $config.versionFlag `
    -FallbackToLegacy $config.fallbackToLegacy `
    -LogMessages     $logMessages

$isPwshMissing = -not $pwshExe
if ($isPwshMissing) {
    return
}

# -- Process modes (normal + admin) --------------------------------------------
$enabledModes    = $config.enabledModes
$isAllSuccessful = $true

foreach ($modeName in $enabledModes) {
    $mode = $config.modes.$modeName

    $isModeMissing = -not $mode
    if ($isModeMissing) {
        Write-Log "Unknown mode '$modeName' in enabledModes -- skipping" -Level "warn"
        $isAllSuccessful = $false
        continue
    }

    $result = Invoke-PwshMode `
        -Mode        $mode `
        -ModeName    $modeName `
        -PwshExe     $pwshExe `
        -LogMessages $logMessages

    $hasFailed = -not $result
    if ($hasFailed) { $isAllSuccessful = $false }
}

# -- Summary -------------------------------------------------------------------
if ($isAllSuccessful) {
    Write-Log $logMessages.messages.done -Level "success"
} else {
    Write-Log $logMessages.messages.completedWithWarnings -Level "warn"
}

# -- Save resolved state -------------------------------------------------------
Save-ResolvedData -ScriptFolder "31-pwsh-context-menu" -Data @{
    pwshExe   = $pwshExe
    modes     = ($enabledModes -join ',')
    timestamp = (Get-Date -Format "o")
}

Write-Log $logMessages.messages.setupComplete -Level "success"
