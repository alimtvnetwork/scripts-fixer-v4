<#
.SYNOPSIS
    PowerShell (pwsh) install helper for script 17.
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

function Install-PowerShellLatest {
    param(
        [PSCustomObject]$Config,
        $LogMessages
    )

    $isDisabled = -not $Config.enabled
    if ($isDisabled) {
        Write-Log $LogMessages.messages.pwshDisabled -Level "info"
        return $true
    }

    Write-Log $LogMessages.messages.pwshChecking -Level "info"
    $pwshCmd = Get-Command $Config.verifyCommand -ErrorAction SilentlyContinue

    if ($pwshCmd) {
        $version = & $Config.verifyCommand $Config.versionFlag 2>&1 | Select-Object -First 1
        $versionStr = "$version".Trim()

        # Check .installed/ tracking
        $isAlreadyTracked = Test-AlreadyInstalled -Name "powershell" -CurrentVersion $versionStr
        if ($isAlreadyTracked) {
            Write-Log ($LogMessages.messages.pwshFound -replace '\{version\}', $version) -Level "info"
            return $true
        }

        Write-Log ($LogMessages.messages.pwshFound -replace '\{version\}', $version) -Level "success"
        Save-InstalledRecord -Name "powershell" -Version $versionStr -Method "winget"

        Save-ResolvedData -ScriptFolder "17-install-powershell" -Data @{
            powershell = @{
                version    = $versionStr
                resolvedAt = (Get-Date -Format "o")
                resolvedBy = $env:USERNAME
            }
        }

        return $true
    }

    Write-Log $LogMessages.messages.pwshNotFound -Level "warn"

    # Try Winget first
    $wingetCmd = Get-Command winget.exe -ErrorAction SilentlyContinue
    $isWingetAvailable = $null -ne $wingetCmd

    if ($isWingetAvailable) {
        Write-Log ($LogMessages.messages.pwshInstallingWinget -replace '\{id\}', $Config.wingetId) -Level "info"
        try {
            $output = & winget.exe install --id $Config.wingetId --accept-source-agreements --accept-package-agreements 2>&1
            $hasWingetFailed = $LASTEXITCODE -ne 0
            if ($hasWingetFailed) {
                Write-Log ($LogMessages.messages.pwshInstallFailed -replace '\{error\}', ($output -join "`n")) -Level "warn"
            }
        } catch {
            Write-Log ($LogMessages.messages.pwshInstallFailed -replace '\{error\}', $_) -Level "warn"
        }
    }

    $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
    $pwshCmd = Get-Command $Config.verifyCommand -ErrorAction SilentlyContinue

    # Fallback to Chocolatey if Winget failed or unavailable
    $isPwshStillMissing = -not $pwshCmd
    if ($isPwshStillMissing) {
        Write-Log ($LogMessages.messages.pwshInstallingChoco -replace '\{package\}', $Config.fallbackChocoPackage) -Level "info"
        $isInstalled = Install-ChocoPackage -PackageName $Config.fallbackChocoPackage
        $hasChocoFailed = -not $isInstalled
        if ($hasChocoFailed) {
            Write-Log ($LogMessages.messages.pwshInstallFailed -replace '\{error\}', "Chocolatey install returned failure") -Level "error"
            return $false
        }

        $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
        $pwshCmd = Get-Command $Config.verifyCommand -ErrorAction SilentlyContinue
    }

    if ($pwshCmd) {
        $version = & $Config.verifyCommand $Config.versionFlag 2>&1 | Select-Object -First 1
        $versionStr = "$version".Trim()
        Write-Log ($LogMessages.messages.pwshInstallSuccess -replace '\{version\}', $version) -Level "success"

        $method = if ($isWingetAvailable) { "winget" } else { "chocolatey" }
        Save-InstalledRecord -Name "powershell" -Version $versionStr -Method $method

        Save-ResolvedData -ScriptFolder "17-install-powershell" -Data @{
            powershell = @{
                version    = $versionStr
                resolvedAt = (Get-Date -Format "o")
                resolvedBy = $env:USERNAME
            }
        }

        return $true
    } else {
        Write-Log $LogMessages.messages.pwshNotInPath -Level "warn"
        return $false
    }
}
