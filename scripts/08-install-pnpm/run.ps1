# --------------------------------------------------------------------------
#  Script 08 -- Install pnpm
#  Installs pnpm globally via npm and configures the global store.
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
. (Join-Path $sharedDir "path-utils.ps1")

# -- Dot-source script helpers ------------------------------------------------
. (Join-Path $scriptDir "helpers\pnpm.ps1")

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

# -- Note: No admin required for pnpm -----------------------------------------

# -- Resolve dev directory -----------------------------------------------------
$devDir = if ($env:DEV_DIR) { $env:DEV_DIR } else { $null }

# -- Execute subcommand --------------------------------------------------------
switch ($Command.ToLower()) {
    "all" {
        Install-Pnpm -Config $config -LogMessages $logMessages
        $storePath = Configure-PnpmStore -Config $config -LogMessages $logMessages -DevDir $devDir
        Update-PnpmPath -Config $config -LogMessages $logMessages
    }
    "install" {
        Install-Pnpm -Config $config -LogMessages $logMessages
    }
    "configure" {
        $storePath = Configure-PnpmStore -Config $config -LogMessages $logMessages -DevDir $devDir
        Update-PnpmPath -Config $config -LogMessages $logMessages
    }
    default {
        Write-Log "Unknown command: $Command. Use -Help for usage." -Level "error"
        return
    }
}

# -- Save resolved state -------------------------------------------------------
Write-Log $logMessages.messages.savingResolved -Level "info"
$pnpmVersion = & pnpm --version 2>$null
$storeDir    = & pnpm config get store-dir 2>$null

Save-ResolvedData -ScriptFolder "08-install-pnpm" -Data @{
    pnpmVersion = $pnpmVersion
    storeDir    = $storeDir
    pnpmHome    = $env:PNPM_HOME
    timestamp   = (Get-Date -Format "o")
}

Write-Log "pnpm setup complete." -Level "success"
