# --------------------------------------------------------------------------
#  Script 08 -- Install All Dev Tools
#  Orchestrator: resolves dev directory, then runs scripts 03-10 in sequence.
# --------------------------------------------------------------------------
param(
    [string]$Skip,
    [string]$Only,
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
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Log $logMessages.messages.adminRequired -Level "error"
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
$scriptList = Resolve-ScriptList -Config $config -Skip $Skip -Only $Only

# -- Run scripts in sequence ---------------------------------------------------
$results = Invoke-ScriptSequence -ScriptList $scriptList -ScriptsRoot $scriptsRoot -LogMessages $logMessages -Skip $Skip

# -- Summary -------------------------------------------------------------------
Show-Summary -Results $results -LogMessages $logMessages
Write-Log $logMessages.messages.allComplete -Level "success"

# -- Save resolved state -------------------------------------------------------
Save-ResolvedData -ScriptFolder "08-install-all-dev-tools" -Data @{
    devDir    = $devDir
    results   = $results
    timestamp = (Get-Date -Format "o")
}
