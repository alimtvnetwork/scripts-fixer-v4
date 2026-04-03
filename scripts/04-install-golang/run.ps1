<#
.SYNOPSIS
    Installs Go and configures GOPATH, PATH, and go env settings.

.DESCRIPTION
    Uses Chocolatey to install/upgrade Go, resolves GOPATH from config or
    user prompt, updates PATH, and applies go env settings (GOMODCACHE,
    GOCACHE, GOPROXY, GOPRIVATE).

.PARAMETER Command
    Subcommand: "all" (default), "install", "configure".

.PARAMETER Help
    Show available commands and usage.

.NOTES
    Author : Lovable AI
    Version: 1.0.0
#>

param(
    [string]$Command = "all",
    [switch]$Help
)

$ErrorActionPreference = "Stop"
$script:ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# ── Load shared helpers ──────────────────────────────────────────────
. (Join-Path $script:ScriptDir "..\shared\logging.ps1")
. (Join-Path $script:ScriptDir "..\shared\choco-utils.ps1")
. (Join-Path $script:ScriptDir "..\shared\path-utils.ps1")
. (Join-Path $script:ScriptDir "..\shared\dev-dir.ps1")

$sharedHelp = Join-Path $script:ScriptDir "..\shared\help.ps1"
if (Test-Path $sharedHelp) { . $sharedHelp }

$sharedResolved = Join-Path $script:ScriptDir "..\shared\resolved.ps1"
if (Test-Path $sharedResolved) { . $sharedResolved }

# ── Load script-specific helpers ─────────────────────────────────────
. (Join-Path $script:ScriptDir "helpers\golang.ps1")

# ── Handle --help ────────────────────────────────────────────────────
if ($Help) {
    Show-ScriptHelp `
        -Name "Install Golang" `
        -Version "1.0.0" `
        -Description "Installs Go via Chocolatey, configures GOPATH, PATH, and go env." `
        -Commands @(
            @{ Name = "all";       Description = "Install + configure (default)" },
            @{ Name = "install";   Description = "Install/upgrade Go only (skip env config)" },
            @{ Name = "configure"; Description = "Configure GOPATH/env only (skip install)" }
        ) `
        -Flags @(
            @{ Name = "-Help"; Description = "Show this help message" }
        ) `
        -Examples @(
            ".\run.ps1                # Install + configure (default)",
            ".\run.ps1 install        # Install/upgrade Go only",
            ".\run.ps1 configure      # Configure GOPATH and go env only",
            ".\run.ps1 -Help          # Show this help"
        )
    exit 0
}

Write-Host "  [ INFO ] Script directory: $($script:ScriptDir)" -ForegroundColor Cyan

# ── Git pull ─────────────────────────────────────────────────────────
$sharedGitPull = Join-Path $script:ScriptDir "..\shared\git-pull.ps1"
if (Test-Path $sharedGitPull) {
    . $sharedGitPull
    $repoRoot = Split-Path -Parent (Split-Path -Parent $script:ScriptDir)
    Invoke-GitPull -RepoRoot $repoRoot
}

# ── Start logging ────────────────────────────────────────────────────
$logFile = Initialize-Logging -ScriptDir $script:ScriptDir

try {
    # Load log messages
    $logPath = Join-Path $script:ScriptDir "log-messages.json"
    $script:LogMessages = Import-JsonConfig -FilePath $logPath -Label "log-messages.json"
    if (-not $script:LogMessages) { exit 1 }

    Write-Banner $script:LogMessages.banner

    # Check admin
    $identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Log $script:LogMessages.errors.notAdmin "fail"
        Write-Host "  Tip: Right-click PowerShell -> 'Run as Administrator'" -ForegroundColor Yellow
        exit 1
    }
    Write-Log "Running as Administrator: $($identity.Name)" "ok"

    # Load config
    $cfgPath = Join-Path $script:ScriptDir "config.json"
    $Config = Import-JsonConfig -FilePath $cfgPath -Label "config.json"
    if (-not $Config) { exit 1 }

    if (-not $Config.enabled) {
        Write-Log $script:LogMessages.errors.disabled "skip"
        exit 0
    }

    # Ensure Chocolatey is available (needed for install)
    if ($Command.ToLower() -ne "configure") {
        $chocoOk = Assert-Choco
        if (-not $chocoOk) {
            Write-Log "Chocolatey is required -- run script 03 first" "fail"
            exit 1
        }
    }

    Write-Log "Command: $Command" "info"

    # Run setup
    $success = Invoke-GoSetup -Config $Config -ScriptDir $script:ScriptDir -Command $Command.ToLower()

    # Summary
    Write-Host ""
    if ($success) {
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
