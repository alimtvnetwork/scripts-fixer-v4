<#
.SYNOPSIS
    VS Code settings sync helpers: source resolution, file application, extension install.

.NOTES
    Dot-sourced by run.ps1. Depends on shared helpers: logging.ps1, json-utils.ps1, resolved.ps1.
#>

function Resolve-SourceFiles {
    param(
        [string]$ScriptDir,
        $LogMessages
    )

    $result = @{ Settings = $null; Keybindings = $null; Extensions = @() }

    # Check for .code-profile first
    $profileFiles = Get-ChildItem -Path $ScriptDir -Filter "*.code-profile" -ErrorAction SilentlyContinue
    Write-Log ($LogMessages.messages.scanningProfiles -replace '\{dir\}', $ScriptDir) -Level "info"
    Write-Log ($LogMessages.messages.profileFilesFound -replace '\{count\}', @($profileFiles).Count) -Level "info"

    $hasProfileFiles = $profileFiles -and $profileFiles.Count -gt 0
    if ($hasProfileFiles) {
        $profilePath = $profileFiles[0].FullName
        Write-Log ($LogMessages.messages.usingProfile -replace '\{name\}', $profileFiles[0].Name) -Level "success"

        try {
            $profileData = Get-Content $profilePath -Raw | ConvertFrom-Json

            if ($profileData.settings) {
                Write-Log $LogMessages.messages.extractingSettings -Level "info"
                $settingsWrapper = $profileData.settings | ConvertFrom-Json
                $settingsContent = $settingsWrapper.settings
                $tmpSettings = Join-Path $env:TEMP "vscode-profile-settings.json"
                $settingsContent | Out-File -FilePath $tmpSettings -Encoding utf8 -Force
                $result.Settings = $tmpSettings
                Write-Log ($LogMessages.messages.settingsExtracted -replace '\{path\}', $tmpSettings) -Level "success"
            }

            if ($profileData.keybindings) {
                Write-Log $LogMessages.messages.extractingKeybindings -Level "info"
                $kbWrapper = $profileData.keybindings | ConvertFrom-Json
                $kbContent = $kbWrapper.keybindings
                $tmpKeybindings = Join-Path $env:TEMP "vscode-profile-keybindings.json"
                $kbContent | Out-File -FilePath $tmpKeybindings -Encoding utf8 -Force
                $result.Keybindings = $tmpKeybindings
                Write-Log ($LogMessages.messages.keybindingsExtracted -replace '\{path\}', $tmpKeybindings) -Level "success"
            }

            if ($profileData.extensions) {
                Write-Log $LogMessages.messages.extractingExtensions -Level "info"
                $profileExtensions = $profileData.extensions | ConvertFrom-Json
                $result.Extensions = @($profileExtensions | Where-Object { $_.disabled -ne $true } | ForEach-Object { $_.identifier.id })
                Write-Log ($LogMessages.messages.extensionsExtracted -replace '\{count\}', $result.Extensions.Count) -Level "success"
            }
        } catch {
            Write-Log ($LogMessages.messages.profileParseFailed -replace '\{error\}', $_) -Level "error"
            Write-Log $LogMessages.messages.profileFallback -Level "warn"
        }
    }

    # Fallback: individual settings.json
    $hasNoSettings = -not $result.Settings
    if ($hasNoSettings) {
        $settingsPath = Join-Path $ScriptDir "settings.json"
        Write-Log ($LogMessages.messages.checkingSettingsJson -replace '\{path\}', $settingsPath) -Level "info"
        $isSettingsFound = Test-Path $settingsPath
        if ($isSettingsFound) {
            $result.Settings = $settingsPath
            Write-Log $LogMessages.messages.settingsJsonFound -Level "success"
        } else {
            Write-Log $LogMessages.messages.settingsJsonMissing -Level "error"
        }
    }

    # Fallback: individual keybindings.json
    $hasNoKeybindings = -not $result.Keybindings
    if ($hasNoKeybindings) {
        $kbPath = Join-Path $ScriptDir "keybindings.json"
        Write-Log ($LogMessages.messages.checkingKeybindingsJson -replace '\{path\}', $kbPath) -Level "info"
        $isKbFound = Test-Path $kbPath
        if ($isKbFound) {
            $result.Keybindings = $kbPath
            Write-Log $LogMessages.messages.keybindingsJsonFound -Level "success"
        } else {
            Write-Log $LogMessages.messages.noKeybindingsJson -Level "info"
        }
    }

    # Fallback: extensions.json
    if ($result.Extensions.Count -eq 0) {
        $extPath = Join-Path $ScriptDir "extensions.json"
        Write-Log ($LogMessages.messages.checkingExtensionsJson -replace '\{path\}', $extPath) -Level "info"
        $isExtFound = Test-Path $extPath
        if ($isExtFound) {
            $extData = Get-Content $extPath -Raw | ConvertFrom-Json
            $result.Extensions = @($extData.extensions)
            Write-Log ($LogMessages.messages.extensionsLoaded -replace '\{count\}', $result.Extensions.Count) -Level "success"
        } else {
            Write-Log $LogMessages.messages.noExtensionsJson -Level "warn"
        }
    }

    return $result
}

function Apply-Settings {
    param(
        [string]$SourcePath,
        [string]$DestPath,
        [string]$BackupSuffix,
        [bool]$MergeMode,
        $LogMessages
    )

    Write-Log ($LogMessages.messages.applyingSettings -replace '\{path\}', $DestPath) -Level "info"
    $isBackupOk = Backup-File -FilePath $DestPath -BackupSuffix $BackupSuffix

    $hasBackupFailed = -not $isBackupOk
    if ($hasBackupFailed) { return $false }

    $hasExistingFile = Test-Path $DestPath
    if ($MergeMode -and $hasExistingFile) {
        Write-Log $LogMessages.messages.mergingSettings -Level "info"
        try {
            $existingObj = Get-Content $DestPath -Raw | ConvertFrom-Json
            $incomingObj = Get-Content $SourcePath -Raw | ConvertFrom-Json
            $existingHt  = ConvertTo-OrderedHashtable -InputObject $existingObj
            $incomingHt  = ConvertTo-OrderedHashtable -InputObject $incomingObj
            $merged      = Merge-JsonDeep -Base $existingHt -Override $incomingHt
            $merged | ConvertTo-Json -Depth 20 | Out-File -FilePath $DestPath -Encoding utf8 -Force
            Write-Log $LogMessages.messages.settingsMerged -Level "success"
            return $true
        } catch {
            Write-Log ($LogMessages.messages.mergeFailed -replace '\{error\}', $_) -Level "warn"
        }
    }

    Write-Log $LogMessages.messages.copyingSettings -Level "info"
    try {
        Copy-Item -Path $SourcePath -Destination $DestPath -Force
        Write-Log $LogMessages.messages.settingsApplied -Level "success"
        return $true
    } catch {
        Write-Log ($LogMessages.messages.settingsCopyFailed -replace '\{error\}', $_) -Level "error"
        return $false
    }
}

function Apply-Keybindings {
    param(
        [string]$SourcePath,
        [string]$DestPath,
        [string]$BackupSuffix,
        $LogMessages
    )

    Write-Log ($LogMessages.messages.applyingKeybindings -replace '\{path\}', $DestPath) -Level "info"
    $isBackupOk = Backup-File -FilePath $DestPath -BackupSuffix $BackupSuffix

    $hasBackupFailed = -not $isBackupOk
    if ($hasBackupFailed) { return $false }

    try {
        Copy-Item -Path $SourcePath -Destination $DestPath -Force
        Write-Log $LogMessages.messages.keybindingsApplied -Level "success"
        return $true
    } catch {
        Write-Log ($LogMessages.messages.keybindingsCopyFailed -replace '\{error\}', $_) -Level "error"
        return $false
    }
}

function Install-Extensions {
    param(
        [string]$CliCommand,
        [string[]]$Extensions,
        $LogMessages
    )

    $isAllOk = $true
    Write-Log ($LogMessages.messages.installingExtensions -replace '\{count\}', $Extensions.Count -replace '\{cli\}', $CliCommand) -Level "info"

    foreach ($ext in $Extensions) {
        Write-Log ($LogMessages.messages.installingExt -replace '\{ext\}', $ext) -Level "info"
        try {
            $output = & $CliCommand --install-extension $ext --force 2>&1
            $hasInstallIssue = $LASTEXITCODE -ne 0 -or $output -match 'Failed|error'
            if ($hasInstallIssue) {
                Write-Log ($LogMessages.messages.extInstallIssue -replace '\{ext\}', $ext -replace '\{output\}', $output) -Level "warn"
                $isAllOk = $false
            } else {
                Write-Log ($LogMessages.messages.extInstalled -replace '\{ext\}', $ext) -Level "success"
            }
        } catch {
            Write-Log ($LogMessages.messages.extInstallFailed -replace '\{ext\}', $ext -replace '\{error\}', $_) -Level "error"
            $isAllOk = $false
        }
    }

    return $isAllOk
}

function Invoke-Edition {
    param(
        [PSCustomObject]$Edition,
        [string]$EditionName,
        $Sources,
        [string]$BackupSuffix,
        [bool]$MergeMode,
        [string]$ScriptDir,
        $LogMessages
    )

    Write-Host ""
    Write-Host $LogMessages.messages.editionBorderLine -ForegroundColor DarkCyan
    Write-Host ($LogMessages.messages.editionLabel -replace '\{label\}', "VS Code $($EditionName.Substring(0,1).ToUpper() + $EditionName.Substring(1))") -ForegroundColor Cyan
    Write-Host $LogMessages.messages.editionBorderLine -ForegroundColor DarkCyan

    $cliCmd = $Edition.cliCommand
    $isAllOk = $true

    # Check CLI
    Write-Log ($LogMessages.messages.checkingCli -replace '\{cli\}', $cliCmd) -Level "info"
    $cliExists = Get-Command $cliCmd -ErrorAction SilentlyContinue
    $isCliMissing = -not $cliExists
    if ($isCliMissing) {
        Write-Log ($LogMessages.messages.cliMissing -replace '\{cli\}', $cliCmd) -Level "warn"
        return $false
    }
    Write-Log ($LogMessages.messages.cliFound -replace '\{cli\}', $cliCmd) -Level "success"

    # Resolve settings directory
    $rawPath     = $Edition.settingsPath
    $settingsDir = [System.Environment]::ExpandEnvironmentVariables($rawPath)
    Write-Log ($LogMessages.messages.settingsPathRaw -replace '\{path\}', $rawPath) -Level "info"
    Write-Log ($LogMessages.messages.settingsPathExpanded -replace '\{path\}', $settingsDir) -Level "info"

    $isDirMissing = -not (Test-Path $settingsDir)
    if ($isDirMissing) {
        Write-Log $LogMessages.messages.settingsDirMissing -Level "info"
        New-Item -Path $settingsDir -ItemType Directory -Force -Confirm:$false | Out-Null
        Write-Log ($LogMessages.messages.settingsDirCreated -replace '\{path\}', $settingsDir) -Level "success"
    }

    # Save resolved settings path to .resolved/
    Save-ResolvedData -ScriptFolder "10-vscode-settings-sync" -Data @{
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
            -MergeMode    $MergeMode `
            -LogMessages  $LogMessages
        $hasFailed = -not $ok
        if ($hasFailed) { $isAllOk = $false }
    }

    # Apply keybindings
    if ($Sources.Keybindings) {
        $ok = Apply-Keybindings `
            -SourcePath   $Sources.Keybindings `
            -DestPath     $destKeybindings `
            -BackupSuffix $BackupSuffix `
            -LogMessages  $LogMessages
        $hasFailed = -not $ok
        if ($hasFailed) { $isAllOk = $false }
    }

    # Install extensions
    $hasExtensions = $Sources.Extensions.Count -gt 0
    if ($hasExtensions) {
        $ok = Install-Extensions -CliCommand $cliCmd -Extensions $Sources.Extensions -LogMessages $LogMessages
        $hasFailed = -not $ok
        if ($hasFailed) { $isAllOk = $false }
    }

    # Verify
    Write-Log $LogMessages.messages.verifyingFiles -Level "info"
    $isSettingsPresent = Test-Path $destSettings
    if ($isSettingsPresent) {
        Write-Log ($LogMessages.messages.settingsPresent -replace '\{path\}', $destSettings) -Level "success"
    } else {
        Write-Log ($LogMessages.messages.settingsMissing -replace '\{path\}', $destSettings) -Level "error"
        $isAllOk = $false
    }

    $hasKeybindingsFile = $Sources.Keybindings -and (Test-Path $destKeybindings)
    if ($hasKeybindingsFile) {
        Write-Log ($LogMessages.messages.keybindingsPresent -replace '\{path\}', $destKeybindings) -Level "success"
    }

    return $isAllOk
}
