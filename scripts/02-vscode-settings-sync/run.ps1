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
    Version: 4.0.0
#>

param(
    [switch]$Merge
)

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

# ── Core Functions ───────────────────────────────────────────────────

function Initialize-Logging {
    param([string]$ScriptDir)

    $logsDir = Join-Path $ScriptDir "logs"
    Write-Host "  [ INFO ] Log directory: $logsDir" -ForegroundColor Cyan

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

function Backup-File {
    param([string]$FilePath, [string]$BackupSuffix)

    Write-Log "Checking backup target: $FilePath"
    if (Test-Path $FilePath) {
        $dir       = Split-Path $FilePath -Parent
        $name      = Split-Path $FilePath -Leaf
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $backupName = "$name.$timestamp$BackupSuffix"
        $backupPath = Join-Path $dir $backupName
        Write-Log "Backup destination: $backupPath"
        try {
            Copy-Item -Path $FilePath -Destination $backupPath -Force
            Write-Log "Backup created: $backupName" "ok"
            return $true
        } catch {
            Write-Log "Backup failed for $name -- $_" "fail"
            return $false
        }
    } else {
        Write-Log "No existing $(Split-Path $FilePath -Leaf) to back up" "skip"
        return $true
    }
}

function Merge-JsonDeep {
    param(
        [Parameter(Mandatory)]
        [hashtable]$Base,
        [Parameter(Mandatory)]
        [hashtable]$Override
    )

    $result = $Base.Clone()
    foreach ($key in $Override.Keys) {
        if ($result.ContainsKey($key) -and
            $result[$key] -is [hashtable] -and
            $Override[$key] -is [hashtable]) {
            $result[$key] = Merge-JsonDeep -Base $result[$key] -Override $Override[$key]
        } else {
            $result[$key] = $Override[$key]
        }
    }
    return $result
}

function ConvertTo-OrderedHashtable {
    param([Parameter(Mandatory)][PSCustomObject]$InputObject)

    $ht = [ordered]@{}
    foreach ($prop in $InputObject.PSObject.Properties) {
        if ($prop.Value -is [PSCustomObject]) {
            $ht[$prop.Name] = ConvertTo-OrderedHashtable -InputObject $prop.Value
        } else {
            $ht[$prop.Name] = $prop.Value
        }
    }
    return $ht
}

function Resolve-SourceFiles {
    param([string]$ScriptDir)

    $result = @{ Settings = $null; Keybindings = $null; Extensions = @() }

    # Check for .code-profile first
    $profileFiles = Get-ChildItem -Path $ScriptDir -Filter "*.code-profile" -ErrorAction SilentlyContinue
    Write-Log "Scanning for .code-profile files in: $ScriptDir"
    Write-Log "Found $(@($profileFiles).Count) .code-profile file(s)" "info"

    if ($profileFiles -and $profileFiles.Count -gt 0) {
        $profilePath = $profileFiles[0].FullName
        Write-Log "Using profile: $($profileFiles[0].Name)" "ok"

        try {
            $profileData = Get-Content $profilePath -Raw | ConvertFrom-Json

            if ($profileData.settings) {
                Write-Log "Extracting settings from profile..." "info"
                $settingsWrapper = $profileData.settings | ConvertFrom-Json
                $settingsContent = $settingsWrapper.settings
                $tmpSettings = Join-Path $env:TEMP "vscode-profile-settings.json"
                $settingsContent | Out-File -FilePath $tmpSettings -Encoding utf8 -Force
                $result.Settings = $tmpSettings
                Write-Log "Settings extracted to: $tmpSettings" "ok"
            }

            if ($profileData.keybindings) {
                Write-Log "Extracting keybindings from profile..." "info"
                $kbWrapper = $profileData.keybindings | ConvertFrom-Json
                $kbContent = $kbWrapper.keybindings
                $tmpKeybindings = Join-Path $env:TEMP "vscode-profile-keybindings.json"
                $kbContent | Out-File -FilePath $tmpKeybindings -Encoding utf8 -Force
                $result.Keybindings = $tmpKeybindings
                Write-Log "Keybindings extracted to: $tmpKeybindings" "ok"
            }

            if ($profileData.extensions) {
                Write-Log "Extracting extensions from profile..." "info"
                $profileExtensions = $profileData.extensions | ConvertFrom-Json
                $result.Extensions = @($profileExtensions | Where-Object { -not $_.disabled } | ForEach-Object { $_.identifier.id })
                Write-Log "Extracted $($result.Extensions.Count) extension(s) from profile" "ok"
            }
        } catch {
            Write-Log "Failed to parse profile: $_" "fail"
            Write-Log "Falling back to individual JSON files..." "warn"
        }
    }

    # Fallback: individual settings.json
    if (-not $result.Settings) {
        $settingsPath = Join-Path $ScriptDir "settings.json"
        Write-Log "Checking individual settings.json: $settingsPath"
        if (Test-Path $settingsPath) {
            $result.Settings = $settingsPath
            Write-Log "Source settings.json found" "ok"
        } else {
            Write-Log "settings.json not found -- cannot continue" "fail"
        }
    }

    # Fallback: individual keybindings.json
    if (-not $result.Keybindings) {
        $kbPath = Join-Path $ScriptDir "keybindings.json"
        Write-Log "Checking individual keybindings.json: $kbPath"
        if (Test-Path $kbPath) {
            $result.Keybindings = $kbPath
            Write-Log "Source keybindings.json found" "ok"
        } else {
            Write-Log "No keybindings.json -- skipping keybindings" "skip"
        }
    }

    # Fallback: extensions.json
    if ($result.Extensions.Count -eq 0) {
        $extPath = Join-Path $ScriptDir "extensions.json"
        Write-Log "Checking individual extensions.json: $extPath"
        if (Test-Path $extPath) {
            $extData = Get-Content $extPath -Raw | ConvertFrom-Json
            $result.Extensions = @($extData.extensions)
            Write-Log "$($result.Extensions.Count) extension(s) loaded from extensions.json" "ok"
        } else {
            Write-Log "No extensions.json found" "warn"
        }
    }

    return $result
}

function Apply-Settings {
    param(
        [string]$SourcePath,
        [string]$DestPath,
        [string]$BackupSuffix,
        [bool]$MergeMode
    )

    Write-Log "Applying settings to: $DestPath"
    $backupOk = Backup-File -FilePath $DestPath -BackupSuffix $BackupSuffix

    if (-not $backupOk) { return $false }

    if ($MergeMode -and (Test-Path $DestPath)) {
        Write-Log "Merge mode: deep-merging into existing settings.json" "info"
        try {
            $existingObj = Get-Content $DestPath -Raw | ConvertFrom-Json
            $incomingObj = Get-Content $SourcePath -Raw | ConvertFrom-Json
            $existingHt  = ConvertTo-OrderedHashtable -InputObject $existingObj
            $incomingHt  = ConvertTo-OrderedHashtable -InputObject $incomingObj
            $merged      = Merge-JsonDeep -Base $existingHt -Override $incomingHt
            $merged | ConvertTo-Json -Depth 20 | Out-File -FilePath $DestPath -Encoding utf8 -Force
            Write-Log "settings.json merged successfully" "ok"
            return $true
        } catch {
            Write-Log "Merge failed: $_ -- falling back to replace" "warn"
        }
    }

    Write-Log "Copying settings.json..." "info"
    try {
        Copy-Item -Path $SourcePath -Destination $DestPath -Force
        Write-Log "settings.json applied" "ok"
        return $true
    } catch {
        Write-Log "Failed to copy settings: $_" "fail"
        return $false
    }
}

function Apply-Keybindings {
    param(
        [string]$SourcePath,
        [string]$DestPath,
        [string]$BackupSuffix
    )

    Write-Log "Applying keybindings to: $DestPath"
    $backupOk = Backup-File -FilePath $DestPath -BackupSuffix $BackupSuffix

    if (-not $backupOk) { return $false }

    try {
        Copy-Item -Path $SourcePath -Destination $DestPath -Force
        Write-Log "keybindings.json applied" "ok"
        return $true
    } catch {
        Write-Log "Failed to copy keybindings: $_" "fail"
        return $false
    }
}

function Install-Extensions {
    param(
        [string]$CliCommand,
        [string[]]$Extensions
    )

    $allOk = $true
    Write-Log "Installing $($Extensions.Count) extension(s) via '$CliCommand'..."

    foreach ($ext in $Extensions) {
        Write-Log "Installing: $ext" "info"
        try {
            $output = & $CliCommand --install-extension $ext --force 2>&1
            Write-Log "Installed $ext" "ok"
        } catch {
            Write-Log "Failed to install $ext -- $_" "fail"
            $allOk = $false
        }
    }

    return $allOk
}

function Invoke-Edition {
    param(
        [PSCustomObject]$Edition,
        [string]$EditionName,
        [hashtable]$Sources,
        [string]$BackupSuffix,
        [bool]$MergeMode
    )

    Write-Host ""
    Write-Host "  +----------------------------------------------" -ForegroundColor DarkCyan
    Write-Host "  |  Edition: VS Code $($EditionName.Substring(0,1).ToUpper() + $EditionName.Substring(1))" -ForegroundColor Cyan
    Write-Host "  +----------------------------------------------" -ForegroundColor DarkCyan

    $cliCmd = $Edition.cliCommand
    $allOk  = $true

    # Check CLI
    Write-Log "Checking CLI command: $cliCmd"
    $cliExists = Get-Command $cliCmd -ErrorAction SilentlyContinue
    if (-not $cliExists) {
        Write-Log "'$cliCmd' not found in PATH -- skipping this edition" "warn"
        return $false
    }
    Write-Log "'$cliCmd' found in PATH" "ok"

    # Resolve settings directory
    $rawPath     = $Edition.settingsPath
    $settingsDir = [System.Environment]::ExpandEnvironmentVariables($rawPath)
    Write-Log "Settings path (raw): $rawPath"
    Write-Log "Settings path (expanded): $settingsDir"

    if (-not (Test-Path $settingsDir)) {
        Write-Log "Settings directory does not exist -- creating..." "info"
        New-Item -Path $settingsDir -ItemType Directory -Force -Confirm:$false | Out-Null
        Write-Log "Created: $settingsDir" "ok"
    }

    $destSettings    = Join-Path $settingsDir "settings.json"
    $destKeybindings = Join-Path $settingsDir "keybindings.json"

    # Apply settings
    if ($Sources.Settings) {
        $ok = Apply-Settings `
            -SourcePath   $Sources.Settings `
            -DestPath     $destSettings `
            -BackupSuffix $BackupSuffix `
            -MergeMode    $MergeMode
        if (-not $ok) { $allOk = $false }
    }

    # Apply keybindings
    if ($Sources.Keybindings) {
        $ok = Apply-Keybindings `
            -SourcePath   $Sources.Keybindings `
            -DestPath     $destKeybindings `
            -BackupSuffix $BackupSuffix
        if (-not $ok) { $allOk = $false }
    }

    # Install extensions
    if ($Sources.Extensions.Count -gt 0) {
        $ok = Install-Extensions -CliCommand $cliCmd -Extensions $Sources.Extensions
        if (-not $ok) { $allOk = $false }
    }

    # Verify
    Write-Log "Verifying applied files..."
    if (Test-Path $destSettings) {
        Write-Log "settings.json present at $destSettings" "ok"
    } else {
        Write-Log "settings.json NOT found at $destSettings" "fail"
        $allOk = $false
    }

    if ($Sources.Keybindings -and (Test-Path $destKeybindings)) {
        Write-Log "keybindings.json present at $destKeybindings" "ok"
    }

    return $allOk
}

# ── Main ─────────────────────────────────────────────────────────────

function Main {
    $ErrorActionPreference = "Stop"
    $ScriptDir = Split-Path -Parent $MyInvocation.PSCommandPath

    if (-not $ScriptDir) {
        $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
    }

    Write-Host "  [ INFO ] Script directory: $ScriptDir" -ForegroundColor Cyan

    # Start logging
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
                -MergeMode    $Merge.IsPresent

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
}

# ── Entry Point ──────────────────────────────────────────────────────
Main
