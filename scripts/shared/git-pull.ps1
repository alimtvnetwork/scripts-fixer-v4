<#
.SYNOPSIS
    Shared git-pull helper. Dot-source this from any script to get Invoke-GitPull.

.DESCRIPTION
    Provides Invoke-GitPull which runs 'git pull' from the repository root.
    Skips automatically if $env:SCRIPTS_ROOT_RUN is set (meaning the root
    dispatcher already performed the pull).

.NOTES
    Author : Lovable AI
    Version: 1.0.0
#>

function Invoke-GitPull {
    param(
        [Parameter(Mandatory)]
        [string]$RepoRoot
    )

    # Skip if the root dispatcher already ran git pull
    if ($env:SCRIPTS_ROOT_RUN -eq "1") {
        Write-Host "  [ SKIP  ] " -ForegroundColor DarkGray -NoNewline
        Write-Host "git pull -- already run by root dispatcher"
        return
    }

    Write-Host "  [  GIT  ] " -ForegroundColor Cyan -NoNewline
    Write-Host "Pulling latest changes..."

    try {
        Push-Location $RepoRoot
        $gitOutput = git pull 2>&1
        Pop-Location
        Write-Host "  [  OK   ] " -ForegroundColor Green -NoNewline
        Write-Host $gitOutput
    } catch {
        Pop-Location
        Write-Host "  [ WARN  ] " -ForegroundColor Yellow -NoNewline
        Write-Host "git pull failed: $_  (continuing anyway)"
    }
}
