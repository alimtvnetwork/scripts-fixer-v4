# --------------------------------------------------------------------------
#  Orchestrator helper -- Invoke-ScriptSequence
# --------------------------------------------------------------------------

# -- Bootstrap shared helpers --------------------------------------------------
$_sharedDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "shared"
$_loggingPath = Join-Path $_sharedDir "logging.ps1"
if ((Test-Path $_loggingPath) -and -not (Get-Command Write-Log -ErrorAction SilentlyContinue)) {
    . $_loggingPath
}

function Invoke-ScriptSequence {
    param(
        $ScriptList,
        [string]$ScriptsRoot,
        $LogMessages,
        [string]$Skip
    )

    # Normalize: ensure $ScriptList is always a proper list
    $ScriptList = if ($ScriptList -is [hashtable]) { ,@($ScriptList) } else { @($ScriptList) }

    $skipList = if ($Skip) { $Skip -split ',' | ForEach-Object { $_.Trim() } } else { @() }
    $results  = New-Object System.Collections.ArrayList

    foreach ($script in $ScriptList) {
        $id   = $script.Id
        $name = $script.Name

        # Skip disabled
        $isDisabled = -not $script.Enabled
        if ($isDisabled) {
            Write-Log ($LogMessages.messages.scriptDisabled -replace '\{id\}', $id -replace '\{name\}', $name) -Level "warn"
            [void]$results.Add(@{ Id = $id; Name = $name; Status = "disabled" })
            continue
        }

        # Skip user-requested
        $isSkipped = $id -in $skipList
        if ($isSkipped) {
            Write-Log ($LogMessages.messages.scriptSkipped -replace '\{id\}', $id -replace '\{name\}', $name) -Level "warn"
            [void]$results.Add(@{ Id = $id; Name = $name; Status = "skipped" })
            continue
        }

        Write-Log ($LogMessages.messages.runningScript -replace '\{id\}', $id -replace '\{name\}', $name) -Level "info"

        $scriptPath = Join-Path $ScriptsRoot "$($script.Folder)\run.ps1"

        try {
            & $scriptPath
            Write-Log ($LogMessages.messages.scriptSuccess -replace '\{id\}', $id) -Level "success"
            [void]$results.Add(@{ Id = $id; Name = $name; Status = "success" })
        }
        catch {
            $errMsg = $_.Exception.Message
            Write-Log ($LogMessages.messages.scriptFailed -replace '\{id\}', $id -replace '\{error\}', $errMsg) -Level "error"
            [void]$results.Add(@{ Id = $id; Name = $name; Status = "failed" })
        }
    }

    return ,@($results)
}