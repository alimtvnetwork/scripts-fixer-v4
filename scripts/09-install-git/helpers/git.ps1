# --------------------------------------------------------------------------
#  Git helper functions
# --------------------------------------------------------------------------

function Install-Git {
    param(
        [hashtable]$Config,
        [hashtable]$LogMessages
    )

    $packageName = $Config.chocoPackageName

    $existing = Get-Command git -ErrorAction SilentlyContinue
    if ($existing) {
        $currentVersion = & git --version 2>$null
        Write-Log ($LogMessages.messages.gitAlreadyInstalled -replace '\{version\}', $currentVersion) -Level "info"

        if ($Config.alwaysUpgradeToLatest) {
            Upgrade-ChocoPackage -PackageName $packageName
            $newVersion = & git --version 2>$null
            Write-Log ($LogMessages.messages.gitUpgradeSuccess -replace '\{version\}', $newVersion) -Level "success"
        }
    }
    else {
        Write-Log $LogMessages.messages.gitNotFound -Level "warn"
        Install-ChocoPackage -PackageName $packageName

        # Refresh PATH
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

        $installedVersion = & git --version 2>$null
        Write-Log ($LogMessages.messages.gitInstallSuccess -replace '\{version\}', $installedVersion) -Level "success"
    }
}

function Configure-GitGlobal {
    param(
        [hashtable]$Config,
        [hashtable]$LogMessages
    )

    $gc = $Config.gitConfig
    Write-Log $LogMessages.messages.configuringGit -Level "info"

    # -- user.name ---------------------------------------------------------------
    $nameConfig = $gc.userName
    $currentName = & git config --global user.name 2>$null

    if ($currentName) {
        Write-Log ($LogMessages.messages.userNameAlreadySet -replace '\{value\}', $currentName) -Level "info"
    }
    else {
        $name = $nameConfig.value
        if ((-not $name) -and $nameConfig.promptOnFirstRun) {
            $name = Read-Host $LogMessages.messages.promptUserName
        }
        if ($name) {
            & git config --global user.name $name
            Write-Log ($LogMessages.messages.settingUserName -replace '\{value\}', $name) -Level "success"
        }
    }

    # -- user.email --------------------------------------------------------------
    $emailConfig = $gc.userEmail
    $currentEmail = & git config --global user.email 2>$null

    if ($currentEmail) {
        Write-Log ($LogMessages.messages.userEmailAlreadySet -replace '\{value\}', $currentEmail) -Level "info"
    }
    else {
        $email = $emailConfig.value
        if ((-not $email) -and $emailConfig.promptOnFirstRun) {
            $email = Read-Host $LogMessages.messages.promptUserEmail
        }
        if ($email) {
            & git config --global user.email $email
            Write-Log ($LogMessages.messages.settingUserEmail -replace '\{value\}', $email) -Level "success"
        }
    }

    # -- credential.helper -------------------------------------------------------
    $credConfig = $gc.credentialManager
    if ($credConfig.enabled) {
        $currentCred = & git config --global credential.helper 2>$null
        if ($currentCred -eq $credConfig.helper) {
            Write-Log ($LogMessages.messages.credentialManagerAlreadySet -replace '\{value\}', $currentCred) -Level "info"
        }
        else {
            & git config --global credential.helper $credConfig.helper
            Write-Log ($LogMessages.messages.settingCredentialManager -replace '\{value\}', $credConfig.helper) -Level "success"
        }
    }

    # -- core.autocrlf -----------------------------------------------------------
    $lineConfig = $gc.lineEndings
    if ($lineConfig.enabled) {
        $currentCrlf = & git config --global core.autocrlf 2>$null
        if ($currentCrlf -eq $lineConfig.autocrlf) {
            Write-Log ($LogMessages.messages.autocrlfAlreadySet -replace '\{value\}', $currentCrlf) -Level "info"
        }
        else {
            & git config --global core.autocrlf $lineConfig.autocrlf
            Write-Log ($LogMessages.messages.settingAutocrlf -replace '\{value\}', $lineConfig.autocrlf) -Level "success"
        }
    }
}

function Update-GitPath {
    param(
        [hashtable]$Config,
        [hashtable]$LogMessages
    )

    if (-not $Config.path.updateUserPath) { return }

    $gitExe = Get-Command git -ErrorAction SilentlyContinue
    if (-not $gitExe) { return }

    $gitDir = Split-Path -Parent $gitExe.Source

    if (Test-InPath -Directory $gitDir) {
        Write-Log ($LogMessages.messages.pathAlreadyContains -replace '\{path\}', $gitDir) -Level "info"
    }
    else {
        Write-Log ($LogMessages.messages.addingToPath -replace '\{path\}', $gitDir) -Level "info"
        Add-ToUserPath -Directory $gitDir
    }
}
