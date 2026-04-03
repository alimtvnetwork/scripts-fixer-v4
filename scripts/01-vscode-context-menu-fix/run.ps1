<#
.SYNOPSIS
    Restores "Open with Code" to the Windows right-click context menu.

.DESCRIPTION
    Reads paths from config.json and log messages from log-messages.json,
    then creates the required registry entries for files, folders, and
    folder backgrounds. Supports both VS Code Stable and Insiders editions.
    Must be run as Administrator.

.NOTES
    Author : Lovable AI
    Version: 3.0.0
#>

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

Write-Host "  [ INFO ] Script directory: $ScriptDir" -ForegroundColor Cyan

# ── Load helpers ─────────────────────────────────────────────────────
. (Join-Path $ScriptDir "helpers\logging.ps1")
. (Join-Path $ScriptDir "helpers\registry.ps1")

$sharedResolved = Join-Path $ScriptDir "..\shared\resolved.ps1"
if (Test-Path $sharedResolved) { . $sharedResolved }

# ── Git pull (skip if called from root dispatcher) ───────────────────
$sharedGitPull = Join-Path $ScriptDir "..\shared\git-pull.ps1"
if (Test-Path $sharedGitPull) {
    . $sharedGitPull
    $repoRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)
    Invoke-GitPull -RepoRoot $repoRoot
} else {
    Write-Host "  [ WARN  ] " -ForegroundColor Yellow -NoNewline
    Write-Host "Shared git-pull helper not found -- skipping git pull"
}

# ── Start logging ────────────────────────────────────────────────────
$logFile = Initialize-Logging -ScriptDir $ScriptDir

try {
    # Load log messages
    $logPath = Join-Path $ScriptDir "log-messages.json"
    $script:LogMessages = Import-JsonConfig -FilePath $logPath -Label "log-messages.json"
    if (-not $script:LogMessages) { exit 1 }

    Write-Banner $script:LogMessages.banner

    # Check admin
    if (-not (Assert-Admin)) {
        Write-Log $script:LogMessages.errors.notAdmin "fail"
        Write-Host ""
        Write-Host "  Tip: Right-click PowerShell -> 'Run as Administrator'" -ForegroundColor Yellow
        exit 1
    }

    # Load config
    $cfgPath = Join-Path $ScriptDir "config.json"
    $Config = Import-JsonConfig -FilePath $cfgPath -Label "config.json"
    if (-not $Config) { exit 1 }

    $installType     = $Config.installationType
    $enabledEditions = $Config.enabledEditions
    $totalSuccess    = $true

    Write-Log "Installation type preference: $installType" "info"
    Write-Log "Enabled editions: $($enabledEditions -join ', ')" "info"

    # Process each edition
    foreach ($editionName in $enabledEditions) {
        $edition = $Config.editions.$editionName

        if (-not $edition) {
            Write-Log "Unknown edition '$editionName' in enabledEditions -- skipping" "warn"
            $totalSuccess = $false
            continue
        }

        $result = Invoke-Edition `
            -Edition     $edition `
            -EditionName $editionName `
            -InstallType $installType `
            -ScriptDir   $ScriptDir `
            -Steps       @{
                detectInstall = $script:LogMessages.steps.detectInstall
                regFile       = $script:LogMessages.steps.regFile
                regDir        = $script:LogMessages.steps.regDir
                regBg         = $script:LogMessages.steps.regBg
                verify        = $script:LogMessages.steps.verify
            }

        if (-not $result) { $totalSuccess = $false }
    }

    # Summary
    Write-Host ""
    if ($totalSuccess) {
        Write-Log $script:LogMessages.steps.done "ok"
    } else {
        Write-Log "Completed with some warnings -- check output above." "warn"
    }

    Write-Banner $script:LogMessages.footer "Green"

} catch {
    Write-Host ""
    Write-Log "Unhandled error: $_" "fail"
    Write-Log "Stack: $($_.ScriptStackTrace)" "fail"
    Write-Host ""
    Write-Log "Log saved to: $logFile" "info"
} finally {
    Stop-Transcript -ErrorAction SilentlyContinue | Out-Null
    Write-Host "  [ LOG  ] Transcript saved: $logFile" -ForegroundColor DarkGray
}
