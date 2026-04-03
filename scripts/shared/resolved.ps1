<#
.SYNOPSIS
    Shared helper for writing runtime-resolved data to .resolved/ at repo root.

.DESCRIPTION
    Scripts should never mutate their own config.json with discovered paths.
    Instead, call Save-ResolvedData to persist runtime state to:
        <repo-root>/.resolved/<script-folder>/resolved.json

    The .resolved/ folder is gitignored and safe to overwrite on every run.
#>

function Get-ResolvedDir {
    <#
    .SYNOPSIS
        Returns the .resolved/<script-folder> directory path, creating it if needed.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ScriptDir
    )

    $repoRoot    = Split-Path -Parent (Split-Path -Parent $ScriptDir)
    $scriptName  = Split-Path -Leaf $ScriptDir
    $resolvedDir = Join-Path $repoRoot ".resolved" | Join-Path -ChildPath $scriptName

    if (-not (Test-Path $resolvedDir)) {
        New-Item -Path $resolvedDir -ItemType Directory -Force -Confirm:$false | Out-Null
        Write-Log "Created .resolved directory: $resolvedDir" "info"
    }

    return $resolvedDir
}

function Save-ResolvedData {
    <#
    .SYNOPSIS
        Writes a hashtable as JSON to .resolved/<script-folder>/resolved.json.
        Accepts either -ScriptDir (full path) or -ScriptFolder (folder name string).
    #>
    param(
        [string]$ScriptDir,
        [string]$ScriptFolder,

        [Parameter(Mandatory)]
        [hashtable]$Data
    )

    # Resolve the directory path
    if ($ScriptFolder -and -not $ScriptDir) {
        # Derive from ScriptFolder name: walk up to repo root from the calling script
        $callerDir = if ($script:ScriptDir) { $script:ScriptDir }
                     elseif ($scriptDir) { $scriptDir }
                     else { Split-Path -Parent $MyInvocation.PSCommandPath }
        $repoRoot    = Split-Path -Parent (Split-Path -Parent $callerDir)
        $resolvedDir = Join-Path $repoRoot ".resolved" | Join-Path -ChildPath $ScriptFolder

        if (-not (Test-Path $resolvedDir)) {
            New-Item -Path $resolvedDir -ItemType Directory -Force -Confirm:$false | Out-Null
        }
    }
    else {
        $resolvedDir = Get-ResolvedDir -ScriptDir $ScriptDir
    }

    $resolvedFile = Join-Path $resolvedDir "resolved.json"

    # Merge with existing data if present
    $existing = @{}
    if (Test-Path $resolvedFile) {
        try {
            $raw = Get-Content $resolvedFile -Raw | ConvertFrom-Json
            foreach ($prop in $raw.PSObject.Properties) {
                $existing[$prop.Name] = $prop.Value
            }
        } catch {
            Write-Log "Could not read existing resolved.json -- overwriting" "warn"
        }
    }

    # Overlay new data
    foreach ($key in $Data.Keys) {
        $existing[$key] = $Data[$key]
    }

    try {
        $json = $existing | ConvertTo-Json -Depth 10
        [System.IO.File]::WriteAllText($resolvedFile, $json)
        Write-Log "Resolved data saved: $resolvedFile" "ok"
    } catch {
        Write-Log "Failed to save resolved data: $_" "warn"
    }
}
