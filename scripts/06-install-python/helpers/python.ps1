# --------------------------------------------------------------------------
#  Python helper functions
# --------------------------------------------------------------------------

function Install-Python {
    param(
        [hashtable]$Config,
        [hashtable]$LogMessages
    )

    $packageName = $Config.chocoPackageName

    $existing = Get-Command python -ErrorAction SilentlyContinue
    if ($existing) {
        $currentVersion = & python --version 2>$null
        Write-Log ($LogMessages.messages.pythonAlreadyInstalled -replace '\{version\}', $currentVersion) -Level "info"

        if ($Config.alwaysUpgradeToLatest) {
            Upgrade-ChocoPackage -PackageName $packageName
            $newVersion = & python --version 2>$null
            Write-Log ($LogMessages.messages.pythonUpgradeSuccess -replace '\{version\}', $newVersion) -Level "success"
        }
    }
    else {
        Write-Log $LogMessages.messages.pythonNotFound -Level "warn"
        Install-ChocoPackage -PackageName $packageName

        # Refresh PATH
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

        $installedVersion = & python --version 2>$null
        Write-Log ($LogMessages.messages.pythonInstallSuccess -replace '\{version\}', $installedVersion) -Level "success"
    }
}

function Configure-PipSite {
    param(
        [hashtable]$Config,
        [hashtable]$LogMessages,
        [string]$DevDir
    )

    $pipConfig = $Config.pip
    if (-not $pipConfig.setUserSite) { return }

    # Resolve site path
    $sitePath = if ($DevDir) {
        Join-Path $DevDir $Config.devDirSubfolder
    } else {
        $pipConfig.userSitePath
    }

    # Ensure directory exists
    if (-not (Test-Path $sitePath)) {
        New-Item -Path $sitePath -ItemType Directory -Force | Out-Null
    }

    # Set PYTHONUSERBASE environment variable (controls pip install --user target)
    $currentBase = [System.Environment]::GetEnvironmentVariable("PYTHONUSERBASE", "User")
    if ($currentBase -eq $sitePath) {
        Write-Log ($LogMessages.messages.pipSiteAlreadySet -replace '\{path\}', $sitePath) -Level "info"
    }
    else {
        Write-Log ($LogMessages.messages.configuringPipSite -replace '\{path\}', $sitePath) -Level "info"
        [System.Environment]::SetEnvironmentVariable("PYTHONUSERBASE", $sitePath, "User")
        $env:PYTHONUSERBASE = $sitePath
        Write-Log ($LogMessages.messages.pipSiteSet -replace '\{path\}', $sitePath) -Level "success"
    }

    return $sitePath
}

function Update-PythonPath {
    param(
        [hashtable]$Config,
        [hashtable]$LogMessages,
        [string]$SitePath
    )

    if (-not $Config.path.updateUserPath) { return }
    if (-not $SitePath) { return }

    # Python user Scripts directory
    $scriptsDir = Join-Path $SitePath "Scripts"

    if (-not (Test-Path $scriptsDir)) {
        New-Item -Path $scriptsDir -ItemType Directory -Force | Out-Null
    }

    if (Test-InPath -Directory $scriptsDir) {
        Write-Log ($LogMessages.messages.pathAlreadyContains -replace '\{path\}', $scriptsDir) -Level "info"
    }
    else {
        Write-Log ($LogMessages.messages.addingToPath -replace '\{path\}', $scriptsDir) -Level "info"
        Add-ToUserPath -Directory $scriptsDir
    }
}
