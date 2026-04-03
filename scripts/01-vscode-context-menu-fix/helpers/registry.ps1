<#
.SYNOPSIS
    Registry and VS Code resolution helpers for the context-menu-fix script.

.NOTES
    Uses reg.exe for all registry writes to avoid PowerShell provider issues
    with wildcard characters (HKCR:\*) and -LiteralPath incompatibility
    on Windows PowerShell 5.1.
#>

function Assert-Admin {
    Write-Log "Checking Administrator privileges..." "info"
    $identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    $isAdmin   = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    Write-Log "Current user: $($identity.Name)" "info"
    Write-Log "Is Administrator: $isAdmin" $(if ($isAdmin) { "ok" } else { "fail" })
    return $isAdmin
}

function Resolve-VsCodePath {
    param(
        [PSCustomObject]$PathConfig,
        [string]$PreferredType,
        [string]$ScriptDir,
        [string]$EditionName
    )

    # Check .resolved/ cache first
    if ($ScriptDir -and $EditionName) {
        $resolvedDir  = Get-ResolvedDir -ScriptDir $ScriptDir
        $resolvedFile = Join-Path $resolvedDir "resolved.json"
        if (Test-Path $resolvedFile) {
            try {
                $cached = Get-Content $resolvedFile -Raw | ConvertFrom-Json
                $cachedExe = $cached.$EditionName.resolvedExe
                if ($cachedExe -and (Test-Path $cachedExe)) {
                    Write-Log "Using cached path from .resolved/: $cachedExe" "ok"
                    return $cachedExe
                } elseif ($cachedExe) {
                    Write-Log "Cached path no longer valid: $cachedExe -- re-detecting" "warn"
                }
            } catch {
                Write-Log "Could not read resolved cache -- re-detecting" "warn"
            }
        }
    }

    Write-Log "Preferred installation type: $PreferredType"

    # Try preferred path
    $rawPath = $PathConfig.$PreferredType
    Write-Log "Raw config value ($PreferredType): $rawPath"
    $exePath = [System.Environment]::ExpandEnvironmentVariables($rawPath)
    Write-Log "Expanded path: $exePath"

    $exists = Test-Path $exePath
    Write-Log "File exists at expanded path: $exists" $(if ($exists) { "ok" } else { "warn" })

    if ($exists) { return $exePath }

    # Fallback
    $fallbackType = if ($PreferredType -eq "user") { "system" } else { "user" }
    Write-Log "Trying fallback type: $fallbackType" "warn"

    $fallbackRaw = $PathConfig.$fallbackType
    Write-Log "Raw config value ($fallbackType): $fallbackRaw"
    $fallbackExe = [System.Environment]::ExpandEnvironmentVariables($fallbackRaw)
    Write-Log "Expanded fallback path: $fallbackExe"

    $fallbackExists = Test-Path $fallbackExe
    Write-Log "File exists at fallback path: $fallbackExists" $(if ($fallbackExists) { "ok" } else { "fail" })

    if ($fallbackExists) { return $fallbackExe }

    Write-Log "No valid VS Code executable found for either type" "fail"
    return $null
}

function Save-ResolvedPath {
    param(
        [string]$ScriptDir,
        [string]$EditionName,
        [string]$ResolvedExe
    )

    Save-ResolvedData -ScriptDir $ScriptDir -Data @{
        $EditionName = @{
            resolvedExe  = $ResolvedExe
            resolvedAt   = (Get-Date -Format "o")
            resolvedBy   = $env:USERNAME
        }
    }
}

# ── Registry helpers using reg.exe ───────────────────────────────────

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
        [string]$CommandArg
    )

    Write-Log "$StepLabel"
    Write-Log "  Registry path : $RegistryPath"
    Write-Log "  Label         : $Label"
    Write-Log "  Icon          : $IconValue"
    Write-Log "  Command       : $CommandArg"

    $regPath = ConvertTo-RegPath $RegistryPath

    try {
        # Set (Default) value = label
        Write-Log "  Setting (Default) = $Label" "info"
        $out = reg.exe add $regPath /ve /d $Label /f 2>&1
        if ($LASTEXITCODE -ne 0) { throw "reg add (Default) failed: $out" }
        Write-Log "  (Default) set" "ok"

        # Set Icon
        Write-Log "  Setting Icon = $IconValue" "info"
        $out = reg.exe add $regPath /v "Icon" /d $IconValue /f 2>&1
        if ($LASTEXITCODE -ne 0) { throw "reg add Icon failed: $out" }
        Write-Log "  Icon set" "ok"

        # Create command subkey with (Default) = command
        $cmdRegPath = "$regPath\command"
        Write-Log "  Setting command = $CommandArg" "info"
        $out = reg.exe add $cmdRegPath /ve /d $CommandArg /f 2>&1
        if ($LASTEXITCODE -ne 0) { throw "reg add command failed: $out" }
        Write-Log "  Command set" "ok"

        return $true
    } catch {
        Write-Log "  FAILED: $_" "fail"
        Write-Log "  Stack: $($_.ScriptStackTrace)" "fail"
        return $false
    }
}

function Test-RegistryEntry {
    param(
        [string]$RegistryPath,
        [string]$Label
    )

    $regPath = ConvertTo-RegPath $RegistryPath
    Write-Log "  Verifying: $regPath"

    $out = reg.exe query $regPath 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Log "  [pass] $Label -- $regPath" "ok"
        return $true
    } else {
        Write-Log "  [miss] $Label -- $regPath" "fail"
        return $false
    }
}

function Invoke-Edition {
    param(
        [PSCustomObject]$Edition,
        [string]$EditionName,
        [string]$InstallType,
        [hashtable]$Steps,
        [string]$ScriptDir
    )

    Write-Host ""
    Write-Host "  +----------------------------------------------" -ForegroundColor DarkCyan
    Write-Host "  |  Edition: $($Edition.contextMenuLabel)" -ForegroundColor Cyan
    Write-Host "  +----------------------------------------------" -ForegroundColor DarkCyan

    # Resolve exe
    Write-Log $Steps.detectInstall
    $VsCodeExe = Resolve-VsCodePath -PathConfig $Edition.vscodePath -PreferredType $InstallType -ScriptDir $ScriptDir -EditionName $EditionName

    if (-not $VsCodeExe) {
        Write-Log "$($Edition.contextMenuLabel): executable not found -- skipping" "warn"
        return $false
    }
    Write-Log "Using executable: $VsCodeExe" "ok"

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

    $allOk = $true

    # Register
    foreach ($entry in $entries) {
        $result = Register-ContextMenu `
            -StepLabel  $entry.Step `
            -RegistryPath $entry.Path `
            -Label      $Label `
            -IconValue  $IconVal `
            -CommandArg $entry.CmdArg
        if (-not $result) { $allOk = $false }
    }

    # Verify
    Write-Log $Steps.verify
    foreach ($entry in $entries) {
        $result = Test-RegistryEntry -RegistryPath $entry.Path -Label $entry.Step
        if (-not $result) { $allOk = $false }
    }

    return $allOk
}
