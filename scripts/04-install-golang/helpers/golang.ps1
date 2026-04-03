<#
.SYNOPSIS
    Go installation, GOPATH resolution, PATH management, and go env configuration.

.DESCRIPTION
    Adapted from user's existing go-install.ps1. Uses shared helpers for
    Chocolatey, PATH manipulation, and dev directory resolution.
#>

function Install-Go {
    <#
    .SYNOPSIS
        Installs or upgrades Go via Chocolatey.
    #>
    param(
        [PSCustomObject]$Config
    )

    $packageName = if ($Config.chocoPackageName) { $Config.chocoPackageName } else { "golang" }
    Write-Log "Chocolatey package name: $packageName" "info"

    $goCmd = Get-Command go.exe -ErrorAction SilentlyContinue

    if (-not $goCmd) {
        Write-Log "Go is not installed -- installing via Chocolatey..." "info"
        $ok = Install-ChocoPackage -PackageName $packageName
        if (-not $ok) { return $false }

        # Refresh PATH so go.exe is available in this session
        $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
        $goCmd = Get-Command go.exe -ErrorAction SilentlyContinue
        if (-not $goCmd) {
            Write-Log "Go installed but go.exe not found in PATH -- may need a new terminal" "warn"
            return $false
        }
    } else {
        Write-Log "Go is already installed" "ok"
        if ($Config.alwaysUpgradeToLatest) {
            Upgrade-ChocoPackage -PackageName $packageName | Out-Null
        }
    }

    $version = & go.exe version 2>&1
    Write-Log "Go version: $version" "ok"
    return $true
}

function Resolve-Gopath {
    <#
    .SYNOPSIS
        Resolves GOPATH from config (override, prompt, or default).
        If $env:DEV_DIR is set (by orchestrator), uses that as base.
    #>
    param(
        [PSCustomObject]$GopathConfig,
        [string]$DevDirSubfolder
    )

    # If orchestrator set DEV_DIR, derive GOPATH from it
    if (-not [string]::IsNullOrWhiteSpace($env:DEV_DIR) -and $DevDirSubfolder) {
        $derived = Join-Path $env:DEV_DIR $DevDirSubfolder
        Write-Log "Using GOPATH derived from DEV_DIR: $derived" "ok"
        return $derived
    }

    if (-not $GopathConfig) {
        $fallback = "E:\dev\go"
        Write-Log "No gopath config -- using fallback: $fallback" "warn"
        return $fallback
    }

    $default  = if ($GopathConfig.default)  { $GopathConfig.default }  else { "E:\dev\go" }
    $override = if ($GopathConfig.override) { $GopathConfig.override } else { "" }

    if (-not [string]::IsNullOrWhiteSpace($override)) {
        Write-Log "Using GOPATH override from config: $override" "info"
        return $override
    }

    if ($GopathConfig.mode -eq "json-only") {
        Write-Log "GOPATH mode is 'json-only': $default" "info"
        return $default
    }

    # Prompt mode
    $userInput = Read-Host -Prompt "Enter GOPATH (default: $default)"
    if (-not [string]::IsNullOrWhiteSpace($userInput)) {
        Write-Log "User provided GOPATH: $userInput" "info"
        return $userInput
    }

    Write-Log "Using default GOPATH: $default" "info"
    return $default
}

function Initialize-Gopath {
    <#
    .SYNOPSIS
        Creates GOPATH directory and sets the environment variable.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$GopathValue
    )

    $gopathFull = [System.IO.Path]::GetFullPath($GopathValue)
    Write-Log "Resolved GOPATH to: $gopathFull" "info"

    if (-not (Test-Path $gopathFull)) {
        Write-Log "Creating GOPATH directory: $gopathFull" "info"
        New-Item -Path $gopathFull -ItemType Directory -Force -Confirm:$false | Out-Null
        Write-Log "GOPATH directory created" "ok"
    }

    # Set user environment variable
    try {
        Write-Log "Setting user env GOPATH=$gopathFull" "info"
        [Environment]::SetEnvironmentVariable("GOPATH", $gopathFull, "User")
        $env:GOPATH = $gopathFull
        Write-Log "GOPATH set successfully" "ok"
    } catch {
        Write-Log "Failed to set GOPATH: $_" "fail"
        return $null
    }

    return $gopathFull
}

function Update-GoPath {
    <#
    .SYNOPSIS
        Adds GOPATH\bin to user PATH if configured.
    #>
    param(
        [PSCustomObject]$PathConfig,
        [string]$GopathFull
    )

    if (-not $PathConfig.updateUserPath) {
        Write-Log "User PATH update is disabled in config" "skip"
        return $true
    }

    $goBin = Join-Path $GopathFull "bin"

    if (-not (Test-Path $goBin)) {
        Write-Log "Creating Go bin directory: $goBin" "info"
        New-Item -Path $goBin -ItemType Directory -Force -Confirm:$false | Out-Null
    }

    if ($PathConfig.ensureGoBinInPath) {
        return (Add-ToUserPath -Directory $goBin)
    }

    return $true
}

function Set-GoEnvSetting {
    <#
    .SYNOPSIS
        Runs 'go env -w KEY=VALUE' with logging.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Key,

        [Parameter(Mandatory)]
        [string]$Value
    )

    Write-Log "Running: go env -w $Key=$Value" "info"
    try {
        & go.exe env -w "$Key=$Value" 2>&1 | ForEach-Object {
            if ($_ -and $_.ToString().Trim().Length -gt 0) { Write-Log $_ "info" }
        }
        if ($LASTEXITCODE -ne 0) {
            Write-Log "go env -w failed for $Key (exit code $LASTEXITCODE)" "warn"
            return $false
        }
        Write-Log "go env $Key set" "ok"
        return $true
    } catch {
        Write-Log "Failed to set go env $Key -- $_" "fail"
        return $false
    }
}

function Configure-GoEnv {
    <#
    .SYNOPSIS
        Applies all go env settings from config (GOMODCACHE, GOCACHE, GOPROXY, etc.)
    #>
    param(
        [PSCustomObject]$GoEnvConfig,
        [string]$GopathFull
    )

    if (-not $GoEnvConfig -or -not $GoEnvConfig.settings) {
        Write-Log "No goEnv settings in config -- skipping" "skip"
        return $true
    }

    $settings = $GoEnvConfig.settings
    $relativeToGopath = $GoEnvConfig.relativeToGopath
    $allOk = $true

    foreach ($key in $settings.PSObject.Properties.Name) {
        $entry = $settings.$key

        if (-not $entry.enabled) {
            Write-Log "go env $key is disabled -- skipping" "skip"
            continue
        }

        $finalValue = $null

        # Resolve value: relative path or direct value
        if ($relativeToGopath -and ($entry.PSObject.Properties.Name -contains "relativePath")) {
            $rel = $entry.relativePath
            if ([string]::IsNullOrWhiteSpace($rel)) {
                Write-Log "go env $key has empty relativePath -- skipping" "warn"
                continue
            }

            $absolutePath = Join-Path $GopathFull $rel
            if (-not (Test-Path $absolutePath)) {
                Write-Log "Creating directory for $key -- $absolutePath" "info"
                New-Item -Path $absolutePath -ItemType Directory -Force -Confirm:$false | Out-Null
            }
            $finalValue = $absolutePath
        } elseif ($entry.PSObject.Properties.Name -contains "value") {
            $finalValue = $entry.value
        }

        # Prompt if configured
        if ($GoEnvConfig.applyMode -eq "json-or-prompt" -and $entry.promptOnFirstRun) {
            $userInput = Read-Host -Prompt "Enter value for $key (default: $finalValue)"
            if (-not [string]::IsNullOrWhiteSpace($userInput)) {
                $finalValue = $userInput
                Write-Log "User provided value for $key -- $finalValue" "info"
            }
        }

        if (-not [string]::IsNullOrWhiteSpace($finalValue)) {
            $ok = Set-GoEnvSetting -Key $key -Value $finalValue
            if (-not $ok) { $allOk = $false }
        } else {
            Write-Log "No value resolved for go env $key -- skipping" "warn"
        }
    }

    return $allOk
}

function Invoke-GoSetup {
    <#
    .SYNOPSIS
        Full Go setup: install, GOPATH, PATH, go env.
    #>
    param(
        [PSCustomObject]$Config,
        [string]$ScriptDir,
        [string]$Command
    )

    $allOk = $true

    # Install/upgrade
    if ($Command -ne "configure") {
        $ok = Install-Go -Config $Config
        if (-not $ok) {
            Write-Log "Go install failed -- cannot continue" "fail"
            return $false
        }
    }

    # Configure (skip if command is "install" only)
    if ($Command -ne "install") {
        # Resolve GOPATH
        $gopathValue = Resolve-Gopath -GopathConfig $Config.gopath -DevDirSubfolder $Config.devDirSubfolder
        $gopathFull = Initialize-Gopath -GopathValue $gopathValue

        if (-not $gopathFull) {
            Write-Log "Failed to initialize GOPATH" "fail"
            return $false
        }

        # Update PATH
        $ok = Update-GoPath -PathConfig $Config.path -GopathFull $gopathFull
        if (-not $ok) { $allOk = $false }

        # Configure go env
        $ok = Configure-GoEnv -GoEnvConfig $Config.goEnv -GopathFull $gopathFull
        if (-not $ok) { $allOk = $false }

        # Save resolved data
        Save-ResolvedData -ScriptDir $ScriptDir -Data @{
            golang = @{
                gopath     = $gopathFull
                version    = "$(& go.exe version 2>&1)".Trim()
                resolvedAt = (Get-Date -Format "o")
                resolvedBy = $env:USERNAME
            }
        }
    }

    return $allOk
}
