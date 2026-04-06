# --------------------------------------------------------------------------
#  pnpm helper functions
# --------------------------------------------------------------------------

# -- Bootstrap shared helpers --------------------------------------------------
$_sharedDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "shared"
$_loggingPath = Join-Path $_sharedDir "logging.ps1"
if ((Test-Path $_loggingPath) -and -not (Get-Command Write-Log -ErrorAction SilentlyContinue)) {
    . $_loggingPath
}


function Install-Pnpm {
    param(
        $Config,
        $LogMessages
    )

    # Ensure npm is available
    $hasNpm = Get-Command npm -ErrorAction SilentlyContinue
    $isNpmMissing = -not $hasNpm
    if ($isNpmMissing) {
        Write-Log $LogMessages.messages.nodeRequired -Level "error"
        throw "npm is not available. Install Node.js first (script 06)."
    }

    $existing = Get-Command pnpm -ErrorAction SilentlyContinue
    if ($existing) {
        $currentVersion = & pnpm --version 2>$null

        # Check .installed/ tracking -- skip if version matches
        $isAlreadyTracked = Test-AlreadyInstalled -Name "pnpm" -CurrentVersion $currentVersion
        if ($isAlreadyTracked) {
            Write-Log ($LogMessages.messages.pnpmAlreadyInstalled -replace '\{version\}', $currentVersion) -Level "info"
            return
        }

        Write-Log ($LogMessages.messages.pnpmAlreadyInstalled -replace '\{version\}', $currentVersion) -Level "info"

        # Upgrade to latest
        Write-Log $LogMessages.messages.pnpmUpgrading -Level "info"
        try {
            & npm install -g pnpm@latest 2>$null
            $newVersion = & pnpm --version 2>$null
            Write-Log ($LogMessages.messages.pnpmUpgradeSuccess -replace '\{version\}', $newVersion) -Level "success"
            Save-InstalledRecord -Name "pnpm" -Version $newVersion -Method "npm"
        } catch {
            Write-Log "pnpm upgrade failed: $_" -Level "error"
            Save-InstalledError -Name "pnpm" -ErrorMessage "$_" -Method "npm"
        }
    }
    else {
        Write-Log $LogMessages.messages.pnpmNotFound -Level "warn"
        try {
            # Refresh PATH so the updated npm prefix from script 03 is visible
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
            & npm install -g pnpm 2>$null

            # Refresh PATH
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

            $installedVersion = & pnpm --version 2>$null
            Write-Log ($LogMessages.messages.pnpmInstallSuccess -replace '\{version\}', $installedVersion) -Level "success"
            Save-InstalledRecord -Name "pnpm" -Version $installedVersion -Method "npm"
        } catch {
            Write-Log "pnpm install failed: $_" -Level "error"
            Save-InstalledError -Name "pnpm" -ErrorMessage "$_" -Method "npm"
        }
    }
}

function Configure-PnpmStore {
    param(
        $Config,
        $LogMessages,
        [string]$DevDir
    )

    $storeConfig = $Config.store
    $isStorePathDisabled = -not $storeConfig.setStorePath
    if ($isStorePathDisabled) { return }

    # Resolve store path
    $storePath = if ($DevDir) {
        Join-Path (Join-Path $DevDir $Config.devDirSubfolder) "store"
    } else {
        $storeConfig.storePath
    }

    # Ensure directory exists
    $isDirMissing = -not (Test-Path $storePath)
    if ($isDirMissing) {
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
        $Config,
        $LogMessages
    )

    $isPathUpdateDisabled = -not $Config.path.updateUserPath
    if ($isPathUpdateDisabled) { return }

    # pnpm global bin directory
    $pnpmHome = & pnpm config get global-bin-dir 2>$null
    $hasPnpmHome = [bool]$pnpmHome
    $isPnpmHomeMissing = -not $hasPnpmHome
    if ($isPnpmHomeMissing) {
        # Fallback: use PNPM_HOME or default location
        $pnpmHome = if ($env:PNPM_HOME) { $env:PNPM_HOME }
                    else { Join-Path $env:LOCALAPPDATA "pnpm" }
    }

    $isAlreadyInPath = Test-InPath -Directory $pnpmHome
    if ($isAlreadyInPath) {
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
