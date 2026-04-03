<#
.SYNOPSIS
    VS Code settings sync helpers: source resolution, file application, extension install.

.NOTES
    Dot-sourced by run.ps1. Depends on shared helpers: logging.ps1, json-utils.ps1, resolved.ps1.
#>

function Resolve-SourceFiles {
    param([string]$ScriptDir)

    $result = @{ Settings = $null; Keybindings = $null; Extensions = @() }

    # Check for .code-profile first
    $profileFiles = Get-ChildItem -Path $ScriptDir -Filter "*.code-profile" -ErrorAction SilentlyContinue
    Write-Log "Scanning for .code-profile files in: $ScriptDir" -Level "info"
    Write-Log "Found $(@($profileFiles).Count) .code-profile file(s)" -Level "info"

    if ($profileFiles -and $profileFiles.Count -gt 0) {
        $profilePath = $profileFiles[0].FullName
        Write-Log "Using profile: $($profileFiles[0].Name)" -Level "success"

        try {
            $profileData = Get-Content $profilePath -Raw | ConvertFrom-Json

            if ($profileData.settings) {
                Write-Log "Extracting settings from profile..." -Level "info"
                $settingsWrapper = $profileData.settings | ConvertFrom-Json
                $settingsContent = $settingsWrapper.settings
                $tmpSettings = Join-Path $env:TEMP "vscode-profile-settings.json"
                $settingsContent | Out-File -FilePath $tmpSettings -Encoding utf8 -Force
                $result.Settings = $tmpSettings
                Write-Log "Settings extracted to: $tmpSettings" -Level "success"
            }

            if ($profileData.keybindings) {
                Write-Log "Extracting keybindings from profile..." -Level "info"
                $kbWrapper = $profileData.keybindings | ConvertFrom-Json
                $kbContent = $kbWrapper.keybindings
                $tmpKeybindings = Join-Path $env:TEMP "vscode-profile-keybindings.json"
                $kbContent | Out-File -FilePath $tmpKeybindings -Encoding utf8 -Force
                $result.Keybindings = $tmpKeybindings
                Write-Log "Keybindings extracted to: $tmpKeybindings" -Level "success"
            }

            if ($profileData.extensions) {
                Write-Log "Extracting extensions from profile..." -Level "info"
                $profileExtensions = $profileData.extensions | ConvertFrom-Json
                $result.Extensions = @($profileExtensions | Where-Object { -not $_.disabled } | ForEach-Object { $_.identifier.id })
                Write-Log "Extracted $($result.Extensions.Count) extension(s) from profile" -Level "success"
            }
        } catch {
            Write-Log "Failed to parse profile: $_" -Level "error"
            Write-Log "Falling back to individual JSON files..." -Level "warn"
        }
    }

    # Fallback: individual settings.json
    if (-not $result.Settings) {
        $settingsPath = Join-Path $ScriptDir "settings.json"
        Write-Log "Checking individual settings.json: $settingsPath" -Level "info"
        if (Test-Path $settingsPath) {
            $result.Settings = $settingsPath
            Write-Log "Source settings.json found" -Level "success"
        } else {
            Write-Log "settings.json not found -- cannot continue" -Level "error"
        }
    }

    # Fallback: individual keybindings.json
    if (-not $result.Keybindings) {
        $kbPath = Join-Path $ScriptDir "keybindings.json"
        Write-Log "Checking individual keybindings.json: $kbPath" -Level "info"
        if (Test-Path $kbPath) {
            $result.Keybindings = $kbPath
            Write-Log "Source keybindings.json found" -Level "success"
        } else {
            Write-Log "No keybindings.json -- skipping keybindings" -Level "info"
        }
    }

    # Fallback: extensions.json
    if ($result.Extensions.Count -eq 0) {
        $extPath = Join-Path $ScriptDir "extensions.json"
        Write-Log "Checking individual extensions.json: $extPath" -Level "info"
        if (Test-Path $extPath) {
            $extData = Get-Content $extPath -Raw | ConvertFrom-Json
            $result.Extensions = @($extData.extensions)
            Write-Log "$($result.Extensions.Count) extension(s) loaded from extensions.json" -Level "success"
        } else {
            Write-Log "No extensions.json found" -Level "warn"
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

    Write-Log "Applying settings to: $DestPath" -Level "info"
    $backupOk = Backup-File -FilePath $DestPath -BackupSuffix $BackupSuffix

    if (-not $backupOk) { return $false }

    if ($MergeMode -and (Test-Path $DestPath)) {
        Write-Log "Merge mode: deep-merging into existing settings.json" -Level "info"
        try {
            $existingObj = Get-Content $DestPath -Raw | ConvertFrom-Json
            $incomingObj = Get-Content $SourcePath -Raw | ConvertFrom-Json
            $existingHt  = ConvertTo-OrderedHashtable -InputObject $existingObj
            $incomingHt  = ConvertTo-OrderedHashtable -InputObject $incomingObj
            $merged      = Merge-JsonDeep -Base $existingHt -Override $incomingHt
            $merged | ConvertTo-Json -Depth 20 | Out-File -FilePath $DestPath -Encoding utf8 -Force
            Write-Log "settings.json merged successfully" -Level "success"
            return $true
        } catch {
            Write-Log "Merge failed: $_ -- falling back to replace" -Level "warn"
        }
    }

    Write-Log "Copying settings.json..." -Level "info"
    try {
        Copy-Item -Path $SourcePath -Destination $DestPath -Force
        Write-Log "settings.json applied" -Level "success"
        return $true
    } catch {
        Write-Log "Failed to copy settings: $_" -Level "error"
        return $false
    }
}

function Apply-Keybindings {
    param(
        [string]$SourcePath,
        [string]$DestPath,
        [string]$BackupSuffix
    )

    Write-Log "Applying keybindings to: $DestPath" -Level "info"
    $backupOk = Backup-File -FilePath $DestPath -BackupSuffix $BackupSuffix

    if (-not $backupOk) { return $false }

    try {
        Copy-Item -Path $SourcePath -Destination $DestPath -Force
        Write-Log "keybindings.json applied" -Level "success"
        return $true
    } catch {
        Write-Log "Failed to copy keybindings: $_" -Level "error"
        return $false
    }
}

function Install-Extensions {
    param(
        [string]$CliCommand,
        [string[]]$Extensions
    )

    $allOk = $true
    Write-Log "Installing $($Extensions.Count) extension(s) via '$CliCommand'..." -Level "info"

    foreach ($ext in $Extensions) {
        Write-Log "Installing: $ext" -Level "info"
        try {
            $output = & $CliCommand --install-extension $ext --force 2>&1
            if ($LASTEXITCODE -ne 0 -or $output -match 'Failed|error') {
                Write-Log "Extension install may have failed: $ext -- $output" -Level "warn"
                $allOk = $false
            } else {
                Write-Log "Installed $ext" -Level "success"
            }
        } catch {
            Write-Log "Failed to install $ext -- $_" -Level "error"
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
        [bool]$MergeMode,
        [string]$ScriptDir
    )

    Write-Host ""
    Write-Host "  +----------------------------------------------" -ForegroundColor DarkCyan
    Write-Host "  |  Edition: VS Code $($EditionName.Substring(0,1).ToUpper() + $EditionName.Substring(1))" -ForegroundColor Cyan
    Write-Host "  +----------------------------------------------" -ForegroundColor DarkCyan

    $cliCmd = $Edition.cliCommand
    $allOk  = $true

    # Check CLI
    Write-Log "Checking CLI command: $cliCmd" -Level "info"
    $cliExists = Get-Command $cliCmd -ErrorAction SilentlyContinue
    if (-not $cliExists) {
        Write-Log "'$cliCmd' not found in PATH -- skipping this edition" -Level "warn"
        return $false
    }
    Write-Log "'$cliCmd' found in PATH" -Level "success"

    # Resolve settings directory
    $rawPath     = $Edition.settingsPath
    $settingsDir = [System.Environment]::ExpandEnvironmentVariables($rawPath)
    Write-Log "Settings path (raw): $rawPath" -Level "info"
    Write-Log "Settings path (expanded): $settingsDir" -Level "info"

    if (-not (Test-Path $settingsDir)) {
        Write-Log "Settings directory does not exist -- creating..." -Level "info"
        New-Item -Path $settingsDir -ItemType Directory -Force -Confirm:$false | Out-Null
        Write-Log "Created: $settingsDir" -Level "success"
    }

    # Save resolved settings path to .resolved/
    Save-ResolvedData -ScriptDir $ScriptDir -Data @{
        $EditionName = @{
            settingsDir = $settingsDir
            cliCommand  = $cliCmd
            resolvedAt  = (Get-Date -Format "o")
            resolvedBy  = $env:USERNAME
        }
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
    Write-Log "Verifying applied files..." -Level "info"
    if (Test-Path $destSettings) {
        Write-Log "settings.json present at $destSettings" -Level "success"
    } else {
        Write-Log "settings.json NOT found at $destSettings" -Level "error"
        $allOk = $false
    }

    if ($Sources.Keybindings -and (Test-Path $destKeybindings)) {
        Write-Log "keybindings.json present at $destKeybindings" -Level "success"
    }

    return $allOk
}
