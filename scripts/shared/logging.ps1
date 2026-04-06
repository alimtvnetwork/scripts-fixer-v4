<#
.SYNOPSIS
    Shared logging helpers used by all scripts in this repo.
    Logs are written to scripts/logs/ as structured JSON files.
#>

# ── Module-scoped log state ──────────────────────────────────────────────────
$script:_LogEvents   = [System.Collections.ArrayList]::new()
$script:_LogErrors   = [System.Collections.ArrayList]::new()
$script:_LogName     = $null
$script:_LogStart    = $null
$script:_LogsDir     = $null

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

    $badge  = $null
    $hasLogMessages = (Get-Variable -Name LogMessages -Scope Script -ErrorAction SilentlyContinue) -and
                      $script:LogMessages.PSObject.Properties['status']
    if ($hasLogMessages) {
        $badge = $script:LogMessages.status.$Status
    }
    $isBadgeMissing = -not $badge
    if ($isBadgeMissing) {
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

    # Highlight version numbers in a distinct color
    $versionPattern = '(v?\d+\.\d+[\.\d]*[a-zA-Z0-9\-\.]*)'
    $parts = [regex]::Split($Message, $versionPattern)
    foreach ($part in $parts) {
        $isVersion = [regex]::IsMatch($part, "^$versionPattern$")
        if ($isVersion) {
            Write-Host $part -ForegroundColor Yellow -NoNewline
        }
        else {
            Write-Host $part -NoNewline
        }
    }
    Write-Host ""

    # ── Record structured event ──────────────────────────────────────────
    $event = @{
        timestamp = (Get-Date -Format "o")
        level     = $Status
        message   = $Message
    }
    $script:_LogEvents.Add($event) | Out-Null

    # Also track errors separately
    $isError = $Status -eq "fail"
    if ($isError) {
        $script:_LogErrors.Add($event) | Out-Null
    }
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
        # Always read version from the central scripts/version.json
        $versionFilePath = Join-Path (Split-Path -Parent $PSScriptRoot) "version.json"
        $isShared = (Split-Path -Leaf $PSScriptRoot) -eq "shared"
        if ($isShared) {
            $versionFilePath = Join-Path (Split-Path -Parent $PSScriptRoot) "version.json"
        }
        $hasVersionFile = Test-Path $versionFilePath
        if ($hasVersionFile) {
            $versionData = Get-Content $versionFilePath -Raw | ConvertFrom-Json
            $Version = $versionData.version
        }

        $header = if ($Version) { "$Title -- v$Version" } else { $Title }
        $border = "-" * ([Math]::Max($header.Length + 6, 60))
        $Lines = @($border, "  $header", $border)
    }

    Write-Host ""
    foreach ($line in $Lines) { Write-Host $line -ForegroundColor $Color }
    Write-Host ""
}

function Initialize-Logging {
    param(
        [Parameter(Position = 0)]
        [string]$ScriptName
    )

    # Resolve scripts/logs/ directory (always at scripts root)
    $scriptsRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    # If PSScriptRoot is already scripts/shared, go up one level
    $isSharedDir = (Split-Path -Leaf $PSScriptRoot) -eq "shared"
    if ($isSharedDir) {
        $scriptsRoot = Split-Path -Parent $PSScriptRoot
    }

    $logsDir = Join-Path $scriptsRoot "logs"

    # Create logs dir if missing
    $isLogsDirMissing = -not (Test-Path $logsDir)
    if ($isLogsDirMissing) {
        New-Item -Path $logsDir -ItemType Directory -Force | Out-Null
    }

    # Sanitise script name for filename (e.g. "Install Golang" -> "golang")
    $safeName = $ScriptName.ToLower() -replace '[^a-z0-9]+', '-'
    $safeName = $safeName.Trim('-')

    # Store state
    $script:_LogsDir   = $logsDir
    $script:_LogName   = $safeName
    $script:_LogStart  = Get-Date
    $script:_LogEvents = [System.Collections.ArrayList]::new()
    $script:_LogErrors = [System.Collections.ArrayList]::new()

    Write-Log "Logging initialised -- events will be saved to: $logsDir\$safeName.json" -Level "info"
}

function Save-LogFile {
    <#
    .SYNOPSIS
        Flush collected log events to scripts/logs/<name>.json
        and scripts/logs/<name>-error.json (if errors exist).
    #>
    param(
        [string]$Status = "ok"
    )

    $isNotInitialised = -not $script:_LogsDir
    if ($isNotInitialised) { return }

    $endTime  = Get-Date
    $duration = ($endTime - $script:_LogStart).TotalSeconds

    # Main log file
    $logData = @{
        scriptName = $script:_LogName
        status     = $Status
        startTime  = $script:_LogStart.ToString("o")
        endTime    = $endTime.ToString("o")
        duration   = [math]::Round($duration, 2)
        eventCount = $script:_LogEvents.Count
        errorCount = $script:_LogErrors.Count
        events     = @($script:_LogEvents)
    }

    $logPath = Join-Path $script:_LogsDir "$($script:_LogName).json"
    $logData | ConvertTo-Json -Depth 5 | Set-Content -Path $logPath -Encoding UTF8
    Write-Host "  [  OK  ] Log saved: $logPath" -ForegroundColor Green

    # Error log file -- written when there are individual errors OR overall failure
    $hasErrors = $script:_LogErrors.Count -gt 0
    $isOverallFailure = $Status -eq "fail"
    $shouldWriteErrorLog = $hasErrors -or $isOverallFailure
    if ($shouldWriteErrorLog) {
        $errorData = @{
            scriptName    = $script:_LogName
            overallStatus = $Status
            startTime     = $script:_LogStart.ToString("o")
            endTime       = $endTime.ToString("o")
            duration      = [math]::Round($duration, 2)
            errorCount    = $script:_LogErrors.Count
            errors        = @($script:_LogErrors)
        }

        $errorPath = Join-Path $script:_LogsDir "$($script:_LogName)-error.json"
        $errorData | ConvertTo-Json -Depth 5 | Set-Content -Path $errorPath -Encoding UTF8
        Write-Host "  [ WARN ] Error log saved: $errorPath" -ForegroundColor Yellow
    }
}

function Import-JsonConfig {
    param(
        [Parameter(Position = 0, Mandatory)]
        [string]$FilePath,

        [Parameter(Position = 1)]
        [string]$Label
    )

    $slm = $script:SharedLogMessages

    $isLabelMissing = -not $Label
    if ($isLabelMissing) { $Label = Split-Path -Leaf $FilePath }

    # Use shared log messages if available, otherwise fall back to direct Write-Host
    $hasSharedLogs = $null -ne $slm
    if ($hasSharedLogs) {
        Write-Log ($slm.messages.importLoading -replace '\{label\}', $Label -replace '\{path\}', $FilePath) -Level "info"
    }

    $isFileMissing = -not (Test-Path $FilePath)
    if ($isFileMissing) {
        if ($hasSharedLogs) {
            Write-Log ($slm.messages.importNotFound -replace '\{label\}', $Label -replace '\{path\}', $FilePath) -Level "error"
        }
        return $null
    }

    $content = Get-Content $FilePath -Raw
    if ($hasSharedLogs) {
        Write-Log ($slm.messages.importFileSize -replace '\{label\}', $Label -replace '\{size\}', $content.Length) -Level "info"
    }

    $parsed = $content | ConvertFrom-Json
    if ($hasSharedLogs) {
        Write-Log ($slm.messages.importLoaded -replace '\{label\}', $Label) -Level "success"
    }
    return $parsed
}
