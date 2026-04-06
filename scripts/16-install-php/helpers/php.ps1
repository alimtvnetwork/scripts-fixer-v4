<#
.SYNOPSIS
    PHP install helper for script 16.
#>

$_sharedDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "shared"
$_loggingPath = Join-Path $_sharedDir "logging.ps1"
if ((Test-Path $_loggingPath) -and -not (Get-Command Write-Log -ErrorAction SilentlyContinue)) {
    . $_loggingPath
}
$_chocoUtilsPath = Join-Path $_sharedDir "choco-utils.ps1"
if ((Test-Path $_chocoUtilsPath) -and -not (Get-Command Install-ChocoPackage -ErrorAction SilentlyContinue)) {
    . $_chocoUtilsPath
}

function Install-Php {
    param(
        [PSCustomObject]$Config,
        $LogMessages
    )

    $isDisabled = -not $Config.enabled
    if ($isDisabled) {
        Write-Log $LogMessages.messages.phpDisabled -Level "info"
        return $true
    }

    Write-Log $LogMessages.messages.phpChecking -Level "info"
    $phpCmd = Get-Command $Config.verifyCommand -ErrorAction SilentlyContinue

    if ($phpCmd) {
        $version = & $Config.verifyCommand $Config.versionFlag 2>&1 | Select-Object -First 1
        $versionStr = "$version".Trim()

        # Check .installed/ tracking
        $isAlreadyTracked = Test-AlreadyInstalled -Name "php" -CurrentVersion $versionStr
        if ($isAlreadyTracked) {
            Write-Log ($LogMessages.messages.phpFound -replace '\{version\}', $version) -Level "info"
            return $true
        }

        Write-Log ($LogMessages.messages.phpFound -replace '\{version\}', $version) -Level "success"
        Save-InstalledRecord -Name "php" -Version $versionStr

        Save-ResolvedData -ScriptFolder "16-install-php" -Data @{
            php = @{
                version    = $versionStr
                resolvedAt = (Get-Date -Format "o")
                resolvedBy = $env:USERNAME
            }
        }

        return $true
    }

    Write-Log $LogMessages.messages.phpNotFound -Level "warn"
    Write-Log $LogMessages.messages.phpInstalling -Level "info"

    try {
        $isInstalled = Install-ChocoPackage -PackageName $Config.chocoPackage
        $hasInstallFailed = -not $isInstalled
        if ($hasInstallFailed) {
            Write-Log ($LogMessages.messages.phpInstallFailed -replace '\{error\}', "Chocolatey install returned failure") -Level "error"
            Save-InstalledError -Name "php" -ErrorMessage "Chocolatey install returned failure"
            return $false
        }
    } catch {
        Write-Log ($LogMessages.messages.phpInstallFailed -replace '\{error\}', $_) -Level "error"
        Save-InstalledError -Name "php" -ErrorMessage "$_"
        return $false
    }

    $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")

    $phpCmd = Get-Command $Config.verifyCommand -ErrorAction SilentlyContinue
    if ($phpCmd) {
        $version = & $Config.verifyCommand $Config.versionFlag 2>&1 | Select-Object -First 1
        $versionStr = "$version".Trim()
        Write-Log ($LogMessages.messages.phpInstallSuccess -replace '\{version\}', $version) -Level "success"
        Save-InstalledRecord -Name "php" -Version $versionStr

        Save-ResolvedData -ScriptFolder "16-install-php" -Data @{
            php = @{
                version    = $versionStr
                resolvedAt = (Get-Date -Format "o")
                resolvedBy = $env:USERNAME
            }
        }

        return $true
    } else {
        Write-Log $LogMessages.messages.phpNotInPath -Level "warn"
        return $false
    }
}
