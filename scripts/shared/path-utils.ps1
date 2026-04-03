<#
.SYNOPSIS
    Shared PATH manipulation helpers with dedup safety.
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

function Test-InPath {
    <#
    .SYNOPSIS
        Checks if a directory is already in the specified PATH scope.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Directory,

        [ValidateSet("User", "Machine", "Process")]
        [string]$Scope = "User"
    )

    $currentPath = [Environment]::GetEnvironmentVariable("Path", $Scope)
    if ([string]::IsNullOrWhiteSpace($currentPath)) { return $false }

    $entries = $currentPath.Split(";", [StringSplitOptions]::RemoveEmptyEntries)
    return ($entries -contains $Directory)
}

function Add-ToUserPath {
    <#
    .SYNOPSIS
        Adds a directory to the user PATH if not already present.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Directory
    )

    $slm = $script:SharedLogMessages

    if (Test-InPath -Directory $Directory -Scope "User") {
        Write-Log ($slm.messages.pathAlreadyInUser -replace '\{path\}', $Directory) -Level "info"
        return $true
    }

    try {
        $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
        if ([string]::IsNullOrWhiteSpace($currentPath)) {
            $newPath = $Directory
        } else {
            $newPath = $currentPath.TrimEnd(";") + ";" + $Directory
        }

        [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
        # Also update current session
        $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + $newPath
        Write-Log ($slm.messages.pathAddedToUser -replace '\{path\}', $Directory) -Level "success"
        return $true
    } catch {
        Write-Log ($slm.messages.pathUserUpdateFailed -replace '\{error\}', $_) -Level "error"
        return $false
    }
}

function Add-ToMachinePath {
    <#
    .SYNOPSIS
        Adds a directory to the machine PATH if not already present. Requires admin.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Directory
    )

    $slm = $script:SharedLogMessages

    if (Test-InPath -Directory $Directory -Scope "Machine") {
        Write-Log ($slm.messages.pathAlreadyInMachine -replace '\{path\}', $Directory) -Level "info"
        return $true
    }

    try {
        $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
        if ([string]::IsNullOrWhiteSpace($currentPath)) {
            $newPath = $Directory
        } else {
            $newPath = $currentPath.TrimEnd(";") + ";" + $Directory
        }

        [Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")
        $env:Path = $newPath + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
        Write-Log ($slm.messages.pathAddedToMachine -replace '\{path\}', $Directory) -Level "success"
        return $true
    } catch {
        Write-Log ($slm.messages.pathMachineUpdateFailed -replace '\{error\}', $_) -Level "error"
        return $false
    }
}
