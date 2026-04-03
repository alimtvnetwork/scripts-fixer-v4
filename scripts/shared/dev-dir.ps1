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

if ($null -eq $script:SharedLogMessages) {
    $sharedLogPath = Join-Path $PSScriptRoot "log-messages.json"
    if (Test-Path $sharedLogPath) {
        $script:SharedLogMessages = Get-Content $sharedLogPath -Raw | ConvertFrom-Json
    }
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
        return $env:DEV_DIR
    }

    $hasNoConfig = -not $DevDirConfig
    if ($hasNoConfig) {
        $fallback = "E:\dev"
        Write-Log ($slm.messages.devDirNoConfig -replace '\{path\}', $fallback) -Level "warn"
        return $fallback
    }

    $default  = if ($DevDirConfig.default)  { $DevDirConfig.default }  else { "E:\dev" }
    $override = if ($DevDirConfig.override) { $DevDirConfig.override } else { "" }

    # Config override takes precedence
    $hasOverride = -not [string]::IsNullOrWhiteSpace($override)
    if ($hasOverride) {
        Write-Log ($slm.messages.devDirOverride -replace '\{path\}', $override) -Level "info"
        return $override
    }

    # Prompt if mode allows
    if ($DevDirConfig.mode -eq "json-or-prompt") {
        $userInput = Read-Host -Prompt "Enter dev directory (default: $default)"
        $hasUserInput = -not [string]::IsNullOrWhiteSpace($userInput)
        if ($hasUserInput) {
            Write-Log ($slm.messages.devDirUserProvided -replace '\{path\}', $userInput) -Level "info"
            return $userInput
        }
    }

    Write-Log ($slm.messages.devDirDefault -replace '\{path\}', $default) -Level "info"
    return $default
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

    Write-Log ($slm.messages.devDirInitializing -replace '\{path\}', $DevDir) -Level "info"

    $isDirMissing = -not (Test-Path $DevDir)
    if ($isDirMissing) {
        New-Item -Path $DevDir -ItemType Directory -Force -Confirm:$false | Out-Null
        Write-Log ($slm.messages.devDirCreated -replace '\{path\}', $DevDir) -Level "success"
    } else {
        Write-Log ($slm.messages.devDirExists -replace '\{path\}', $DevDir) -Level "info"
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
