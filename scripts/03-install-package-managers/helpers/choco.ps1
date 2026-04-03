<#
.SYNOPSIS
    Chocolatey install/update helpers for script 03.
#>

function Install-Chocolatey {
    param(
        [PSCustomObject]$Config,
        $LogMessages
    )

    $isDisabled = -not $Config.enabled
    if ($isDisabled) {
        Write-Log $LogMessages.messages.chocoDisabled -Level "info"
        return $true
    }

    $isChocoReady = Assert-Choco
    $isChocoNotReady = -not $isChocoReady
    if ($isChocoNotReady) { return $false }

    if ($Config.upgradeOnRun) {
        Write-Log $LogMessages.messages.chocoUpgrading -Level "info"
        try {
            $output = & choco.exe upgrade chocolatey -y 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Log ($LogMessages.messages.chocoUpgradeIssues -replace '\{output\}', $output) -Level "warn"
            } else {
                Write-Log $LogMessages.messages.chocoUpToDate -Level "success"
            }
        } catch {
            Write-Log ($LogMessages.messages.chocoUpgradeFailed -replace '\{error\}', $_) -Level "warn"
        }
    }

    # Save resolved info
    $version = & choco.exe --version 2>&1
    Save-ResolvedData -ScriptFolder "03-install-package-managers" -Data @{
        chocolatey = @{
            version    = "$version".Trim()
            resolvedAt = (Get-Date -Format "o")
            resolvedBy = $env:USERNAME
        }
    }

    return $true
}
