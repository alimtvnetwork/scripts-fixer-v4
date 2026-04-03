# --------------------------------------------------------------------------
#  pnpm helper functions
# --------------------------------------------------------------------------

function Install-Pnpm {
    param(
        [hashtable]$Config,
        [hashtable]$LogMessages
    )

    # Ensure npm is available
    $npmExists = Get-Command npm -ErrorAction SilentlyContinue
    if (-not $npmExists) {
        Write-Log $LogMessages.messages.nodeRequired -Level "error"
        throw "npm is not available. Install Node.js first (script 05)."
    }

    $existing = Get-Command pnpm -ErrorAction SilentlyContinue
    if ($existing) {
        $currentVersion = & pnpm --version 2>$null
        Write-Log ($LogMessages.messages.pnpmAlreadyInstalled -replace '\{version\}', $currentVersion) -Level "info"

        # Upgrade to latest
        Write-Log "Upgrading pnpm to latest..." -Level "info"
        & npm install -g pnpm@latest 2>$null
        $newVersion = & pnpm --version 2>$null
        Write-Log ($LogMessages.messages.pnpmUpgradeSuccess -replace '\{version\}', $newVersion) -Level "success"
    }
    else {
        Write-Log $LogMessages.messages.pnpmNotFound -Level "warn"
        & npm install -g pnpm 2>$null

        # Refresh PATH
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

        $installedVersion = & pnpm --version 2>$null
        Write-Log ($LogMessages.messages.pnpmInstallSuccess -replace '\{version\}', $installedVersion) -Level "success"
    }
}

function Configure-PnpmStore {
    param(
        [hashtable]$Config,
        [hashtable]$LogMessages,
        [string]$DevDir
    )

    $storeConfig = $Config.store
    if (-not $storeConfig.setStorePath) { return }

    # Resolve store path
    $storePath = if ($DevDir) {
        Join-Path (Join-Path $DevDir $Config.devDirSubfolder) "store"
    } else {
        $storeConfig.storePath
    }

    # Ensure directory exists
    if (-not (Test-Path $storePath)) {
        New-Item -Path $storePath -ItemType Directory -Force | Out-Null
    }

    # Check current store dir
    $currentStore = & pnpm config get store-dir 2>$null
    if ($currentStore -eq $storePath) {
        Write-Log ($LogMessages.messages.storeAlreadySet -replace '\{path\}', $storePath) -Level "info"
    }
    else {
        Write-Log ($LogMessages.messages.configuringStore -replace '\{path\}', $storePath) -Level "info"
        & pnpm config set store-dir $storePath
        Write-Log ($LogMessages.messages.storeSet -replace '\{path\}', $storePath) -Level "success"
    }

    return $storePath
}

function Update-PnpmPath {
    param(
        [hashtable]$Config,
        [hashtable]$LogMessages
    )

    if (-not $Config.path.updateUserPath) { return }

    # pnpm global bin directory
    $pnpmHome = & pnpm config get global-bin-dir 2>$null
    if (-not $pnpmHome) {
        # Fallback: use PNPM_HOME or default location
        $pnpmHome = if ($env:PNPM_HOME) { $env:PNPM_HOME }
                    else { Join-Path $env:LOCALAPPDATA "pnpm" }
    }

    if (Test-InPath -Directory $pnpmHome) {
        Write-Log ($LogMessages.messages.pathAlreadyContains -replace '\{path\}', $pnpmHome) -Level "info"
    }
    else {
        Write-Log ($LogMessages.messages.addingToPath -replace '\{path\}', $pnpmHome) -Level "info"
        Add-ToUserPath -Directory $pnpmHome

        # Also set PNPM_HOME env var
        [System.Environment]::SetEnvironmentVariable("PNPM_HOME", $pnpmHome, "User")
        $env:PNPM_HOME = $pnpmHome
    }
}
