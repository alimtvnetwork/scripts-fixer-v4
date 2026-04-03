<#
.SYNOPSIS
    Shared dev directory resolution and initialization.

.DESCRIPTION
    Provides functions to resolve the base dev directory (from config, env var,
    or user prompt) and create the standard subdirectory structure.
#>

function Resolve-DevDir {
    <#
    .SYNOPSIS
        Resolves the dev directory path from (in priority order):
        1. $env:DEV_DIR (set by orchestrator script 08)
        2. Config override value
        3. User prompt (if mode allows)
        4. Config default value
    #>
    param(
        [PSCustomObject]$DevDirConfig
    )

    # Check environment variable first (set by orchestrator)
    if (-not [string]::IsNullOrWhiteSpace($env:DEV_DIR)) {
        Write-Log "Using dev directory from environment: $env:DEV_DIR" "ok"
        return $env:DEV_DIR
    }

    if (-not $DevDirConfig) {
        $fallback = "E:\dev"
        Write-Log "No dev directory config -- using fallback: $fallback" "warn"
        return $fallback
    }

    $default  = if ($DevDirConfig.default)  { $DevDirConfig.default }  else { "E:\dev" }
    $override = if ($DevDirConfig.override) { $DevDirConfig.override } else { "" }

    # Config override takes precedence
    if (-not [string]::IsNullOrWhiteSpace($override)) {
        Write-Log "Using dev directory override from config: $override" "info"
        return $override
    }

    # Prompt if mode allows
    if ($DevDirConfig.mode -eq "json-or-prompt") {
        $userInput = Read-Host -Prompt "Enter dev directory (default: $default)"
        if (-not [string]::IsNullOrWhiteSpace($userInput)) {
            Write-Log "User provided dev directory: $userInput" "info"
            return $userInput
        }
    }

    Write-Log "Using default dev directory: $default" "info"
    return $default
}

function Initialize-DevDir {
    <#
    .SYNOPSIS
        Creates the dev directory and standard subdirectories if they don't exist.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$DevDir,

        [string[]]$Subdirectories = @()
    )

    Write-Log "Initializing dev directory: $DevDir" "info"

    if (-not (Test-Path $DevDir)) {
        New-Item -Path $DevDir -ItemType Directory -Force -Confirm:$false | Out-Null
        Write-Log "Created dev directory: $DevDir" "ok"
    } else {
        Write-Log "Dev directory already exists: $DevDir" "skip"
    }

    foreach ($sub in $Subdirectories) {
        $subPath = Join-Path $DevDir $sub
        if (-not (Test-Path $subPath)) {
            New-Item -Path $subPath -ItemType Directory -Force -Confirm:$false | Out-Null
            Write-Log "Created subdirectory: $sub" "ok"
        }
    }

    return $DevDir
}
