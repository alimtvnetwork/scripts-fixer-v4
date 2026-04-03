# --------------------------------------------------------------------------
#  Script 09 -- Install Git
#  Installs Git via Chocolatey and configures global settings.
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

# -- Dot-source script helpers ------------------------------------------------
. (Join-Path $scriptDir "helpers\git.ps1")

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
if (-not $config.enabled) {
    Write-Log $logMessages.messages.scriptDisabled -Level "warn"
    return
}

# -- Assert admin --------------------------------------------------------------
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Log "This script requires administrator privileges." -Level "error"
    return
}

# -- Assert Chocolatey ---------------------------------------------------------
Assert-Choco

# -- Execute subcommand --------------------------------------------------------
switch ($Command.ToLower()) {
    "all" {
        Install-Git -Config $config -LogMessages $logMessages
        Configure-GitGlobal -Config $config -LogMessages $logMessages
        Update-GitPath -Config $config -LogMessages $logMessages
    }
    "install" {
        Install-Git -Config $config -LogMessages $logMessages
    }
    "configure" {
        Configure-GitGlobal -Config $config -LogMessages $logMessages
        Update-GitPath -Config $config -LogMessages $logMessages
    }
    default {
        Write-Log "Unknown command: $Command. Use -Help for usage." -Level "error"
        return
    }
}

# -- Save resolved state -------------------------------------------------------
Write-Log $logMessages.messages.savingResolved -Level "info"
$gitVersion   = & git --version 2>$null
$userName     = & git config --global user.name 2>$null
$userEmail    = & git config --global user.email 2>$null
$credHelper   = & git config --global credential.helper 2>$null
$autocrlf     = & git config --global core.autocrlf 2>$null

Save-ResolvedData -ScriptFolder "09-install-git" -Data @{
    gitVersion       = $gitVersion
    userName         = $userName
    userEmail        = $userEmail
    credentialHelper = $credHelper
    autocrlf         = $autocrlf
    timestamp        = (Get-Date -Format "o")
}

Write-Log "Git setup complete." -Level "success"
