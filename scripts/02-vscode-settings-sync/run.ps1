<#
.SYNOPSIS
    Applies VS Code settings and installs extensions for Stable & Insiders.

.DESCRIPTION
    Reads configuration from config.json, backs up existing settings.json,
    copies the provided settings.json, and installs extensions from
    extensions.json using the VS Code CLI.

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

Write-Banner $script:LogMessages.banner

# Load config
Write-Log $script:LogMessages.steps.loadConfig
$cfgPath = Join-Path $ScriptDir "config.json"
if (-not (Test-Path $cfgPath)) {
    Write-Log $script:LogMessages.errors.configNotFound "fail"
    exit 1
}
$Config = Get-Content $cfgPath -Raw | ConvertFrom-Json
Write-Log "Configuration loaded" "ok"

# Check for settings.json
$srcSettings = Join-Path $ScriptDir "settings.json"
if (-not (Test-Path $srcSettings)) {
    Write-Log $script:LogMessages.errors.settingsNotFound "fail"
    exit 1
}
Write-Log "Source settings.json found" "ok"

# Load extensions
Write-Log $script:LogMessages.steps.loadExtensions
$extPath = Join-Path $ScriptDir "extensions.json"
$Extensions = @()
if (Test-Path $extPath) {
    $extData    = Get-Content $extPath -Raw | ConvertFrom-Json
    $Extensions = $extData.extensions
    Write-Log "$($Extensions.Count) extension(s) to install" "ok"
} else {
    Write-Log $script:LogMessages.errors.extensionsNotFound "warn"
}

$enabledEditions = $Config.enabledEditions
$totalSuccess    = $true

Write-Log "Enabled editions: $($enabledEditions -join ', ')" "info"
Write-Host ""

# ── Process each edition ─────────────────────────────────────────────
foreach ($editionName in $enabledEditions) {
    $edition = $Config.editions.$editionName

    if (-not $edition) {
        Write-Log "Unknown edition '$editionName' — skipping" "warn"
        continue
    }

    Write-Host "  ┌──────────────────────────────────────────────" -ForegroundColor DarkCyan
    Write-Host "  │  Edition: VS Code $($editionName.Substring(0,1).ToUpper() + $editionName.Substring(1))" -ForegroundColor Cyan
    Write-Host "  └──────────────────────────────────────────────" -ForegroundColor DarkCyan

    $cliCmd = $edition.cliCommand

    # Check CLI availability
    Write-Log $script:LogMessages.steps.checkCli
    $cliExists = Get-Command $cliCmd -ErrorAction SilentlyContinue
    if (-not $cliExists) {
        Write-Log "'$cliCmd' $($script:LogMessages.errors.cliNotFound)" "warn"
        $totalSuccess = $false
        Write-Host ""
        continue
    }
    Write-Log "'$cliCmd' found in PATH" "ok"

    # Resolve settings directory
    $settingsDir  = [System.Environment]::ExpandEnvironmentVariables($edition.settingsPath)
    $destSettings = Join-Path $settingsDir "settings.json"

    # Create settings dir if missing
    if (-not (Test-Path $settingsDir)) {
        New-Item -Path $settingsDir -ItemType Directory -Force | Out-Null
        Write-Log "Created settings directory: $settingsDir" "ok"
    }

    # Backup existing settings
    if (Test-Path $destSettings) {
        Write-Log $script:LogMessages.steps.backupSettings
        $timestamp  = Get-Date -Format "yyyyMMdd-HHmmss"
        $backupName = "settings.json.$timestamp$($Config.backupSuffix)"
        $backupPath = Join-Path $settingsDir $backupName
        try {
            Copy-Item -Path $destSettings -Destination $backupPath -Force
            Write-Log "Backup created: $backupName" "ok"
        } catch {
            Write-Log "$($script:LogMessages.errors.backupFail) $_" "fail"
            $totalSuccess = $false
            Write-Host ""
            continue
        }
    } else {
        Write-Log "No existing settings.json to back up" "skip"
    }

    # Copy new settings
    Write-Log $script:LogMessages.steps.applySettings
    try {
        Copy-Item -Path $srcSettings -Destination $destSettings -Force
        Write-Log "settings.json applied to $settingsDir" "ok"
    } catch {
        Write-Log "$($script:LogMessages.errors.copyFail) $_" "fail"
        $totalSuccess = $false
    }

    # Install extensions
    if ($Extensions.Count -gt 0) {
        foreach ($ext in $Extensions) {
            Write-Log "$($script:LogMessages.steps.installExt) $ext"
            try {
                $output = & $cliCmd --install-extension $ext --force 2>&1
                Write-Log "Installed $ext" "ok"
            } catch {
                Write-Log "$($script:LogMessages.errors.extInstallFail) $ext — $_" "fail"
                $totalSuccess = $false
            }
        }
    }

    # Verify
    Write-Log $script:LogMessages.steps.verify
    if (Test-Path $destSettings) {
        Write-Log "settings.json present at $destSettings" "ok"
    } else {
        Write-Log "settings.json NOT found at $destSettings" "fail"
        $totalSuccess = $false
    }

    Write-Host ""
}

# ── Summary ──────────────────────────────────────────────────────────
if ($totalSuccess) {
    Write-Log $script:LogMessages.steps.done "ok"
} else {
    Write-Log "Completed with some warnings — check output above." "warn"
}

Write-Banner $script:LogMessages.footer "Green"
