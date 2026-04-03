# --------------------------------------------------------------------------
#  Orchestrator helper functions
# --------------------------------------------------------------------------

function Resolve-ScriptList {
    param(
        $Config,
        [string]$Skip,
        [string]$Only
    )

    $sequence = $Config.sequence
    $scripts  = $Config.scripts

    # --only filter
    if ($Only) {
        $onlyList = $Only -split ',' | ForEach-Object { $_.Trim() }
        $sequence = $sequence | Where-Object { $_ -in $onlyList }
    }

    # --skip filter
    if ($Skip) {
        $skipList = $Skip -split ',' | ForEach-Object { $_.Trim() }
        $sequence = $sequence | Where-Object { $_ -notin $skipList }
    }

    # Filter disabled
    $result = @()
    foreach ($id in $sequence) {
        $entry = $scripts.$id
        $hasNoEntry = -not $entry
        if ($hasNoEntry) { continue }

        $result += @{
            Id      = $id
            Folder  = $entry.folder
            Name    = $entry.name
            Enabled = $entry.enabled
        }
    }

    return $result
}

function Invoke-ScriptSequence {
    param(
        [array]$ScriptList,
        [string]$ScriptsRoot,
        $LogMessages,
        [string]$Skip
    )

    $skipList = if ($Skip) { $Skip -split ',' | ForEach-Object { $_.Trim() } } else { @() }
    $results  = @()

    foreach ($script in $ScriptList) {
        $id   = $script.Id
        $name = $script.Name

        # Skip disabled
        $isDisabled = -not $script.Enabled
        if ($isDisabled) {
            Write-Log ($LogMessages.messages.scriptDisabled -replace '\{id\}', $id -replace '\{name\}', $name) -Level "warn"
            $results += @{ Id = $id; Name = $name; Status = "disabled" }
            continue
        }

        # Skip user-requested
        $isSkipped = $id -in $skipList
        if ($isSkipped) {
            Write-Log ($LogMessages.messages.scriptSkipped -replace '\{id\}', $id -replace '\{name\}', $name) -Level "warn"
            $results += @{ Id = $id; Name = $name; Status = "skipped" }
            continue
        }

        Write-Log ($LogMessages.messages.runningScript -replace '\{id\}', $id -replace '\{name\}', $name) -Level "info"

        $scriptPath = Join-Path $ScriptsRoot "$($script.Folder)\run.ps1"

        try {
            & $scriptPath
            Write-Log ($LogMessages.messages.scriptSuccess -replace '\{id\}', $id) -Level "success"
            $results += @{ Id = $id; Name = $name; Status = "success" }
        }
        catch {
            $errMsg = $_.Exception.Message
            Write-Log ($LogMessages.messages.scriptFailed -replace '\{id\}', $id -replace '\{error\}', $errMsg) -Level "error"
            $results += @{ Id = $id; Name = $name; Status = "failed" }
        }
    }

    return $results
}

function Show-Summary {
    param(
        [array]$Results,
        $LogMessages
    )

    Write-Host ""
    Write-Log $LogMessages.messages.summaryHeader -Level "info"

    foreach ($r in $Results) {
        $badge = switch ($r.Status) {
            "success"  { "OK" }
            "failed"   { "FAIL" }
            "skipped"  { "SKIP" }
            "disabled" { "OFF" }
            default    { "??" }
        }
        $level = switch ($r.Status) {
            "success"  { "success" }
            "failed"   { "error" }
            default    { "warn" }
        }
        $msg = $LogMessages.messages.summaryItem -replace '\{status\}', $badge -replace '\{id\}', $r.Id -replace '\{name\}', $r.Name
        Write-Log $msg -Level $level
    }

    Write-Host ""
}
