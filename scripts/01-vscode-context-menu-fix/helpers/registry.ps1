<#
.SYNOPSIS
    Registry and VS Code resolution helpers for the context-menu-fix script.

.NOTES
    Uses reg.exe for all registry writes to avoid PowerShell provider issues
    with wildcard characters (HKCR:\*) and -LiteralPath incompatibility
    on Windows PowerShell 5.1.
#>

function Assert-Admin {
    $logMsgs = Import-JsonConfig (Join-Path $script:ScriptDir "log-messages.json")
    Write-Log $logMsgs.messages.checkingAdmin -Level "info"
    $identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    $hasAdminRights = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    Write-Log ($logMsgs.messages.currentUser -replace '\{name\}', $identity.Name) -Level "info"
    Write-Log ($logMsgs.messages.isAdministrator -replace '\{value\}', $hasAdminRights) -Level $(if ($hasAdminRights) { "success" } else { "error" })
    return $hasAdminRights
}

function Resolve-VsCodePath {
    param(
        [PSCustomObject]$PathConfig,
        [string]$PreferredType,
        [string]$ScriptDir,
        [string]$EditionName
    )

    $logMsgs = Import-JsonConfig (Join-Path $ScriptDir "log-messages.json")

    # Check .resolved/ cache first
    if ($ScriptDir -and $EditionName) {
        $resolvedDir  = Get-ResolvedDir -ScriptDir $ScriptDir
        $resolvedFile = Join-Path $resolvedDir "resolved.json"
        $hasCacheFile = Test-Path $resolvedFile
        if ($hasCacheFile) {
            try {
                $cached = Get-Content $resolvedFile -Raw | ConvertFrom-Json
                $cachedExe = $cached.$EditionName.resolvedExe
                $isCachedPathValid = $cachedExe -and (Test-Path $cachedExe)
                if ($isCachedPathValid) {
                    Write-Log ($logMsgs.messages.usingCachedPath -replace '\{path\}', $cachedExe) -Level "success"
                    return $cachedExe
                } elseif ($cachedExe) {
                    Write-Log ($logMsgs.messages.cachedPathInvalid -replace '\{path\}', $cachedExe) -Level "warn"
                }
            } catch {
                Write-Log $logMsgs.messages.cacheReadFailed -Level "warn"
            }
        }
    }

    Write-Log ($logMsgs.messages.preferredInstallType -replace '\{type\}', $PreferredType) -Level "info"

    # Try preferred path
    $rawPath = $PathConfig.$PreferredType
    Write-Log (($logMsgs.messages.rawConfigValue -replace '\{type\}', $PreferredType) -replace '\{path\}', $rawPath) -Level "info"
    $exePath = [System.Environment]::ExpandEnvironmentVariables($rawPath)
    Write-Log ($logMsgs.messages.expandedPath -replace '\{path\}', $exePath) -Level "info"

    $isPreferredFound = Test-Path $exePath
    Write-Log (($logMsgs.messages.fileExistsAtPath -replace '\{result\}', $isPreferredFound)) -Level $(if ($isPreferredFound) { "success" } else { "warn" })

    if ($isPreferredFound) { return $exePath }

    # Fallback
    $fallbackType = if ($PreferredType -eq "user") { "system" } else { "user" }
    Write-Log ($logMsgs.messages.tryingFallback -replace '\{type\}', $fallbackType) -Level "warn"

    $fallbackRaw = $PathConfig.$fallbackType
    Write-Log (($logMsgs.messages.rawConfigValue -replace '\{type\}', $fallbackType) -replace '\{path\}', $fallbackRaw) -Level "info"
    $fallbackExe = [System.Environment]::ExpandEnvironmentVariables($fallbackRaw)
    Write-Log ($logMsgs.messages.expandedPath -replace '\{path\}', $fallbackExe) -Level "info"

    $isFallbackFound = Test-Path $fallbackExe
    Write-Log (($logMsgs.messages.fileExistsAtPath -replace '\{result\}', $isFallbackFound)) -Level $(if ($isFallbackFound) { "success" } else { "error" })

    if ($isFallbackFound) { return $fallbackExe }

    Write-Log $logMsgs.messages.noExeFound -Level "error"
    return $null
}

function Save-ResolvedPath {
    param(
        [string]$ScriptDir,
        [string]$EditionName,
        [string]$ResolvedExe
    )

    Save-ResolvedData -ScriptFolder "01-vscode-context-menu-fix" -Data @{
        $EditionName = @{
            resolvedExe  = $ResolvedExe
            resolvedAt   = (Get-Date -Format "o")
            resolvedBy   = $env:USERNAME
        }
    }
}

# -- Registry helpers using reg.exe -------------------------------------------

function ConvertTo-RegPath {
    <#
    .SYNOPSIS
        Converts a PowerShell Registry:: path to a native reg.exe path.
        e.g. Registry::HKEY_CLASSES_ROOT\*\shell\VSCode -> HKCR\*\shell\VSCode
    #>
    param([string]$PsPath)

    $p = $PsPath -replace '^Registry::', ''
    $p = $p -replace '^HKEY_CLASSES_ROOT', 'HKCR'
    $p = $p -replace '^HKEY_CURRENT_USER', 'HKCU'
    $p = $p -replace '^HKEY_LOCAL_MACHINE', 'HKLM'
    return $p
}

function Register-ContextMenu {
    param(
        [string]$StepLabel,
        [string]$RegistryPath,
        [string]$Label,
        [string]$IconValue,
        [string]$CommandArg,
        [PSObject]$LogMsgs
    )

    Write-Log ($LogMsgs.messages.registerStep -replace '\{step\}', $StepLabel) -Level "info"
    Write-Log ($LogMsgs.messages.regPathDetail -replace '\{path\}', $RegistryPath) -Level "info"
    Write-Log ($LogMsgs.messages.regLabelDetail -replace '\{label\}', $Label) -Level "info"
    Write-Log ($LogMsgs.messages.regIconDetail -replace '\{icon\}', $IconValue) -Level "info"
    Write-Log ($LogMsgs.messages.regCommandDetail -replace '\{command\}', $CommandArg) -Level "info"

    $regPath = ConvertTo-RegPath $RegistryPath

    try {
        # Set (Default) value = label
        Write-Log ("  " + ($LogMsgs.messages.settingRegistryDefault -replace '\{label\}', $Label)) -Level "info"
        $out = reg.exe add $regPath /ve /d $Label /f 2>&1
        $hasRegFailed = $LASTEXITCODE -ne 0
        if ($hasRegFailed) { throw "reg add (Default) failed: $out" }
        Write-Log ("  " + $LogMsgs.messages.registryDefaultSet) -Level "success"

        # Set Icon
        Write-Log ("  " + ($LogMsgs.messages.settingIcon -replace '\{icon\}', $IconValue)) -Level "info"
        $out = reg.exe add $regPath /v "Icon" /d $IconValue /f 2>&1
        $hasRegFailed = $LASTEXITCODE -ne 0
        if ($hasRegFailed) { throw "reg add Icon failed: $out" }
        Write-Log ("  " + $LogMsgs.messages.iconSet) -Level "success"

        # Create command subkey with (Default) = command
        $cmdRegPath = "$regPath\command"
        Write-Log ("  " + ($LogMsgs.messages.settingCommand -replace '\{command\}', $CommandArg)) -Level "info"
        $out = reg.exe add $cmdRegPath /ve /d $CommandArg /f 2>&1
        $hasRegFailed = $LASTEXITCODE -ne 0
        if ($hasRegFailed) { throw "reg add command failed: $out" }
        Write-Log ("  " + $LogMsgs.messages.commandSet) -Level "success"

        return $true
    } catch {
        Write-Log ("  " + ($LogMsgs.messages.registryFailed -replace '\{error\}', $_)) -Level "error"
        Write-Log ("  " + ($LogMsgs.messages.registryStack -replace '\{stack\}', $_.ScriptStackTrace)) -Level "error"
        return $false
    }
}

function Test-RegistryEntry {
    param(
        [string]$RegistryPath,
        [string]$Label,
        [PSObject]$LogMsgs
    )

    $regPath = ConvertTo-RegPath $RegistryPath
    Write-Log ("  " + ($LogMsgs.messages.verifyingEntry -replace '\{path\}', $regPath)) -Level "info"

    $out = reg.exe query $regPath 2>&1
    $isEntryFound = $LASTEXITCODE -eq 0
    if ($isEntryFound) {
        Write-Log ("  " + (($LogMsgs.messages.verifyPass -replace '\{label\}', $Label) -replace '\{path\}', $regPath)) -Level "success"
        return $true
    } else {
        Write-Log ("  " + (($LogMsgs.messages.verifyMiss -replace '\{label\}', $Label) -replace '\{path\}', $regPath)) -Level "error"
        return $false
    }
}

function Invoke-Edition {
    param(
        [PSCustomObject]$Edition,
        [string]$EditionName,
        [string]$InstallType,
        $Steps,
        [string]$ScriptDir
    )

    $logMsgs = Import-JsonConfig (Join-Path $ScriptDir "log-messages.json")

    Write-Host ""
    Write-Host $logMsgs.messages.editionBorderLine -ForegroundColor DarkCyan
    Write-Host ($logMsgs.messages.editionLabel -replace '\{label\}', $Edition.contextMenuLabel) -ForegroundColor Cyan
    Write-Host $logMsgs.messages.editionBorderLine -ForegroundColor DarkCyan

    # Resolve exe
    Write-Log $Steps.detectInstall -Level "info"
    $VsCodeExe = Resolve-VsCodePath -PathConfig $Edition.vscodePath -PreferredType $InstallType -ScriptDir $ScriptDir -EditionName $EditionName

    $isExeMissing = -not $VsCodeExe
    if ($isExeMissing) {
        Write-Log ($logMsgs.messages.exeNotFound -replace '\{label\}', $Edition.contextMenuLabel) -Level "warn"
        return $false
    }
    Write-Log ($logMsgs.messages.usingExe -replace '\{path\}', $VsCodeExe) -Level "success"

    # Persist resolved path to .resolved/ (not config.json)
    if ($ScriptDir) {
        Save-ResolvedPath -ScriptDir $ScriptDir -EditionName $EditionName -ResolvedExe $VsCodeExe
    }

    $Label   = $Edition.contextMenuLabel
    $IconVal = "`"$VsCodeExe`""

    # Define entries
    $entries = @(
        @{ Step = $Steps.regFile; Path = $Edition.registryPaths.file;       CmdArg = "`"$VsCodeExe`" `"%1`"" },
        @{ Step = $Steps.regDir;  Path = $Edition.registryPaths.directory;  CmdArg = "`"$VsCodeExe`" `"%V`"" },
        @{ Step = $Steps.regBg;   Path = $Edition.registryPaths.background; CmdArg = "`"$VsCodeExe`" `"%V`"" }
    )

    $isAllOk = $true

    # Register
    foreach ($entry in $entries) {
        $result = Register-ContextMenu `
            -StepLabel  $entry.Step `
            -RegistryPath $entry.Path `
            -Label      $Label `
            -IconValue  $IconVal `
            -CommandArg $entry.CmdArg `
            -LogMsgs    $logMsgs
        $hasFailed = -not $result
        if ($hasFailed) { $isAllOk = $false }
    }

    # Verify
    Write-Log $Steps.verify -Level "info"
    foreach ($entry in $entries) {
        $result = Test-RegistryEntry -RegistryPath $entry.Path -Label $entry.Step -LogMsgs $logMsgs
        $hasFailed = -not $result
        if ($hasFailed) { $isAllOk = $false }
    }

    return $isAllOk
}
