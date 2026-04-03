<#
.SYNOPSIS
    Clears the .resolved/ folder for a fresh start.

.DESCRIPTION
    Removes all contents of <repo-root>/.resolved/ so that the next script
    run re-detects everything from scratch. The folder itself is preserved.

.PARAMETER ScriptDir
    Any script directory -- used to locate the repo root.

.PARAMETER EditionName
    Optional. If provided, only clears that edition's key from the
    script's resolved.json instead of wiping the whole folder.
#>

function Clear-ResolvedData {
    param(
        [Parameter(Mandatory)]
        [string]$ScriptDir,

        [string]$EditionName
    )

    $repoRoot    = Split-Path -Parent (Split-Path -Parent $ScriptDir)
    $resolvedDir = Join-Path $repoRoot ".resolved"

    if (-not (Test-Path $resolvedDir)) {
        Write-Log "Nothing to clear -- .resolved/ does not exist" -Level "info"
        return
    }

    if ($EditionName) {
        # Clear only a specific edition key from this script's resolved.json
        $scriptName   = Split-Path -Leaf $ScriptDir
        $resolvedFile = Join-Path $resolvedDir $scriptName "resolved.json"

        if (-not (Test-Path $resolvedFile)) {
            Write-Log "No resolved.json for $scriptName -- nothing to clear" -Level "info"
            return
        }

        try {
            $raw  = Get-Content $resolvedFile -Raw | ConvertFrom-Json
            $ht   = @{}
            foreach ($prop in $raw.PSObject.Properties) {
                if ($prop.Name -ne $EditionName) {
                    $ht[$prop.Name] = $prop.Value
                }
            }

            if ($ht.Count -eq 0) {
                Remove-Item -Path $resolvedFile -Force
                Write-Log "Removed resolved.json for $scriptName (was only $EditionName)" -Level "success"
            } else {
                $json = $ht | ConvertTo-Json -Depth 10
                [System.IO.File]::WriteAllText($resolvedFile, $json)
                Write-Log "Cleared '$EditionName' from $scriptName/resolved.json" -Level "success"
            }
        } catch {
            Write-Log "Failed to clear edition '$EditionName': $_" -Level "warn"
        }
        return
    }

    # Clear everything
    Write-Log "Clearing all resolved data..." -Level "info"
    try {
        Get-ChildItem -Path $resolvedDir -Recurse -Force | Remove-Item -Recurse -Force
        Write-Log "All .resolved/ contents removed" -Level "success"
    } catch {
        Write-Log "Failed to clear .resolved/: $_" -Level "warn"
    }
}
