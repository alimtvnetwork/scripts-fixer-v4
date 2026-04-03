# --------------------------------------------------------------------------
#  Node.js helper functions
# --------------------------------------------------------------------------

function Install-NodeJs {
    param(
        $Config,
        $LogMessages
    )

    $packageName = $Config.chocoPackageName

    # Check if Node.js is already installed
    $existing = Get-Command node -ErrorAction SilentlyContinue
    if ($existing) {
        $currentVersion = & node --version 2>$null
        Write-Log ($LogMessages.messages.nodeAlreadyInstalled -replace '\{version\}', $currentVersion) -Level "info"

        if ($Config.alwaysUpgradeToLatest) {
            Upgrade-ChocoPackage -PackageName $packageName
            $newVersion = & node --version 2>$null
            Write-Log ($LogMessages.messages.nodeUpgradeSuccess -replace '\{version\}', $newVersion) -Level "success"
        }
    }
    else {
        Write-Log $LogMessages.messages.nodeNotFound -Level "warn"
        Install-ChocoPackage -PackageName $packageName
        
        # Refresh PATH so node is discoverable
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
        
        $installedVersion = & node --version 2>$null
        Write-Log ($LogMessages.messages.nodeInstallSuccess -replace '\{version\}', $installedVersion) -Level "success"
    }
}

function Configure-NpmPrefix {
    param(
        $Config,
        $LogMessages,
        [string]$DevDir
    )

    $npmConfig = $Config.npm
    if (-not $npmConfig.setGlobalPrefix) { return }

    # Resolve prefix path
    $prefixPath = if ($DevDir) {
        Join-Path $DevDir $Config.devDirSubfolder
    } else {
        $npmConfig.globalPrefix
    }

    # Ensure directory exists
    if (-not (Test-Path $prefixPath)) {
        New-Item -Path $prefixPath -ItemType Directory -Force | Out-Null
    }

    # Check current prefix
    $currentPrefix = & npm config get prefix 2>$null
    if ($currentPrefix -eq $prefixPath) {
        Write-Log ($LogMessages.messages.npmPrefixAlreadySet -replace '\{path\}', $prefixPath) -Level "info"
    }
    else {
        Write-Log ($LogMessages.messages.configuringNpmPrefix -replace '\{path\}', $prefixPath) -Level "info"
        & npm config set prefix $prefixPath
        Write-Log ($LogMessages.messages.npmPrefixSet -replace '\{path\}', $prefixPath) -Level "success"
    }

    return $prefixPath
}

function Update-NodePath {
    param(
        $Config,
        $LogMessages,
        [string]$PrefixPath
    )

    if (-not $Config.path.updateUserPath) { return }
    if (-not $PrefixPath) { return }

    # npm installs global bins directly into the prefix on Windows
    if (Test-InPath -Directory $PrefixPath) {
        Write-Log ($LogMessages.messages.pathAlreadyContains -replace '\{path\}', $PrefixPath) -Level "info"
    }
    else {
        Write-Log ($LogMessages.messages.addingToPath -replace '\{path\}', $PrefixPath) -Level "info"
        Add-ToUserPath -Directory $PrefixPath
    }

    # Also ensure node_modules/.bin if needed
    if ($Config.path.ensureNpmBinInPath) {
        $nodeModulesBin = Join-Path $PrefixPath "node_modules\.bin"
        if ((Test-Path $nodeModulesBin) -and -not (Test-InPath -Directory $nodeModulesBin)) {
            Add-ToUserPath -Directory $nodeModulesBin
        }
    }
}
