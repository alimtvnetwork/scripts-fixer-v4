<#
.SYNOPSIS
    Registry and VS Code resolution helpers for the context-menu-fix script.
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
        [string]$PreferredType
    )

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

    try {
        Write-Log "  Creating registry key..." "info"
        New-Item -LiteralPath $RegistryPath -Force -Confirm:$false -ErrorAction Stop | Out-Null
        Write-Log "  Key created" "ok"

        Write-Log "  Setting (Default) = $Label" "info"
        Set-Item -LiteralPath $RegistryPath -Value $Label -Force -Confirm:$false -ErrorAction Stop
        Write-Log "  (Default) set" "ok"

        Write-Log "  Setting Icon = $IconValue" "info"
        Set-ItemProperty -LiteralPath $RegistryPath -Name "Icon" -Value $IconValue -Force -Confirm:$false -ErrorAction Stop
        Write-Log "  Icon set" "ok"

        $cmdPath = "$RegistryPath\command"
        Write-Log "  Creating command subkey: $cmdPath" "info"
        New-Item -LiteralPath $cmdPath -Force -Confirm:$false -ErrorAction Stop | Out-Null
        Write-Log "  Command subkey created" "ok"

        Write-Log "  Setting command (Default) = $CommandArg" "info"
        Set-Item -LiteralPath $cmdPath -Value $CommandArg -Force -Confirm:$false -ErrorAction Stop
        Write-Log "  Command value set" "ok"

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

    Write-Log "  Verifying: $RegistryPath"
    if (Test-Path -LiteralPath $RegistryPath) {
        Write-Log "  [pass] $Label -- $RegistryPath" "ok"
        return $true
    } else {
        Write-Log "  [miss] $Label -- $RegistryPath" "fail"
        return $false
    }
}

function Invoke-Edition {
    param(
        [PSCustomObject]$Edition,
        [string]$EditionName,
        [string]$InstallType,
        [hashtable]$Steps
    )

    Write-Host ""
    Write-Host "  +----------------------------------------------" -ForegroundColor DarkCyan
    Write-Host "  |  Edition: $($Edition.contextMenuLabel)" -ForegroundColor Cyan
    Write-Host "  +----------------------------------------------" -ForegroundColor DarkCyan

    # Resolve exe
    Write-Log $Steps.detectInstall
    $VsCodeExe = Resolve-VsCodePath -PathConfig $Edition.vscodePath -PreferredType $InstallType

    if (-not $VsCodeExe) {
        Write-Log "$($Edition.contextMenuLabel): executable not found -- skipping" "warn"
        return $false
    }
    Write-Log "Using executable: $VsCodeExe" "ok"

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
