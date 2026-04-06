<#
.SYNOPSIS
    Go installation, GOPATH resolution, PATH management, and go env configuration.

.DESCRIPTION
    Adapted from user's existing go-install.ps1. Uses shared helpers for
    Chocolatey, PATH manipulation, and dev directory resolution.
#>

# -- Bootstrap shared helpers --------------------------------------------------
$_sharedDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "shared"
$_loggingPath = Join-Path $_sharedDir "logging.ps1"
if ((Test-Path $_loggingPath) -and -not (Get-Command Write-Log -ErrorAction SilentlyContinue)) {
    . $_loggingPath
}


function Install-Go {
    <#
    .SYNOPSIS
        Installs or upgrades Go via Chocolatey.
    #>
    param(
        [PSCustomObject]$Config,
        $LogMessages
    )

    $packageName = if ($Config.chocoPackageName) { $Config.chocoPackageName } else { "golang" }
    Write-Log ($LogMessages.messages.chocoPackageName -replace '\{name\}', $packageName) -Level "info"

    $goCmd = Get-Command go.exe -ErrorAction SilentlyContinue

    $isGoMissing = -not $goCmd
    if ($isGoMissing) {
        Write-Log $LogMessages.messages.goNotInstalled -Level "info"
        $ok = Install-ChocoPackage -PackageName $packageName
        $hasFailed = -not $ok
        if ($hasFailed) { return $false }

        # Refresh PATH so go.exe is available in this session
        $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
        $goCmd = Get-Command go.exe -ErrorAction SilentlyContinue
        $isStillMissing = -not $goCmd
        if ($isStillMissing) {
            Write-Log $LogMessages.messages.goNotInPath -Level "warn"
            return $false
        }

        $version = & go.exe version 2>&1
        Write-Log ($LogMessages.messages.goVersion -replace '\{version\}', $version) -Level "success"
        Save-InstalledRecord -Name "golang" -Version "$version".Trim()
        return $true
    } else {
        $version = & go.exe version 2>&1

        # Check .installed/ tracking -- skip if version matches
        $isAlreadyTracked = Test-AlreadyInstalled -Name "golang" -CurrentVersion "$version".Trim()
        if ($isAlreadyTracked) {
            Write-Log ($LogMessages.messages.goAlreadyInstalled -replace '\{version\}', $version) -Level "info"
            return $true
        }

        Write-Log $LogMessages.messages.goAlreadyInstalled -Level "success"
        if ($Config.alwaysUpgradeToLatest) {
            Upgrade-ChocoPackage -PackageName $packageName | Out-Null
        }

        $version = & go.exe version 2>&1
        Write-Log ($LogMessages.messages.goVersion -replace '\{version\}', $version) -Level "success"
        Save-InstalledRecord -Name "golang" -Version "$version".Trim()
        return $true
    }
}

function Resolve-Gopath {
    param(
        [PSCustomObject]$GopathConfig,
        [string]$DevDirSubfolder,
        $LogMessages
    )

    $hasDevDir = -not [string]::IsNullOrWhiteSpace($env:DEV_DIR)
    if ($hasDevDir -and $DevDirSubfolder) {
        $derived = Join-Path $env:DEV_DIR $DevDirSubfolder
        Write-Log ($LogMessages.messages.gopathFromDevDir -replace '\{path\}', $derived) -Level "success"
        return $derived
    }

    $hasNoConfig = -not $GopathConfig
    if ($hasNoConfig) {
        $fallback = "E:\dev\go"
        Write-Log ($LogMessages.messages.gopathNoConfig -replace '\{path\}', $fallback) -Level "warn"
        return $fallback
    }

    $default  = if ($GopathConfig.default)  { $GopathConfig.default }  else { "E:\dev\go" }
    $override = if ($GopathConfig.override) { $GopathConfig.override } else { "" }

    $hasOverride = -not [string]::IsNullOrWhiteSpace($override)
    if ($hasOverride) {
        Write-Log ($LogMessages.messages.gopathOverride -replace '\{path\}', $override) -Level "info"
        return $override
    }

    if ($GopathConfig.mode -eq "json-only") {
        Write-Log ($LogMessages.messages.gopathJsonOnly -replace '\{path\}', $default) -Level "info"
        return $default
    }

    $hasDevDirEnv = -not [string]::IsNullOrWhiteSpace($env:DEV_DIR)
    if ($hasDevDirEnv -and $GopathConfig.mode -eq "json-or-prompt") {
        $envGopath = Join-Path $env:DEV_DIR "go"
        Write-Log ($LogMessages.messages.gopathDefault -replace '\{path\}', $envGopath) -Level "info"
        return $envGopath
    }

    $userInput = Read-Host -Prompt "Enter GOPATH (default: $default)"
    $hasUserInput = -not [string]::IsNullOrWhiteSpace($userInput)
    if ($hasUserInput) {
        Write-Log ($LogMessages.messages.gopathUserProvided -replace '\{path\}', $userInput) -Level "info"
        return $userInput
    }

    Write-Log ($LogMessages.messages.gopathDefault -replace '\{path\}', $default) -Level "info"
    return $default
}

function Initialize-Gopath {
    param(
        [Parameter(Mandatory)]
        [string]$GopathValue,
        $LogMessages
    )

    $gopathFull = [System.IO.Path]::GetFullPath($GopathValue)
    Write-Log ($LogMessages.messages.gopathResolved -replace '\{path\}', $gopathFull) -Level "info"

    $isDirMissing = -not (Test-Path $gopathFull)
    if ($isDirMissing) {
        Write-Log ($LogMessages.messages.gopathCreating -replace '\{path\}', $gopathFull) -Level "info"
        New-Item -Path $gopathFull -ItemType Directory -Force -Confirm:$false | Out-Null
        Write-Log $LogMessages.messages.gopathCreated -Level "success"
    }

    try {
        Write-Log ($LogMessages.messages.gopathSettingEnv -replace '\{path\}', $gopathFull) -Level "info"
        [Environment]::SetEnvironmentVariable("GOPATH", $gopathFull, "User")
        $env:GOPATH = $gopathFull
        Write-Log $LogMessages.messages.gopathSet -Level "success"
    } catch {
        Write-Log ($LogMessages.messages.gopathSetFailed -replace '\{error\}', $_) -Level "error"
        return $null
    }

    return $gopathFull
}

function Update-GoPath {
    param(
        [PSCustomObject]$PathConfig,
        [string]$GopathFull,
        $LogMessages
    )

    $isPathUpdateDisabled = -not $PathConfig.updateUserPath
    if ($isPathUpdateDisabled) {
        Write-Log $LogMessages.messages.pathUpdateDisabled -Level "info"
        return $true
    }

    $goBin = Join-Path $GopathFull "bin"

    $isBinMissing = -not (Test-Path $goBin)
    if ($isBinMissing) {
        Write-Log ($LogMessages.messages.goBinCreating -replace '\{path\}', $goBin) -Level "info"
        New-Item -Path $goBin -ItemType Directory -Force -Confirm:$false | Out-Null
    }

    if ($PathConfig.ensureGoBinInPath) {
        return (Add-ToUserPath -Directory $goBin)
    }

    return $true
}

function Set-GoEnvSetting {
    param(
        [Parameter(Mandatory)]
        [string]$Key,
        [Parameter(Mandatory)]
        [string]$Value,
        $LogMessages
    )

    Write-Log ($LogMessages.messages.goEnvRunning -replace '\{key\}', $Key -replace '\{value\}', $Value) -Level "info"
    try {
        & go.exe env -w "$Key=$Value" 2>&1 | ForEach-Object {
            if ($_ -and $_.ToString().Trim().Length -gt 0) { Write-Log $_ -Level "info" }
        }
        if ($LASTEXITCODE -ne 0) {
            Write-Log ($LogMessages.messages.goEnvFailed -replace '\{key\}', $Key -replace '\{code\}', $LASTEXITCODE) -Level "warn"
            return $false
        }
        Write-Log ($LogMessages.messages.goEnvSet -replace '\{key\}', $Key) -Level "success"
        return $true
    } catch {
        Write-Log ($LogMessages.messages.goEnvSetFailed -replace '\{key\}', $Key -replace '\{error\}', $_) -Level "error"
        return $false
    }
}

function Configure-GoEnv {
    param(
        [PSCustomObject]$GoEnvConfig,
        [string]$GopathFull,
        $LogMessages
    )

    $hasNoConfig = -not $GoEnvConfig -or -not $GoEnvConfig.settings
    if ($hasNoConfig) {
        Write-Log $LogMessages.messages.goEnvNoConfig -Level "info"
        return $true
    }

    $settings = $GoEnvConfig.settings
    $relativeToGopath = $GoEnvConfig.relativeToGopath
    $isAllOk = $true

    foreach ($key in $settings.PSObject.Properties.Name) {
        $entry = $settings.$key

        $isEntryDisabled = -not $entry.enabled
        if ($isEntryDisabled) {
            Write-Log ($LogMessages.messages.goEnvDisabled -replace '\{key\}', $key) -Level "info"
            continue
        }

        $finalValue = $null

        $hasRelativePath = $relativeToGopath -and ($entry.PSObject.Properties.Name -contains "relativePath")
        if ($hasRelativePath) {
            $rel = $entry.relativePath
            $isRelEmpty = [string]::IsNullOrWhiteSpace($rel)
            if ($isRelEmpty) {
                Write-Log ($LogMessages.messages.goEnvEmptyRelPath -replace '\{key\}', $key) -Level "warn"
                continue
            }

            $absolutePath = Join-Path $GopathFull $rel
            $isDirMissing = -not (Test-Path $absolutePath)
            if ($isDirMissing) {
                Write-Log ($LogMessages.messages.goEnvCreatingDir -replace '\{key\}', $key -replace '\{path\}', $absolutePath) -Level "info"
                New-Item -Path $absolutePath -ItemType Directory -Force -Confirm:$false | Out-Null
            }
            $finalValue = $absolutePath
        } elseif ($entry.PSObject.Properties.Name -contains "value") {
            $finalValue = $entry.value
        }

        $hasOrchestratorEnv = -not [string]::IsNullOrWhiteSpace($env:SCRIPTS_ROOT_RUN)
        $shouldPrompt = $GoEnvConfig.applyMode -eq "json-or-prompt" -and $entry.promptOnFirstRun -and -not $hasOrchestratorEnv
        if ($shouldPrompt) {
            $userInput = Read-Host -Prompt "Enter value for $key (default: $finalValue)"
            $hasUserInput = -not [string]::IsNullOrWhiteSpace($userInput)
            if ($hasUserInput) {
                $finalValue = $userInput
                Write-Log ($LogMessages.messages.goEnvUserProvided -replace '\{key\}', $key -replace '\{value\}', $finalValue) -Level "info"
            }
        }

        $hasValue = -not [string]::IsNullOrWhiteSpace($finalValue)
        if ($hasValue) {
            $ok = Set-GoEnvSetting -Key $key -Value $finalValue -LogMessages $LogMessages
            $hasFailed = -not $ok
            if ($hasFailed) { $isAllOk = $false }
        } else {
            Write-Log ($LogMessages.messages.goEnvNoValue -replace '\{key\}', $key) -Level "warn"
        }
    }

    return $isAllOk
}

function Invoke-GoSetup {
    param(
        [PSCustomObject]$Config,
        [string]$ScriptDir,
        [string]$Command,
        $LogMessages
    )

    $isAllOk = $true

    $isNotConfigureOnly = $Command -ne "configure"
    if ($isNotConfigureOnly) {
        $ok = Install-Go -Config $Config -LogMessages $LogMessages
        $hasFailed = -not $ok
        if ($hasFailed) {
            Write-Log $LogMessages.messages.goInstallFailed -Level "error"
            return $false
        }
    }

    $isNotInstallOnly = $Command -ne "install"
    if ($isNotInstallOnly) {
        $gopathValue = Resolve-Gopath -GopathConfig $Config.gopath -DevDirSubfolder $Config.devDirSubfolder -LogMessages $LogMessages
        $gopathFull = Initialize-Gopath -GopathValue $gopathValue -LogMessages $LogMessages

        $isGopathFailed = -not $gopathFull
        if ($isGopathFailed) {
            Write-Log $LogMessages.messages.gopathInitFailed -Level "error"
            return $false
        }

        $ok = Update-GoPath -PathConfig $Config.path -GopathFull $gopathFull -LogMessages $LogMessages
        $hasFailed = -not $ok
        if ($hasFailed) { $isAllOk = $false }

        $ok = Configure-GoEnv -GoEnvConfig $Config.goEnv -GopathFull $gopathFull -LogMessages $LogMessages
        $hasFailed = -not $ok
        if ($hasFailed) { $isAllOk = $false }

        Save-ResolvedData -ScriptFolder "06-install-golang" -Data @{
            golang = @{
                gopath     = $gopathFull
                version    = "$(& go.exe version 2>&1)".Trim()
                resolvedAt = (Get-Date -Format "o")
                resolvedBy = $env:USERNAME
            }
        }
    }

    return $isAllOk
}
