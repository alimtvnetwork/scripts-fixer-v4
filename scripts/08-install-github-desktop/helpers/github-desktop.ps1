# --------------------------------------------------------------------------
#  GitHub Desktop helper functions
# --------------------------------------------------------------------------

# -- Bootstrap shared helpers --------------------------------------------------
$_sharedDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "shared"
$_loggingPath = Join-Path $_sharedDir "logging.ps1"
if ((Test-Path $_loggingPath) -and -not (Get-Command Write-Log -ErrorAction SilentlyContinue)) {
    . $_loggingPath
}


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
        # Get version from choco list
        $chocoVersion = (choco list --local-only --exact $packageName 2>&1 | Select-String $packageName) -replace ".*$packageName\s*", "" | ForEach-Object { $_.Trim() }

        # Check .installed/ tracking
        $isAlreadyTracked = $chocoVersion -and (Test-AlreadyInstalled -Name "github-desktop" -CurrentVersion $chocoVersion)
        if ($isAlreadyTracked) {
            Write-Log $LogMessages.messages.ghDesktopAlreadyInstalled -Level "info"
            return
        }

        Write-Log $LogMessages.messages.ghDesktopAlreadyInstalled -Level "info"

        if ($Config.alwaysUpgradeToLatest) {
            Write-Log $LogMessages.messages.ghDesktopUpgrading -Level "info"
            Upgrade-ChocoPackage -PackageName $packageName
            Write-Log $LogMessages.messages.ghDesktopUpgradeSuccess -Level "success"
        }

        $newVersion = (choco list --local-only --exact $packageName 2>&1 | Select-String $packageName) -replace ".*$packageName\s*", "" | ForEach-Object { $_.Trim() }
        if ($newVersion) { Save-InstalledRecord -Name "github-desktop" -Version $newVersion }
    }
    else {
        Write-Log $LogMessages.messages.ghDesktopNotFound -Level "warn"
        Install-ChocoPackage -PackageName $packageName
        Write-Log $LogMessages.messages.ghDesktopInstallSuccess -Level "success"

        $newVersion = (choco list --local-only --exact $packageName 2>&1 | Select-String $packageName) -replace ".*$packageName\s*", "" | ForEach-Object { $_.Trim() }
        if ($newVersion) { Save-InstalledRecord -Name "github-desktop" -Version $newVersion }
    }
}
