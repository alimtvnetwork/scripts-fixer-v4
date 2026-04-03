<#
.SYNOPSIS
    Winget verification and install helpers for script 03.
#>

function Install-Winget {
    param([PSCustomObject]$Config)

    $isDisabled = -not $Config.enabled
    if ($isDisabled) {
        Write-Log "Winget is disabled in config -- skipping" -Level "info"
        return $true
    }

    Write-Log "Checking for Winget..." -Level "info"
    $wingetCmd = Get-Command winget.exe -ErrorAction SilentlyContinue

    if ($wingetCmd) {
        $version = & winget.exe --version 2>&1
        Write-Log "Winget found: $version" -Level "success"

        Save-ResolvedData -ScriptFolder "03-install-package-managers" -Data @{
            winget = @{
                version    = "$version".Trim()
                resolvedAt = (Get-Date -Format "o")
                resolvedBy = $env:USERNAME
            }
        }

        return $true
    }

    $isInstallDisabled = -not $Config.installIfMissing
    if ($isInstallDisabled) {
        Write-Log "Winget not found and installIfMissing is false -- skipping" -Level "warn"
        return $false
    }

    Write-Log "Winget not found -- attempting install..." -Level "warn"

    # Try via Add-AppxPackage (Microsoft.DesktopAppInstaller)
    try {
        Write-Log "Downloading App Installer from: $($Config.msStoreUrl)" -Level "info"
        $installerPath = Join-Path $env:TEMP "Microsoft.DesktopAppInstaller.msixbundle"

        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $Config.msStoreUrl -OutFile $installerPath -UseBasicParsing

        Write-Log "Installing App Installer package..." -Level "info"
        Add-AppxPackage -Path $installerPath -ErrorAction Stop

        # Refresh PATH
        $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")

        $wingetCmd = Get-Command winget.exe -ErrorAction SilentlyContinue
        if ($wingetCmd) {
            $version = & winget.exe --version 2>&1
            Write-Log "Winget installed successfully: $version" -Level "success"

            Save-ResolvedData -ScriptFolder "03-install-package-managers" -Data @{
                winget = @{
                    version    = "$version".Trim()
                    resolvedAt = (Get-Date -Format "o")
                    resolvedBy = $env:USERNAME
                }
            }

            return $true
        } else {
            Write-Log "Winget install completed but winget.exe not found in PATH" -Level "error"
            Write-Log "Try installing manually from the Microsoft Store" -Level "info"
            return $false
        }
    } catch {
        Write-Log "Failed to install Winget: $_" -Level "error"
        Write-Log "Install manually: Microsoft Store -> 'App Installer'" -Level "info"
        return $false
    } finally {
        if (Test-Path $installerPath -ErrorAction SilentlyContinue) {
            Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
        }
    }
}
