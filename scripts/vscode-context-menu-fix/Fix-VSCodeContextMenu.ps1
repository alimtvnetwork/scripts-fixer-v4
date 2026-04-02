<#
.SYNOPSIS
    Restores "Open with Code" to the Windows right-click context menu.

.DESCRIPTION
    Reads paths from config.json and log messages from log-messages.json,
    then creates the required registry entries for files, folders, and
    folder backgrounds. Must be run as Administrator.

.NOTES
    Author : Lovable AI
    Version: 1.0.0
#>

# ── Helpers ──────────────────────────────────────────────────────────
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("ok","fail","info","warn","skip")]
        [string]$Status = "info"
    )

    $badge  = $script:LogMessages.status.$Status
    $colors = @{
        ok   = "Green"
        fail = "Red"
        info = "Cyan"
        warn = "Yellow"
        skip = "DarkGray"
    }

    Write-Host "  $badge " -ForegroundColor $colors[$Status] -NoNewline
    Write-Host $Message
}

function Write-Banner {
    param([string[]]$Lines, [string]$Color = "Magenta")
    Write-Host ""
    foreach ($line in $Lines) { Write-Host $line -ForegroundColor $Color }
    Write-Host ""
}

function Assert-Admin {
    $identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# ── Main ─────────────────────────────────────────────────────────────
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Load log messages
$logPath = Join-Path $ScriptDir "log-messages.json"
if (-not (Test-Path $logPath)) {
    Write-Host "  [ FAIL ] log-messages.json not found at $logPath" -ForegroundColor Red
    exit 1
}
$script:LogMessages = Get-Content $logPath -Raw | ConvertFrom-Json

# Print banner
Write-Banner $script:LogMessages.banner

# Check admin
Write-Log $script:LogMessages.steps.init
if (-not (Assert-Admin)) {
    Write-Log $script:LogMessages.errors.notAdmin "fail"
    Write-Host ""
    Write-Host "  Tip: Right-click PowerShell -> 'Run as Administrator'" -ForegroundColor Yellow
    exit 1
}
Write-Log "Running with Administrator privileges" "ok"

# Load config
Write-Log $script:LogMessages.steps.loadConfig
$cfgPath = Join-Path $ScriptDir "config.json"
if (-not (Test-Path $cfgPath)) {
    Write-Log $script:LogMessages.errors.configNotFound "fail"
    exit 1
}
$Config = Get-Content $cfgPath -Raw | ConvertFrom-Json
Write-Log "Configuration loaded" "ok"

# Determine VS Code path
Write-Log $script:LogMessages.steps.detectInstall
$installType = $Config.installationType
$rawPath     = $Config.vscodePath.$installType
# Expand environment variables in the path
$VsCodeExe   = [System.Environment]::ExpandEnvironmentVariables($rawPath)
Write-Log "Installation type: $installType" "info"

Write-Log $script:LogMessages.steps.validatePath
if (-not (Test-Path $VsCodeExe)) {
    Write-Log "$($script:LogMessages.errors.vscodeNotFound) ($VsCodeExe)" "fail"

    # Try the other path as fallback
    $fallback = if ($installType -eq "user") { "system" } else { "user" }
    $fallbackRaw = $Config.vscodePath.$fallback
    $fallbackExe = [System.Environment]::ExpandEnvironmentVariables($fallbackRaw)

    Write-Log "Trying fallback ($fallback): $fallbackExe" "warn"
    if (Test-Path $fallbackExe) {
        $VsCodeExe = $fallbackExe
        Write-Log "Fallback path valid" "ok"
    } else {
        Write-Log "Fallback path also not found. Aborting." "fail"
        exit 1
    }
} else {
    Write-Log "VS Code found at: $VsCodeExe" "ok"
}

# Map HKCR PSDrive
Write-Log $script:LogMessages.steps.mapDrive
if (-not (Get-PSDrive -Name HKCR -ErrorAction SilentlyContinue)) {
    New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT | Out-Null
    Write-Log "HKCR PSDrive mapped" "ok"
} else {
    Write-Log "HKCR PSDrive already exists" "skip"
}

$Label   = $Config.contextMenuLabel
$IconVal = "`"$VsCodeExe`""

# Registry entries to create
$Entries = @(
    @{
        Step    = $script:LogMessages.steps.regFile
        Path    = $Config.registryPaths.file
        CmdArg  = "`"$VsCodeExe`" `"%1`""
    },
    @{
        Step    = $script:LogMessages.steps.regDir
        Path    = $Config.registryPaths.directory
        CmdArg  = "`"$VsCodeExe`" `"%V`""
    },
    @{
        Step    = $script:LogMessages.steps.regBg
        Path    = $Config.registryPaths.background
        CmdArg  = "`"$VsCodeExe`" `"%V`""
    }
)

foreach ($entry in $Entries) {
    Write-Log $entry.Step
    try {
        New-Item    -Path $entry.Path           -Force | Out-Null
        Set-ItemProperty -Path $entry.Path -Name "(Default)" -Value $Label
        Set-ItemProperty -Path $entry.Path -Name "Icon"      -Value $IconVal

        $cmdPath = "$($entry.Path)\command"
        New-Item    -Path $cmdPath              -Force | Out-Null
        Set-ItemProperty -Path $cmdPath -Name "(Default)" -Value $entry.CmdArg

        Write-Log "Registry key created" "ok"
    } catch {
        Write-Log "$($script:LogMessages.errors.registryFail) $_" "fail"
    }
}

# Verify
Write-Log $script:LogMessages.steps.verify
$allGood = $true
foreach ($entry in $Entries) {
    if (Test-Path $entry.Path) {
        Write-Log "  ✓ $($entry.Path)" "ok"
    } else {
        Write-Log "  ✗ $($entry.Path)" "fail"
        $allGood = $false
    }
}

if ($allGood) {
    Write-Log $script:LogMessages.steps.done "ok"
} else {
    Write-Log "Some entries could not be verified." "warn"
}

# Footer
Write-Banner $script:LogMessages.footer "Green"
