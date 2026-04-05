<#
.SYNOPSIS
    Shared dev directory resolution and initialization.

.DESCRIPTION
    Provides functions to resolve the base dev directory (from config, env var,
    or user prompt) and create the standard subdirectory structure.
#>

# -- Bootstrap shared helpers --------------------------------------------------
$loggingPath = Join-Path $PSScriptRoot "logging.ps1"
if ((Test-Path $loggingPath) -and -not (Get-Command Write-Log -ErrorAction SilentlyContinue)) {
    . $loggingPath
}

if (-not (Get-Variable -Name SharedLogMessages -Scope Script -ErrorAction SilentlyContinue)) {
    $sharedLogPath = Join-Path $PSScriptRoot "log-messages.json"
    if (Test-Path $sharedLogPath) {
        $script:SharedLogMessages = Get-Content $sharedLogPath -Raw | ConvertFrom-Json
    }
}

function Get-SafeDevDirFallback {
    $systemDrive = if ([string]::IsNullOrWhiteSpace($env:SystemDrive)) { "C:" } else { $env:SystemDrive.TrimEnd('\\') }
    return "$systemDrive\dev"
}

function Resolve-UsableDevDir {
    param(
        [string]$PathValue
    )

    $slm = $script:SharedLogMessages
    $isPathMissing = [string]::IsNullOrWhiteSpace($PathValue)
    if ($isPathMissing) {
        $fallbackPath = Get-SafeDevDirFallback
        Write-Log ($slm.messages.devDirFallback -replace '\{path\}', $fallbackPath) -Level "warn"
        return $fallbackPath
    }

    $expandedPath = [System.Environment]::ExpandEnvironmentVariables($PathValue.Trim())
    Write-Log ($slm.messages.devDirExpanded -replace '\{path\}', $expandedPath) -Level "info"

    try {
        $fullPath = [System.IO.Path]::GetFullPath($expandedPath)
    } catch {
        Write-Log ($slm.messages.devDirInvalid -replace '\{path\}', $expandedPath) -Level "warn"
        $fallbackPath = Get-SafeDevDirFallback
        Write-Log ($slm.messages.devDirFallback -replace '\{path\}', $fallbackPath) -Level "warn"
        return $fallbackPath
    }

    $isDriveQualifiedPath = $fullPath -match '^[A-Za-z]:\\'
    if ($isDriveQualifiedPath) {
        $driveName = $fullPath.Substring(0, 1)
        $drive = Get-PSDrive -Name $driveName -ErrorAction SilentlyContinue
        $hasDrive = $null -ne $drive
        $isDriveMissing = -not $hasDrive
        if ($isDriveMissing) {
            Write-Log ($slm.messages.devDirDriveMissing -replace '\{path\}', $fullPath) -Level "warn"
            $fallbackPath = Get-SafeDevDirFallback
            Write-Log ($slm.messages.devDirFallback -replace '\{path\}', $fallbackPath) -Level "warn"
            return $fallbackPath
        }
    }

    return $fullPath
}

function Resolve-DevDir {
    <#
    .SYNOPSIS
        Resolves the dev directory path from (in priority order):
        1. $env:DEV_DIR (set by orchestrator script 04)
        2. Config override value
        3. User prompt (if mode allows)
        4. Config default value

        Accepts -DevDirConfig or -Config (alias).
    #>
    param(
        [Parameter(Position = 0)]
        [PSCustomObject]$DevDirConfig,

        [PSCustomObject]$Config
    )

    $slm = $script:SharedLogMessages

    # Support -Config alias
    if ($Config -and -not $DevDirConfig) { $DevDirConfig = $Config }

    # Check environment variable first (set by orchestrator)
    $hasDevDirEnv = -not [string]::IsNullOrWhiteSpace($env:DEV_DIR)
    if ($hasDevDirEnv) {
        Write-Log ($slm.messages.devDirFromEnv -replace '\{path\}', $env:DEV_DIR) -Level "success"
        return Resolve-UsableDevDir -PathValue $env:DEV_DIR
    }

    $hasNoConfig = -not $DevDirConfig
    if ($hasNoConfig) {
        $fallbackPath = Get-SafeDevDirFallback
        Write-Log ($slm.messages.devDirNoConfig -replace '\{path\}', $fallbackPath) -Level "warn"
        return Resolve-UsableDevDir -PathValue $fallbackPath
    }

    $defaultPath = if ($DevDirConfig.default) { $DevDirConfig.default } else { Get-SafeDevDirFallback }
    $overridePath = if ($DevDirConfig.override) { $DevDirConfig.override } else { "" }

    # Config override takes precedence
    $hasOverride = -not [string]::IsNullOrWhiteSpace($overridePath)
    if ($hasOverride) {
        Write-Log ($slm.messages.devDirOverride -replace '\{path\}', $overridePath) -Level "info"
        return Resolve-UsableDevDir -PathValue $overridePath
    }

    # Prompt if mode allows
    $isPromptMode = $DevDirConfig.mode -eq "json-or-prompt"
    if ($isPromptMode) {
        $userInput = Read-Host -Prompt "Enter dev directory (default: $defaultPath)"
        $hasUserInput = -not [string]::IsNullOrWhiteSpace($userInput)
        if ($hasUserInput) {
            Write-Log ($slm.messages.devDirUserProvided -replace '\{path\}', $userInput) -Level "info"
            return Resolve-UsableDevDir -PathValue $userInput
        }
    }

    Write-Log ($slm.messages.devDirDefault -replace '\{path\}', $defaultPath) -Level "info"
    return Resolve-UsableDevDir -PathValue $defaultPath
}

function Initialize-DevDir {
    <#
    .SYNOPSIS
        Creates the dev directory and standard subdirectories if they don't exist.
        Accepts -DevDir or -Path (alias).
    #>
    param(
        [Parameter(Position = 0)]
        [string]$DevDir,

        [string]$Path,

        [string[]]$Subdirectories = @()
    )

    $slm = $script:SharedLogMessages

    # Support -Path alias
    if ($Path -and -not $DevDir) { $DevDir = $Path }

    $DevDir = Resolve-UsableDevDir -PathValue $DevDir
    Write-Log ($slm.messages.devDirInitializing -replace '\{path\}', $DevDir) -Level "info"

    try {
        $isDirMissing = -not (Test-Path $DevDir)
        if ($isDirMissing) {
            New-Item -Path $DevDir -ItemType Directory -Force -Confirm:$false | Out-Null
            Write-Log ($slm.messages.devDirCreated -replace '\{path\}', $DevDir) -Level "success"
        } else {
            Write-Log ($slm.messages.devDirExists -replace '\{path\}', $DevDir) -Level "info"
        }
    } catch {
        Write-Log ($slm.messages.devDirCreateFailed -replace '\{path\}', $DevDir -replace '\{error\}', $_) -Level "warn"
        $fallbackPath = Get-SafeDevDirFallback
        $isSameFallback = $fallbackPath -eq $DevDir
        if ($isSameFallback) {
            throw
        }

        Write-Log ($slm.messages.devDirFallback -replace '\{path\}', $fallbackPath) -Level "warn"
        $isFallbackMissing = -not (Test-Path $fallbackPath)
        if ($isFallbackMissing) {
            New-Item -Path $fallbackPath -ItemType Directory -Force -Confirm:$false | Out-Null
            Write-Log ($slm.messages.devDirCreated -replace '\{path\}', $fallbackPath) -Level "success"
        }
        $DevDir = $fallbackPath
    }

    foreach ($sub in $Subdirectories) {
        $subPath = Join-Path $DevDir $sub
        $isSubMissing = -not (Test-Path $subPath)
        if ($isSubMissing) {
            New-Item -Path $subPath -ItemType Directory -Force -Confirm:$false | Out-Null
            Write-Log ($slm.messages.devDirSubCreated -replace '\{name\}', $sub) -Level "success"
        }
    }

    return $DevDir
}
