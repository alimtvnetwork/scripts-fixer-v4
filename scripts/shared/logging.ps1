<#
.SYNOPSIS
    Shared logging helpers used by all scripts in this repo.
#>

function Write-Log {
    param(
        [Parameter(Position = 0)]
        [string]$Message,

        [Parameter(Position = 1)]
        [string]$Status = "info",

        [string]$Level
    )

    # -Level alias: map new-style names to old-style names
    if ($Level) {
        $Status = switch ($Level.ToLower()) {
            "success" { "ok" }
            "error"   { "fail" }
            default   { $Level }
        }
    }

    # Validate
    $validStatuses = @("ok", "fail", "info", "warn", "skip")
    if ($Status -notin $validStatuses) { $Status = "info" }

    $badge  = $script:LogMessages.status.$Status
    if (-not $badge) {
        # Fallback badges when log-messages.json doesn't have a status block
        $fallbackBadges = @{ ok = "[  OK  ]"; fail = "[ FAIL ]"; info = "[ INFO ]"; warn = "[ WARN ]"; skip = "[ SKIP ]" }
        $badge = $fallbackBadges[$Status]
    }

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
    param(
        [Parameter(Position = 0)]
        [string[]]$Lines,

        [Parameter(Position = 1)]
        [string]$Color = "Magenta",

        [string]$Title,
        [string]$Version
    )

    # New-style: -Title and -Version params
    if ($Title) {
        $header = if ($Version) { "$Title -- v$Version" } else { $Title }
        $border = "-" * ([Math]::Max($header.Length + 6, 60))
        $Lines = @($border, "  $header", $border)
    }

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
        [Parameter(Position = 0, Mandatory)]
        [string]$FilePath,

        [Parameter(Position = 1)]
        [string]$Label
    )

    if (-not $Label) { $Label = Split-Path -Leaf $FilePath }

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
