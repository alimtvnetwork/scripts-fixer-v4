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
    Version: 3.0.0
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

function Backup-File {
    param([string]$FilePath, [string]$BackupSuffix)

    if (Test-Path $FilePath) {
        $dir       = Split-Path $FilePath -Parent
        $name      = Split-Path $FilePath -Leaf
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $backupName = "$name.$timestamp$BackupSuffix"
        $backupPath = Join-Path $dir $backupName
        try {
            Copy-Item -Path $FilePath -Destination $backupPath -Force
            Write-Log "Backup created: $backupName" "ok"
            return $true
        } catch {
            Write-Log "Backup failed for $name — $_" "fail"
            return $false
        }
    } else {
        Write-Log "No existing $( Split-Path $FilePath -Leaf ) to back up" "skip"
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

# ── Determine source files ──────────────────────────────────────────
# Check for .code-profile first, then fall back to individual JSON files
$profileFiles = Get-ChildItem -Path $ScriptDir -Filter "*.code-profile" -ErrorAction SilentlyContinue
$srcSettings    = $null
$srcKeybindings = $null

if ($profileFiles -and $profileFiles.Count -gt 0) {
    $profilePath = $profileFiles[0].FullName
    Write-Log "Found VS Code profile: $($profileFiles[0].Name)" "ok"
    Write-Log "Parsing profile to extract settings, keybindings, and extensions..." "info"

    try {
        $profileData = Get-Content $profilePath -Raw | ConvertFrom-Json

        # Extract settings
        if ($profileData.settings) {
            $settingsWrapper = $profileData.settings | ConvertFrom-Json
            $settingsContent = $settingsWrapper.settings
            $tmpSettings = Join-Path $env:TEMP "vscode-profile-settings.json"
            $settingsContent | Out-File -FilePath $tmpSettings -Encoding utf8 -Force
            $srcSettings = $tmpSettings
            Write-Log "Extracted settings from profile" "ok"
        }

        # Extract keybindings
        if ($profileData.keybindings) {
            $kbWrapper = $profileData.keybindings | ConvertFrom-Json
            $kbContent = $kbWrapper.keybindings
            $tmpKeybindings = Join-Path $env:TEMP "vscode-profile-keybindings.json"
            $kbContent | Out-File -FilePath $tmpKeybindings -Encoding utf8 -Force
            $srcKeybindings = $tmpKeybindings
            Write-Log "Extracted keybindings from profile" "ok"
        }

        # Extract extensions from profile
        if ($profileData.extensions) {
            $profileExtensions = $profileData.extensions | ConvertFrom-Json
            $enabledExts = @($profileExtensions | Where-Object { -not $_.disabled } | ForEach-Object { $_.identifier.id })
            Write-Log "Extracted $($enabledExts.Count) extension(s) from profile" "ok"
        }
    } catch {
        Write-Log "Failed to parse profile: $_" "fail"
        Write-Log "Falling back to individual JSON files..." "warn"
    }
}

# Fall back to individual files if profile parsing didn't provide them
if (-not $srcSettings) {
    $srcSettings = Join-Path $ScriptDir "settings.json"
    if (-not (Test-Path $srcSettings)) {
        Write-Log $script:LogMessages.errors.settingsNotFound "fail"
        exit 1
    }
    Write-Log "Source settings.json found" "ok"
}

if (-not $srcKeybindings) {
    $srcKeybindings = Join-Path $ScriptDir "keybindings.json"
    if (Test-Path $srcKeybindings) {
        Write-Log "Source keybindings.json found" "ok"
    } else {
        $srcKeybindings = $null
        Write-Log "No keybindings.json — skipping keybindings" "skip"
    }
}

# Load extensions (profile-extracted or from file)
Write-Log $script:LogMessages.steps.loadExtensions
if (-not $enabledExts) {
    $extPath = Join-Path $ScriptDir "extensions.json"
    if (Test-Path $extPath) {
        $extData    = Get-Content $extPath -Raw | ConvertFrom-Json
        $enabledExts = @($extData.extensions)
        Write-Log "$($enabledExts.Count) extension(s) to install" "ok"
    } else {
        $enabledExts = @()
        Write-Log $script:LogMessages.errors.extensionsNotFound "warn"
    }
} else {
    Write-Log "$($enabledExts.Count) extension(s) to install (from profile)" "ok"
}

$enabledEditions = $Config.enabledEditions
$totalSuccess    = $true

Write-Log "Enabled editions: $($enabledEditions -join ', ')" "info"
if ($Merge) {
    Write-Log "Merge mode enabled — settings will be deep-merged, not replaced" "info"
} else {
    Write-Log "Replace mode — existing settings will be backed up and replaced" "info"
}
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
    $settingsDir    = [System.Environment]::ExpandEnvironmentVariables($edition.settingsPath)
    $destSettings   = Join-Path $settingsDir "settings.json"
    $destKeybindings = Join-Path $settingsDir "keybindings.json"

    # Create settings dir if missing
    if (-not (Test-Path $settingsDir)) {
        New-Item -Path $settingsDir -ItemType Directory -Force | Out-Null
        Write-Log "Created settings directory: $settingsDir" "ok"
    }

    # ── Apply settings.json ──────────────────────────────────────────
    Write-Log $script:LogMessages.steps.backupSettings
    $backupOk = Backup-File -FilePath $destSettings -BackupSuffix $Config.backupSuffix

    if ($backupOk) {
        if ($Merge -and (Test-Path $destSettings)) {
            Write-Log "Merge mode: deep-merging into existing settings.json" "info"
            try {
                $existingObj = Get-Content $destSettings -Raw | ConvertFrom-Json
                $incomingObj = Get-Content $srcSettings -Raw | ConvertFrom-Json
                $existingHt  = ConvertTo-OrderedHashtable -InputObject $existingObj
                $incomingHt  = ConvertTo-OrderedHashtable -InputObject $incomingObj
                $merged      = Merge-JsonDeep -Base $existingHt -Override $incomingHt
                $merged | ConvertTo-Json -Depth 20 | Out-File -FilePath $destSettings -Encoding utf8 -Force
                Write-Log "settings.json merged into $settingsDir" "ok"
            } catch {
                Write-Log "Merge failed: $_ — falling back to replace" "warn"
                Copy-Item -Path $srcSettings -Destination $destSettings -Force
                Write-Log "settings.json replaced in $settingsDir" "ok"
            }
        } else {
            Write-Log $script:LogMessages.steps.applySettings
            try {
                Copy-Item -Path $srcSettings -Destination $destSettings -Force
                Write-Log "settings.json applied to $settingsDir" "ok"
            } catch {
                Write-Log "$($script:LogMessages.errors.copyFail) $_" "fail"
                $totalSuccess = $false
            }
        }
    } else {
        $totalSuccess = $false
    }

    # ── Apply keybindings.json ───────────────────────────────────────
    if ($srcKeybindings) {
        Write-Log "Backing up keybindings..."
        $kbBackupOk = Backup-File -FilePath $destKeybindings -BackupSuffix $Config.backupSuffix

        if ($kbBackupOk) {
            Write-Log "Applying keybindings.json..."
            try {
                Copy-Item -Path $srcKeybindings -Destination $destKeybindings -Force
                Write-Log "keybindings.json applied to $settingsDir" "ok"
            } catch {
                Write-Log "Failed to copy keybindings: $_" "fail"
                $totalSuccess = $false
            }
        } else {
            $totalSuccess = $false
        }
    }

    # ── Install extensions ───────────────────────────────────────────
    if ($enabledExts.Count -gt 0) {
        foreach ($ext in $enabledExts) {
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

    # ── Verify ───────────────────────────────────────────────────────
    Write-Log $script:LogMessages.steps.verify
    if (Test-Path $destSettings) {
        Write-Log "settings.json present at $destSettings" "ok"
    } else {
        Write-Log "settings.json NOT found at $destSettings" "fail"
        $totalSuccess = $false
    }

    if ($srcKeybindings -and (Test-Path $destKeybindings)) {
        Write-Log "keybindings.json present at $destKeybindings" "ok"
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
