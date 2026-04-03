<#
.SYNOPSIS
    Logging helpers for the VS Code context-menu-fix script.
#>

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

function Initialize-Logging {
    param([string]$ScriptDir)

    $logsDir = Join-Path $ScriptDir "logs"
    Write-Host "  [ INFO ] Log directory: $logsDir" -ForegroundColor Cyan

    # Clean and recreate
    if (Test-Path $logsDir) {
        Write-Host "  [ INFO ] Removing old logs folder..." -ForegroundColor Cyan
        Remove-Item -Path $logsDir -Recurse -Force -Confirm:$false
    }
    New-Item -Path $logsDir -ItemType Directory -Force -Confirm:$false | Out-Null
    Write-Host "  [  OK  ] Logs folder created" -ForegroundColor Green

    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $logFile   = Join-Path $logsDir "run-$timestamp.log"
    Write-Host "  [ INFO ] Transcript file: $logFile" -ForegroundColor Cyan

    Start-Transcript -Path $logFile -Force | Out-Null
    return $logFile
}

function Import-JsonConfig {
    param(
        [string]$FilePath,
        [string]$Label
    )

    Write-Log "Loading $Label from: $FilePath"
    if (-not (Test-Path $FilePath)) {
        Write-Log "$Label not found at path: $FilePath" "fail"
        return $null
    }

    $content = Get-Content $FilePath -Raw
    Write-Log "$Label file size: $($content.Length) chars" "info"

    $parsed = $content | ConvertFrom-Json
    Write-Log "$Label loaded successfully" "ok"
    return $parsed
}
