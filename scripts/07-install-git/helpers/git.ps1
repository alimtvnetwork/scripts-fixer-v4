# --------------------------------------------------------------------------
#  Git, Git LFS, and GitHub CLI helper functions
# --------------------------------------------------------------------------

# -- Bootstrap shared helpers --------------------------------------------------
$_sharedDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "shared"
$_loggingPath = Join-Path $_sharedDir "logging.ps1"
if ((Test-Path $_loggingPath) -and -not (Get-Command Write-Log -ErrorAction SilentlyContinue)) {
    . $_loggingPath
}


function Install-Git {
    param(
        $Config,
        $LogMessages
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

function Install-GitLfs {
    param(
        $Config,
        $LogMessages
    )

    $lfsConfig = $Config.gitLfs
    $isLfsDisabled = -not $lfsConfig.enabled
    if ($isLfsDisabled) { return }

    $packageName = $lfsConfig.chocoPackageName

    $existing = Get-Command git-lfs -ErrorAction SilentlyContinue
    if ($existing) {
        $currentVersion = & git lfs version 2>$null
        Write-Log ($LogMessages.messages.lfsAlreadyInstalled -replace '\{version\}', $currentVersion) -Level "info"

        if ($lfsConfig.alwaysUpgradeToLatest) {
            Upgrade-ChocoPackage -PackageName $packageName
            $newVersion = & git lfs version 2>$null
            Write-Log ($LogMessages.messages.lfsUpgradeSuccess -replace '\{version\}', $newVersion) -Level "success"
        }
    }
    else {
        Write-Log $LogMessages.messages.lfsNotFound -Level "warn"
        Install-ChocoPackage -PackageName $packageName

        # Refresh PATH
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

        $installedVersion = & git lfs version 2>$null
        Write-Log ($LogMessages.messages.lfsInstallSuccess -replace '\{version\}', $installedVersion) -Level "success"
    }

    # Initialize LFS in the global git config
    & git lfs install 2>$null
    Write-Log $LogMessages.messages.lfsInitSuccess -Level "success"
}

function Install-GitHubCli {
    param(
        $Config,
        $LogMessages
    )

    $ghConfig = $Config.githubCli
    $isGhDisabled = -not $ghConfig.enabled
    if ($isGhDisabled) { return }

    $packageName = $ghConfig.chocoPackageName

    $existing = Get-Command gh -ErrorAction SilentlyContinue
    if ($existing) {
        $currentVersion = & gh --version 2>$null | Select-Object -First 1
        Write-Log ($LogMessages.messages.ghAlreadyInstalled -replace '\{version\}', $currentVersion) -Level "info"

        if ($ghConfig.alwaysUpgradeToLatest) {
            Write-Log $LogMessages.messages.ghUpgrading -Level "info"
            Upgrade-ChocoPackage -PackageName $packageName
            $newVersion = & gh --version 2>$null | Select-Object -First 1
            Write-Log ($LogMessages.messages.ghUpgradeSuccess -replace '\{version\}', $newVersion) -Level "success"
        }
    }
    else {
        Write-Log $LogMessages.messages.ghNotFound -Level "warn"
        Install-ChocoPackage -PackageName $packageName

        # Refresh PATH
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

        $installedVersion = & gh --version 2>$null | Select-Object -First 1
        Write-Log ($LogMessages.messages.ghInstallSuccess -replace '\{version\}', $installedVersion) -Level "success"
    }

    # Prompt for login if configured
    if ($ghConfig.promptLogin) {
        $authStatus = & gh auth status 2>&1
        $isAuthenticated = $LASTEXITCODE -eq 0
        if ($isAuthenticated) {
            $ghUser = & gh api user --jq '.login' 2>$null
            Write-Log ($LogMessages.messages.ghAlreadyAuthenticated -replace '\{user\}', $ghUser) -Level "info"
        }
        else {
            Write-Log $LogMessages.messages.ghLoginStart -Level "info"
            & gh auth login
        }
    }
}

function Configure-GitGlobal {
    param(
        $Config,
        $LogMessages
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
        $hasNoName = -not $name
        if ($hasNoName -and $nameConfig.promptOnFirstRun) {
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
        $hasNoEmail = -not $email
        if ($hasNoEmail -and $emailConfig.promptOnFirstRun) {
            $email = Read-Host $LogMessages.messages.promptUserEmail
        }
        if ($email) {
            & git config --global user.email $email
            Write-Log ($LogMessages.messages.settingUserEmail -replace '\{value\}', $email) -Level "success"
        }
    }

    # -- init.defaultBranch ------------------------------------------------------
    $branchConfig = $gc.defaultBranch
    if ($branchConfig.enabled) {
        $currentBranch = & git config --global init.defaultBranch 2>$null
        if ($currentBranch -eq $branchConfig.value) {
            Write-Log ($LogMessages.messages.defaultBranchAlreadySet -replace '\{value\}', $currentBranch) -Level "info"
        }
        else {
            & git config --global init.defaultBranch $branchConfig.value
            Write-Log ($LogMessages.messages.settingDefaultBranch -replace '\{value\}', $branchConfig.value) -Level "success"
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

    # -- core.editor -------------------------------------------------------------
    $editorConfig = $gc.editor
    if ($editorConfig.enabled) {
        $currentEditor = & git config --global core.editor 2>$null
        if ($currentEditor -eq $editorConfig.value) {
            Write-Log ($LogMessages.messages.editorAlreadySet -replace '\{value\}', $currentEditor) -Level "info"
        }
        else {
            & git config --global core.editor $editorConfig.value
            Write-Log ($LogMessages.messages.settingEditor -replace '\{value\}', $editorConfig.value) -Level "success"
        }
    }

    # -- push.autoSetupRemote ----------------------------------------------------
    $pushConfig = $gc.pushAutoSetupRemote
    if ($pushConfig.enabled) {
        $currentPush = & git config --global push.autoSetupRemote 2>$null
        $isAlreadySet = $currentPush -eq "true"
        if ($isAlreadySet) {
            Write-Log ($LogMessages.messages.pushAutoSetupAlreadySet -replace '\{value\}', $currentPush) -Level "info"
        }
        else {
            & git config --global push.autoSetupRemote true
            Write-Log $LogMessages.messages.settingPushAutoSetup -Level "success"
        }
    }
}

function Update-GitPath {
    param(
        $Config,
        $LogMessages
    )

    $isPathUpdateDisabled = -not $Config.path.updateUserPath
    if ($isPathUpdateDisabled) { return }

    $gitExe = Get-Command git -ErrorAction SilentlyContinue
    $isGitMissing = -not $gitExe
    if ($isGitMissing) { return }

    $gitDir = Split-Path -Parent $gitExe.Source

    $isAlreadyInPath = Test-InPath -Directory $gitDir
    if ($isAlreadyInPath) {
        Write-Log ($LogMessages.messages.pathAlreadyContains -replace '\{path\}', $gitDir) -Level "info"
    }
    else {
        Write-Log ($LogMessages.messages.addingToPath -replace '\{path\}', $gitDir) -Level "info"
        Add-ToUserPath -Directory $gitDir
    }
}
