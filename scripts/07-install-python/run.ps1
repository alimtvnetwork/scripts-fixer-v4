# --------------------------------------------------------------------------
#  Script 07 -- Install Python
#  Installs Python via Chocolatey and configures pip user site.
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
. (Join-Path $scriptDir "helpers\python.ps1")

# -- Load config & log messages -----------------------------------------------
$config       = Import-JsonConfig (Join-Path $scriptDir "config.json")
$logMessages  = Import-JsonConfig (Join-Path $scriptDir "log-messages.json")

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
    return
}

# -- Assert Chocolatey ---------------------------------------------------------
Assert-Choco

# -- Resolve dev directory -----------------------------------------------------
$devDir = if ($env:DEV_DIR) { $env:DEV_DIR } else { $null }

# -- Execute subcommand --------------------------------------------------------
switch ($Command.ToLower()) {
    "all" {
        Install-Python -Config $config -LogMessages $logMessages
        $sitePath = Configure-PipSite -Config $config -LogMessages $logMessages -DevDir $devDir
        Update-PythonPath -Config $config -LogMessages $logMessages -SitePath $sitePath
    }
    "install" {
        Install-Python -Config $config -LogMessages $logMessages
    }
    "configure" {
        $sitePath = Configure-PipSite -Config $config -LogMessages $logMessages -DevDir $devDir
        Update-PythonPath -Config $config -LogMessages $logMessages -SitePath $sitePath
    }
    default {
        Write-Log "Unknown command: $Command. Use -Help for usage." -Level "error"
        return
    }
}

# -- Save resolved state -------------------------------------------------------
Write-Log $logMessages.messages.savingResolved -Level "info"
$pythonVersion = & python --version 2>$null
$pipVersion    = & pip --version 2>$null

Save-ResolvedData -ScriptFolder "07-install-python" -Data @{
    pythonVersion  = $pythonVersion
    pipVersion     = $pipVersion
    pythonUserBase = $env:PYTHONUSERBASE
    timestamp      = (Get-Date -Format "o")
}

Write-Log "Python setup complete." -Level "success"
