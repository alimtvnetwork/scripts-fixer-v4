<#
.SYNOPSIS
    Imports a VS Code profile: settings, keybindings, and extensions for Stable & Insiders.

.DESCRIPTION
    Reads a VS Code .code-profile export (or individual JSON files) and applies
    settings.json, keybindings.json, and installs extensions via the CLI.
    Supports both Stable and Insiders editions. Backs up existing files before overwriting.

    Use -Merge to deep-merge new settings into existing settings.json instead of replacing.

.PARAMETER Merge
    When set, deep-merges incoming settings into existing settings.json rather than
    replacing. Top-level keys from the incoming file overwrite existing ones, but
    keys only present in the existing file are preserved.

.NOTES
    Author : Lovable AI
    Version: 5.0.0
#>

param(
    [switch]$Merge
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

Write-Host "  [ INFO ] Script directory: $ScriptDir" -ForegroundColor Cyan

# ── Load shared helpers ──────────────────────────────────────────────
. (Join-Path $ScriptDir "..\shared\logging.ps1")
. (Join-Path $ScriptDir "..\shared\json-utils.ps1")

$sharedResolved = Join-Path $ScriptDir "..\shared\resolved.ps1"
if (Test-Path $sharedResolved) { . $sharedResolved }

# ── Load script-specific helpers ─────────────────────────────────────
. (Join-Path $ScriptDir "helpers\sync.ps1")

# ── Git pull (guard is inside Invoke-GitPull) ────────────────────────
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

    # Load config
    $cfgPath = Join-Path $ScriptDir "config.json"
    $Config = Import-JsonConfig -FilePath $cfgPath -Label "config.json"
    if (-not $Config) { exit 1 }

    # Resolve source files
    $sources = Resolve-SourceFiles -ScriptDir $ScriptDir

    if (-not $sources.Settings) {
        Write-Log "No settings source found -- cannot continue" "fail"
        exit 1
    }

    $enabledEditions = $Config.enabledEditions
    $totalSuccess    = $true

    Write-Log "Enabled editions: $($enabledEditions -join ', ')" "info"
    Write-Log "Extensions to install: $($sources.Extensions.Count)" "info"
    if ($Merge) {
        Write-Log "Merge mode enabled -- settings will be deep-merged" "info"
    } else {
        Write-Log "Replace mode -- existing settings will be backed up and replaced" "info"
    }

    # Process each edition
    foreach ($editionName in $enabledEditions) {
        $edition = $Config.editions.$editionName

        if (-not $edition) {
            Write-Log "Unknown edition '$editionName' -- skipping" "warn"
            $totalSuccess = $false
            continue
        }

        $result = Invoke-Edition `
            -Edition      $edition `
            -EditionName  $editionName `
            -Sources      $sources `
            -BackupSuffix $Config.backupSuffix `
            -MergeMode    $Merge.IsPresent `
            -ScriptDir    $ScriptDir

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
