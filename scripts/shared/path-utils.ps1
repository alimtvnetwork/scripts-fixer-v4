<#
.SYNOPSIS
    Shared PATH manipulation helpers with dedup safety.
#>

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

    if (Test-InPath -Directory $Directory -Scope "User") {
        Write-Log "Already in user PATH: $Directory" "skip"
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
        Write-Log "Added to user PATH: $Directory" "ok"
        return $true
    } catch {
        Write-Log "Failed to update user PATH: $_" "fail"
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

    if (Test-InPath -Directory $Directory -Scope "Machine") {
        Write-Log "Already in machine PATH: $Directory" "skip"
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
        Write-Log "Added to machine PATH: $Directory" "ok"
        return $true
    } catch {
        Write-Log "Failed to update machine PATH: $_" "fail"
        return $false
    }
}
