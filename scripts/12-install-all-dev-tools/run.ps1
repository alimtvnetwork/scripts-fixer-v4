# --------------------------------------------------------------------------
#  Script 12 -- Install All Dev Tools
#  Orchestrator: resolves dev directory, then runs scripts 01-11.
#  Supports interactive grouped menu, -All, -Skip, and -Only filters.
# --------------------------------------------------------------------------
param(
    [string]$Skip,
    [string]$Only,
    [switch]$All,
    [switch]$DryRun,
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$scriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Definition
$sharedDir  = Join-Path (Split-Path -Parent $scriptDir) "shared"
$scriptsRoot = Split-Path -Parent $scriptDir

# -- Dot-source shared helpers ------------------------------------------------
. (Join-Path $sharedDir "logging.ps1")
. (Join-Path $sharedDir "resolved.ps1")
. (Join-Path $sharedDir "git-pull.ps1")
. (Join-Path $sharedDir "help.ps1")
. (Join-Path $sharedDir "dev-dir.ps1")

# -- Dot-source script helpers ------------------------------------------------
. (Join-Path $scriptDir "helpers\orchestrator.ps1")

# -- Load config & log messages -----------------------------------------------
$config       = Import-JsonConfig (Join-Path $scriptDir "config.json")
$logMessages  = Import-JsonConfig (Join-Path $scriptDir "log-messages.json")

# -- Help ---------------------------------------------------------------------
if ($Help) {
    Show-ScriptHelp -LogMessages $logMessages
    return
}

# -- Banner --------------------------------------------------------------------
Write-Banner -Title $logMessages.scriptName -Version $logMessages.version

# -- Git pull ------------------------------------------------------------------
Invoke-GitPull

# -- Assert admin --------------------------------------------------------------
$hasAdminRights = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$isNotAdmin = -not $hasAdminRights
if ($isNotAdmin) {
    Write-Log $logMessages.messages.notAdmin -Level "error"
    return
}

# -- Resolve dev directory -----------------------------------------------------
Write-Log $logMessages.messages.resolvingDevDir -Level "info"
$devDir = Resolve-DevDir -Config $config.devDir
Initialize-DevDir -Path $devDir

# Set env var for child scripts
$env:DEV_DIR = $devDir
Write-Log ($logMessages.messages.devDirResolved -replace '\{path\}', $devDir) -Level "success"

# -- Build script list ---------------------------------------------------------
$hasFilter = $Skip -or $Only
if ($hasFilter -or $All -or $DryRun) {
    # Flag-based mode: skip interactive menu
    $scriptList = Resolve-ScriptList -Config $config -Skip $Skip -Only $Only
} else {
    # Interactive menu mode with groups
    $scriptList = Resolve-ScriptList -Config $config -Skip "" -Only ""
    $groups = if ($config.groups) { $config.groups } else { $null }
    $scriptList = Show-InteractiveMenu -ScriptList $scriptList -LogMessages $logMessages -Groups $groups
    $hasNoSelection = -not $scriptList -or $scriptList.Count -eq 0
    if ($hasNoSelection) {
        Write-Log $logMessages.messages.menuNoneSelected -Level "warn"
        return
    }
    Write-Log ($logMessages.messages.menuRunning -replace '\{count\}', $scriptList.Count) -Level "info"
}

# -- Dry run -------------------------------------------------------------------
if ($DryRun) {
    Show-DryRun -ScriptList $scriptList -LogMessages $logMessages
    return
}

# -- Run scripts in sequence ---------------------------------------------------
$results = Invoke-ScriptSequence -ScriptList $scriptList -ScriptsRoot $scriptsRoot -LogMessages $logMessages -Skip $Skip

# -- Summary -------------------------------------------------------------------
Show-Summary -Results $results -LogMessages $logMessages
Write-Log $logMessages.messages.allComplete -Level "success"

# -- Save resolved state -------------------------------------------------------
Save-ResolvedData -ScriptFolder "12-install-all-dev-tools" -Data @{
    devDir    = $devDir
    results   = $results
    timestamp = (Get-Date -Format "o")
}
