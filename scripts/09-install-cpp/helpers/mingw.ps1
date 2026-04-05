<#
.SYNOPSIS
    MinGW-w64 installation, PATH management, and command verification.

.DESCRIPTION
    Installs MinGW-w64 C++ toolchain via Chocolatey. Verifies g++, gcc, and
    mingw32-make are reachable. Adds bin directory to user PATH.
#>

# -- Bootstrap shared helpers --------------------------------------------------
$_sharedDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "shared"
$_loggingPath = Join-Path $_sharedDir "logging.ps1"
if ((Test-Path $_loggingPath) -and -not (Get-Command Write-Log -ErrorAction SilentlyContinue)) {
    . $_loggingPath
}


function Resolve-MingwInstallDir {
    <#
    .SYNOPSIS
        Resolves install directory from config, DEV_DIR, or prompt.
    #>
    param(
        [PSCustomObject]$InstallDirConfig,
        $LogMessages
    )

    # If orchestrator set DEV_DIR, derive install dir from it
    $hasDevDir = -not [string]::IsNullOrWhiteSpace($env:DEV_DIR)
    if ($hasDevDir) {
        $derived = Join-Path $env:DEV_DIR "mingw-w64"
        Write-Log ($LogMessages.messages.installDirFromDevDir -replace '\{path\}', $derived) -Level "success"
        return $derived
    }

    $hasNoConfig = -not $InstallDirConfig
    if ($hasNoConfig) {
        $fallback = "C:\mingw-w64"
        Write-Log ($LogMessages.messages.installDirDefault -replace '\{path\}', $fallback) -Level "info"
        return $fallback
    }

    $default  = if ($InstallDirConfig.default)  { $InstallDirConfig.default }  else { "C:\mingw-w64" }
    $override = if ($InstallDirConfig.override) { $InstallDirConfig.override } else { "" }

    $hasOverride = -not [string]::IsNullOrWhiteSpace($override)
    if ($hasOverride) {
        Write-Log ($LogMessages.messages.installDirOverride -replace '\{path\}', $override) -Level "info"
        return $override
    }

    if ($InstallDirConfig.mode -eq "json-only") {
        Write-Log ($LogMessages.messages.installDirDefault -replace '\{path\}', $default) -Level "info"
        return $default
    }

    # Skip prompt if orchestrator set DEV_DIR (use default)
    $hasOrchestratorEnv = -not [string]::IsNullOrWhiteSpace($env:SCRIPTS_ROOT_RUN)
    $isPromptMode = $InstallDirConfig.mode -ne "json-only" -and -not $hasOrchestratorEnv

    if ($isPromptMode) {
        $userInput = Read-Host -Prompt "Enter MinGW install directory (default: $default)"
        $hasUserInput = -not [string]::IsNullOrWhiteSpace($userInput)
        if ($hasUserInput) {
            Write-Log ($LogMessages.messages.installDirUserProvided -replace '\{path\}', $userInput) -Level "info"
            return $userInput
        }
    }
    return $default
}

function Install-Mingw {
    <#
    .SYNOPSIS
        Installs or upgrades MinGW-w64 via Chocolatey.
    #>
    param(
        [PSCustomObject]$Config,
        $LogMessages
    )

    $packageName = if ($Config.chocoPackageName) { $Config.chocoPackageName } else { "mingw" }
    Write-Log ($LogMessages.messages.chocoPackageName -replace '\{name\}', $packageName) -Level "info"

    $gppCmd = Get-Command g++.exe -ErrorAction SilentlyContinue

    $isMissing = -not $gppCmd
    if ($isMissing) {
        Write-Log $LogMessages.messages.mingwNotInstalled -Level "info"
        $ok = Install-ChocoPackage -PackageName $packageName
        $hasFailed = -not $ok
        if ($hasFailed) { return $false }

        # Refresh PATH so g++ is available in this session
        $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
        $gppCmd = Get-Command g++.exe -ErrorAction SilentlyContinue
        $isStillMissing = -not $gppCmd
        if ($isStillMissing) {
            Write-Log $LogMessages.messages.mingwNotInPath -Level "warn"
            return $false
        }
    } else {
        Write-Log $LogMessages.messages.mingwAlreadyInstalled -Level "success"
        if ($Config.alwaysUpgradeToLatest) {
            Upgrade-ChocoPackage -PackageName $packageName | Out-Null
        }
    }

    $version = & g++.exe --version 2>&1 | Select-Object -First 1
    Write-Log ($LogMessages.messages.mingwVersion -replace '\{version\}', $version) -Level "success"
    return $true
}

function Test-MingwCommands {
    <#
    .SYNOPSIS
        Verifies that required commands (g++, gcc, mingw32-make) are in PATH.
    #>
    param(
        [string[]]$Commands,
        $LogMessages
    )

    $isAllOk = $true

    foreach ($cmd in $Commands) {
        Write-Log ($LogMessages.messages.verifyingCommand -replace '\{command\}', $cmd) -Level "info"
        $found = Get-Command "$cmd.exe" -ErrorAction SilentlyContinue
        $isMissing = -not $found
        if ($isMissing) {
            # Try without .exe
            $found = Get-Command $cmd -ErrorAction SilentlyContinue
            $isMissing = -not $found
        }
        if ($isMissing) {
            Write-Log ($LogMessages.messages.verifyFailed -replace '\{command\}', $cmd) -Level "warn"
            $isAllOk = $false
        } else {
            Write-Log ($LogMessages.messages.verifySuccess -replace '\{command\}', $cmd) -Level "success"
        }
    }

    return $isAllOk
}

function Update-MingwPath {
    <#
    .SYNOPSIS
        Adds MinGW bin directory to user PATH if configured.
    #>
    param(
        [PSCustomObject]$PathConfig,
        $LogMessages
    )

    $isPathUpdateDisabled = -not $PathConfig.updateUserPath
    if ($isPathUpdateDisabled) {
        Write-Log $LogMessages.messages.pathUpdateDisabled -Level "info"
        return $true
    }

    # Find the g++ location and derive the bin directory
    $gppCmd = Get-Command g++.exe -ErrorAction SilentlyContinue
    $hasGpp = [bool]$gppCmd
    if ($hasGpp) {
        $binDir = Split-Path -Parent $gppCmd.Source
        $ok = Add-ToUserPath -Directory $binDir
        if ($ok) {
            Write-Log $LogMessages.messages.pathUpdated -Level "success"
        }
        return $ok
    }

    return $true
}

function Invoke-MingwSetup {
    <#
    .SYNOPSIS
        Full MinGW setup: install, verify, PATH.
    #>
    param(
        [PSCustomObject]$Config,
        [string]$ScriptDir,
        [string]$Command,
        $LogMessages
    )

    $isAllOk = $true

    # Install/upgrade
    $isNotConfigureOnly = $Command -ne "configure"
    if ($isNotConfigureOnly) {
        $ok = Install-Mingw -Config $Config -LogMessages $LogMessages
        $hasFailed = -not $ok
        if ($hasFailed) {
            Write-Log $LogMessages.messages.installFailed -Level "error"
            return $false
        }
    }

    # Configure (skip if command is "install" only)
    $isNotInstallOnly = $Command -ne "install"
    if ($isNotInstallOnly) {
        # Verify commands
        $verifyCommands = if ($Config.verifyCommands) { $Config.verifyCommands } else { @("g++", "gcc", "mingw32-make") }
        $ok = Test-MingwCommands -Commands $verifyCommands -LogMessages $LogMessages
        $hasFailed = -not $ok
        if ($hasFailed) { $isAllOk = $false }

        # Update PATH
        $ok = Update-MingwPath -PathConfig $Config.path -LogMessages $LogMessages
        $hasFailed = -not $ok
        if ($hasFailed) { $isAllOk = $false }

        # Save resolved data
        $gppVersion = ""
        $gppCmd = Get-Command g++.exe -ErrorAction SilentlyContinue
        $hasGpp = [bool]$gppCmd
        if ($hasGpp) {
            $gppVersion = "$(& g++.exe --version 2>&1 | Select-Object -First 1)".Trim()
        }

        Save-ResolvedData -ScriptFolder "09-install-cpp" -Data @{
            cpp = @{
                version    = $gppVersion
                resolvedAt = (Get-Date -Format "o")
                resolvedBy = $env:USERNAME
            }
        }
    }

    return $isAllOk
}
