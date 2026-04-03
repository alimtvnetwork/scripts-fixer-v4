# --------------------------------------------------------------------------
#  GitHub Desktop helper functions
# --------------------------------------------------------------------------

function Install-GitHubDesktop {
    param(
        $Config,
        $LogMessages
    )

    $packageName = $Config.chocoPackageName

    # GitHub Desktop installs to AppData -- check common locations
    $ghDesktop = Get-Command "GitHubDesktop" -ErrorAction SilentlyContinue
    $isCommandMissing = -not $ghDesktop
    if ($isCommandMissing) {
        $localAppPath = Join-Path $env:LOCALAPPDATA "GitHubDesktop\GitHubDesktop.exe"
        $isLocalAppFound = Test-Path $localAppPath
        if ($isLocalAppFound) { $ghDesktop = $true }
    }

    if ($ghDesktop) {
        Write-Log $LogMessages.messages.ghDesktopAlreadyInstalled -Level "info"

        if ($Config.alwaysUpgradeToLatest) {
            Write-Log $LogMessages.messages.ghDesktopUpgrading -Level "info"
            Upgrade-ChocoPackage -PackageName $packageName
            Write-Log $LogMessages.messages.ghDesktopUpgradeSuccess -Level "success"
        }
    }
    else {
        Write-Log $LogMessages.messages.ghDesktopNotFound -Level "warn"
        Install-ChocoPackage -PackageName $packageName
        Write-Log $LogMessages.messages.ghDesktopInstallSuccess -Level "success"
    }
}
