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
    Version: 1.2.0
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

function Resolve-VsCodePath {
    param(
        [PSCustomObject]$PathConfig,
        [string]$PreferredType
    )

    $rawPath = $PathConfig.$PreferredType
    $exePath = [System.Environment]::ExpandEnvironmentVariables($rawPath)

    if (Test-Path $exePath) { return $exePath }

    # Fallback to the other type
    $fallback = if ($PreferredType -eq "user") { "system" } else { "user" }
    $fallbackRaw = $PathConfig.$fallback
    $fallbackExe = [System.Environment]::ExpandEnvironmentVariables($fallbackRaw)

    Write-Log "Primary path not found ($exePath), trying $fallback..." "warn"
    if (Test-Path $fallbackExe) {
        Write-Log "Fallback path valid: $fallbackExe" "ok"
        return $fallbackExe
    }

    return $null
}

# ── Main ─────────────────────────────────────────────────────────────
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# ── Setup file logging ──────────────────────────────────────────────
$logsDir = Join-Path $ScriptDir "logs"
if (-not (Test-Path $logsDir)) { New-Item -Path $logsDir -ItemType Directory -Force -Confirm:$false | Out-Null }
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logFile   = Join-Path $logsDir "run-$timestamp.log"
Start-Transcript -Path $logFile -Force | Out-Null

try {

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

# Map HKCR PSDrive
Write-Log $script:LogMessages.steps.mapDrive
if (-not (Get-PSDrive -Name HKCR -ErrorAction SilentlyContinue)) {
    New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT -Confirm:$false | Out-Null
    Write-Log "HKCR PSDrive mapped" "ok"
} else {
    Write-Log "HKCR PSDrive already exists" "skip"
}

$installType     = $Config.installationType
$enabledEditions = $Config.enabledEditions
$totalSuccess    = $true

Write-Log "Installation type preference: $installType" "info"
Write-Log "Enabled editions: $($enabledEditions -join ', ')" "info"
Write-Host ""

# ── Process each edition ─────────────────────────────────────────────
foreach ($editionName in $enabledEditions) {
    $edition = $Config.editions.$editionName

    if (-not $edition) {
        Write-Log "Unknown edition '$editionName' in enabledEditions -- skipping" "warn"
        continue
    }

    Write-Host "  +----------------------------------------------" -ForegroundColor DarkCyan
    Write-Host "  |  Edition: $($edition.contextMenuLabel)" -ForegroundColor Cyan
    Write-Host "  +----------------------------------------------" -ForegroundColor DarkCyan

    # Resolve exe path
    Write-Log $script:LogMessages.steps.detectInstall
    $VsCodeExe = Resolve-VsCodePath -PathConfig $edition.vscodePath -PreferredType $installType

    if (-not $VsCodeExe) {
        Write-Log "$($edition.contextMenuLabel): executable not found -- skipping this edition" "warn"
        $totalSuccess = $false
        Write-Host ""
        continue
    }
    Write-Log "Found: $VsCodeExe" "ok"

    $Label   = $edition.contextMenuLabel
    $IconVal = "`"$VsCodeExe`""

    # Registry entries
    $Entries = @(
        @{
            Step   = $script:LogMessages.steps.regFile
            Path   = $edition.registryPaths.file
            CmdArg = "`"$VsCodeExe`" `"%1`""
        },
        @{
            Step   = $script:LogMessages.steps.regDir
            Path   = $edition.registryPaths.directory
            CmdArg = "`"$VsCodeExe`" `"%V`""
        },
        @{
            Step   = $script:LogMessages.steps.regBg
            Path   = $edition.registryPaths.background
            CmdArg = "`"$VsCodeExe`" `"%V`""
        }
    )

    foreach ($entry in $Entries) {
        Write-Log $entry.Step
        try {
            New-Item         -Path $entry.Path -Force -Confirm:$false -ErrorAction Stop | Out-Null
            Set-ItemProperty -Path $entry.Path -Name "(Default)" -Value $Label -Force -Confirm:$false -ErrorAction Stop
            Set-ItemProperty -Path $entry.Path -Name "Icon"      -Value $IconVal -Force -Confirm:$false -ErrorAction Stop

            $cmdPath = "$($entry.Path)\command"
            New-Item         -Path $cmdPath -Force -Confirm:$false -ErrorAction Stop | Out-Null
            Set-ItemProperty -Path $cmdPath -Name "(Default)" -Value $entry.CmdArg -Force -Confirm:$false -ErrorAction Stop

            Write-Log "Registry key created" "ok"
        } catch {
            Write-Log "$($script:LogMessages.errors.registryFail) $_" "fail"
            $totalSuccess = $false
        }
    }

    # Verify
    Write-Log $script:LogMessages.steps.verify
    foreach ($entry in $Entries) {
        if (Test-Path $entry.Path) {
            Write-Log "  [pass] $($entry.Path)" "ok"
        } else {
            Write-Log "  [miss] $($entry.Path)" "fail"
            $totalSuccess = $false
        }
    }

    Write-Host ""
}

# ── Summary ──────────────────────────────────────────────────────────
if ($totalSuccess) {
    Write-Log $script:LogMessages.steps.done "ok"
} else {
    Write-Log "Completed with some warnings -- check output above." "warn"
}

Write-Banner $script:LogMessages.footer "Green"

} catch {
    Write-Host ""
    Write-Host "  [ FAIL ] Unhandled error: $_" -ForegroundColor Red
    Write-Host "  [ FAIL ] Stack: $($_.ScriptStackTrace)" -ForegroundColor Red
    Write-Host ""
    Write-Host "  [ INFO ] Log saved to: $logFile" -ForegroundColor Yellow
} finally {
    Stop-Transcript -ErrorAction SilentlyContinue | Out-Null
    Write-Host "  [ LOG  ] Transcript saved: $logFile" -ForegroundColor DarkGray
}
