<#
.SYNOPSIS
    Chocolatey install/update helpers for script 03.
#>

function Install-Chocolatey {
    param([PSCustomObject]$Config)

    $isDisabled = -not $Config.enabled
    if ($isDisabled) {
        Write-Log "Chocolatey is disabled in config -- skipping" -Level "info"
        return $true
    }

    $isChocoReady = Assert-Choco
    if (-not $isChocoReady) { return $false }

    if ($Config.upgradeOnRun) {
        Write-Log "Upgrading Chocolatey itself to latest..." -Level "info"
        try {
            $output = & choco.exe upgrade chocolatey -y 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Log "Chocolatey self-upgrade had issues: $output" -Level "warn"
            } else {
                Write-Log "Chocolatey is up to date" -Level "success"
            }
        } catch {
            Write-Log "Failed to upgrade Chocolatey: $_" -Level "warn"
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
