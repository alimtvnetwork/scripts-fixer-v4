<#
.SYNOPSIS
    Shared git-pull helper. Dot-source this from any script to get Invoke-GitPull.

.DESCRIPTION
    Provides Invoke-GitPull which runs 'git pull' from the repository root.
    Skips automatically if $env:SCRIPTS_ROOT_RUN is set (meaning the root
    dispatcher already performed the pull).

    Can be called with -RepoRoot or without (auto-detects from caller location).

.NOTES
    Author : Lovable AI
    Version: 1.2.0
#>

# -- Bootstrap shared log messages --------------------------------------------
if (-not $script:SharedLogMessages) {
    $sharedLogPath = Join-Path $PSScriptRoot "log-messages.json"
    $isSharedLogFound = Test-Path $sharedLogPath
    if ($isSharedLogFound) {
        $script:SharedLogMessages = Get-Content $sharedLogPath -Raw | ConvertFrom-Json
    }
}

function Invoke-GitPull {
    param(
        [string]$RepoRoot
    )

    $slm = $script:SharedLogMessages

    # Auto-detect repo root if not provided
    $isRepoRootMissing = -not $RepoRoot
    if ($isRepoRootMissing) {
        $callerDir = if ($script:ScriptDir) { $script:ScriptDir }
                     elseif ($scriptDir) { $scriptDir }
                     else { Split-Path -Parent $MyInvocation.PSCommandPath }
        $RepoRoot = Split-Path -Parent (Split-Path -Parent $callerDir)
    }

    # Skip if the root dispatcher already ran git pull
    if ($env:SCRIPTS_ROOT_RUN -eq "1") {
        Write-Log $slm.messages.gitPullSkipped -Level "skip"
        return
    }

    Write-Log $slm.messages.gitPulling -Level "info"

    try {
        Push-Location $RepoRoot
        $gitOutput = git pull 2>&1
        Pop-Location
        Write-Log ($slm.messages.gitPullSuccess -replace '\{output\}', $gitOutput) -Level "success"
    } catch {
        Pop-Location
        Write-Log ($slm.messages.gitPullFailed -replace '\{error\}', $_) -Level "warn"
    }
}
