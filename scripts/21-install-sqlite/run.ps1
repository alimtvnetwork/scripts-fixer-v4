# --------------------------------------------------------------------------
#  Script 21 -- Install SQLite
#  File-based embedded SQL database
# --------------------------------------------------------------------------
param(
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$scriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Definition
$sharedDir  = Join-Path (Split-Path -Parent $scriptDir) "shared"

# -- Dot-source shared helpers ------------------------------------------------
. (Join-Path $sharedDir "logging.ps1")
. (Join-Path $sharedDir "resolved.ps1")
. (Join-Path $sharedDir "git-pull.ps1")
. (Join-Path $sharedDir "help.ps1")
. (Join-Path $sharedDir "choco-utils.ps1")
. (Join-Path $sharedDir "dev-dir.ps1")

# -- Dot-source script helper -------------------------------------------------
. (Join-Path $scriptDir "helpers\sqlite.ps1")

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

# -- Initialize logging --------------------------------------------------------
Initialize-Logging -ScriptName $logMessages.scriptName

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
$devDir = Resolve-DevDir -Config $config.devDir
Initialize-DevDir -Path $devDir
$env:DEV_DIR = $devDir

# -- Resolve install path ------------------------------------------------------
Write-Host ""
Write-Host "  $($logMessages.messages.installPathTitle)" -ForegroundColor Yellow
Write-Host ""
Write-Host "    [1] " -NoNewline -ForegroundColor Cyan
Write-Host ($logMessages.messages.installPathDevDir -replace '\{path\}', $devDir)
Write-Host "    [2] " -NoNewline -ForegroundColor Cyan
Write-Host "Custom path (you choose)"
Write-Host "    [3] " -NoNewline -ForegroundColor Cyan
Write-Host $logMessages.messages.installPathSystem
Write-Host ""

$choice = Read-Host "  Choose [1/2/3] (default: 1)"
$installPath = ""

$isCustom = $choice -eq "2"
if ($isCustom) {
    $customPath = Read-Host "  $($logMessages.messages.installPathCustom)"
    $hasCustom = -not [string]::IsNullOrWhiteSpace($customPath)
    if ($hasCustom) { $installPath = $customPath }
}

$isSystem = $choice -eq "3"
if ($isSystem) {
    $installPath = ""
} elseif (-not $isCustom) {
    $installPath = Join-Path $devDir "sqlite"
}

$hasPath = -not [string]::IsNullOrWhiteSpace($installPath)
if ($hasPath) {
    Write-Log ($logMessages.messages.installPathChosen -replace '\{path\}', $installPath) -Level "info"
} else {
    Write-Log ($logMessages.messages.installPathChosen -replace '\{path\}', "(system default)") -Level "info"
}

# -- Install -------------------------------------------------------------------
$ok = Install-Sqlite -DbConfig $config.database -LogMessages $logMessages -InstallPath $installPath

$isSuccess = $ok -eq $true
if ($isSuccess) {
    Write-Log $logMessages.messages.setupComplete -Level "success"
} else {
    Write-Log ($logMessages.messages.installFailed -replace '\{error\}', "See errors above") -Level "error"
}

# -- Save log ------------------------------------------------------------------
Save-LogFile -Status $(if ($isSuccess) { "ok" } else { "fail" })
