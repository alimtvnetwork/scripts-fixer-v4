<#
.SYNOPSIS
    Shared Chocolatey helpers: ensure installed, install/upgrade packages.
#>

function Assert-Choco {
    <#
    .SYNOPSIS
        Ensures Chocolatey is installed. Installs it if missing.
        Returns $true if available after the check.
    #>

    Write-Log "Checking for Chocolatey..." "info"
    $chocoCmd = Get-Command choco.exe -ErrorAction SilentlyContinue

    if ($chocoCmd) {
        $version = & choco.exe --version 2>&1
        Write-Log "Chocolatey found: v$version" "ok"
        return $true
    }

    Write-Log "Chocolatey not found -- installing..." "warn"
    try {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

        # Refresh PATH for current session
        $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")

        $chocoCmd = Get-Command choco.exe -ErrorAction SilentlyContinue
        if ($chocoCmd) {
            Write-Log "Chocolatey installed successfully" "ok"
            return $true
        } else {
            Write-Log "Chocolatey install completed but choco.exe not found in PATH" "fail"
            return $false
        }
    } catch {
        Write-Log "Failed to install Chocolatey: $_" "fail"
        return $false
    }
}

function Install-ChocoPackage {
    <#
    .SYNOPSIS
        Installs a Chocolatey package if not already installed.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$PackageName,

        [string]$Version
    )

    Write-Log "Checking if '$PackageName' is installed via Chocolatey..." "info"

    $installed = choco list --local-only --exact $PackageName 2>&1
    if ($LASTEXITCODE -eq 0 -and $installed -match $PackageName) {
        Write-Log "'$PackageName' is already installed" "ok"
        return $true
    }

    Write-Log "Installing '$PackageName' via Chocolatey..." "info"
    try {
        $args = @("install", $PackageName, "-y")
        if ($Version) { $args += @("--version", $Version) }

        $output = & choco.exe @args 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Chocolatey install failed for '$PackageName': $output" "fail"
            return $false
        }

        Write-Log "'$PackageName' installed successfully" "ok"
        return $true
    } catch {
        Write-Log "Failed to install '$PackageName': $_" "fail"
        return $false
    }
}

function Upgrade-ChocoPackage {
    <#
    .SYNOPSIS
        Upgrades a Chocolatey package to the latest version.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$PackageName
    )

    Write-Log "Upgrading '$PackageName' via Chocolatey..." "info"
    try {
        $output = & choco.exe upgrade $PackageName -y 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Log "Chocolatey upgrade failed for '$PackageName': $output" "warn"
            return $false
        }

        Write-Log "'$PackageName' upgraded successfully" "ok"
        return $true
    } catch {
        Write-Log "Failed to upgrade '$PackageName': $_" "fail"
        return $false
    }
}
