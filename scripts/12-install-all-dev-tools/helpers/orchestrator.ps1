# --------------------------------------------------------------------------
#  Orchestrator helper functions
# --------------------------------------------------------------------------

# -- Bootstrap shared helpers --------------------------------------------------
$_sharedDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "shared"
$_loggingPath = Join-Path $_sharedDir "logging.ps1"
if ((Test-Path $_loggingPath) -and -not (Get-Command Write-Log -ErrorAction SilentlyContinue)) {
    . $_loggingPath
}


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

    # Build groups lookup for default selection state
    $groupDefaults = @{}
    $hasGroups = $null -ne $Config.groups
    if ($hasGroups) {
        foreach ($group in $Config.groups) {
            foreach ($gid in $group.ids) {
                $groupDefaults[$gid] = $group.checkedByDefault
            }
        }
    }

    # Filter disabled
    $result = @()
    foreach ($id in $sequence) {
        $entry = $scripts.$id
        $hasNoEntry = -not $entry
        if ($hasNoEntry) { continue }

        $checkedByDefault = if ($groupDefaults.ContainsKey($id)) { $groupDefaults[$id] } else { $entry.enabled }

        $result += @{
            Id              = $id
            Folder          = $entry.folder
            Name            = $entry.name
            Desc            = if ($entry.desc) { $entry.desc } else { "" }
            Enabled         = $entry.enabled
            CheckedByDefault = $checkedByDefault
        }
    }

    return $result
}

function Show-InteractiveMenu {
    param(
        [array]$ScriptList,
        $LogMessages,
        $Groups
    )

    # Build selection state from group defaults
    $selected = @{}
    for ($i = 0; $i -lt $ScriptList.Count; $i++) {
        $selected[$i] = $ScriptList[$i].CheckedByDefault
    }

    # Build group ranges for display
    $groupRanges = @()
    $hasGroups = $null -ne $Groups
    if ($hasGroups) {
        foreach ($group in $Groups) {
            $groupIds = @($group.ids)
            $groupRanges += @{
                Label = $group.label
                Ids   = $groupIds
            }
        }
    }

    while ($true) {
        Write-Host ""
        Write-Host "  $($LogMessages.messages.menuTitle)" -ForegroundColor Cyan
        Write-Host "  $('=' * $LogMessages.messages.menuTitle.Length)" -ForegroundColor DarkGray

        if ($hasGroups) {
            # Display with group headers
            foreach ($gr in $groupRanges) {
                Write-Host ""
                Write-Host "  $($gr.Label)" -ForegroundColor Magenta
                Write-Host "  $('-' * $gr.Label.Length)" -ForegroundColor DarkGray

                for ($i = 0; $i -lt $ScriptList.Count; $i++) {
                    $isInGroup = $ScriptList[$i].Id -in $gr.Ids
                    if (-not $isInGroup) { continue }

                    $check = if ($selected[$i]) { "x" } else { " " }
                    $num   = $i + 1
                    $name  = $ScriptList[$i].Name.PadRight(28)
                    $desc  = $ScriptList[$i].Desc

                    Write-Host "  [" -NoNewline
                    if ($selected[$i]) {
                        Write-Host $check -ForegroundColor Green -NoNewline
                    } else {
                        Write-Host $check -NoNewline
                    }
                    Write-Host "] " -NoNewline
                    Write-Host "$num. " -ForegroundColor Yellow -NoNewline
                    Write-Host "$name " -NoNewline
                    Write-Host $desc -ForegroundColor DarkGray
                }
            }
        }
        else {
            # Flat display (no groups)
            Write-Host ""
            for ($i = 0; $i -lt $ScriptList.Count; $i++) {
                $check = if ($selected[$i]) { "x" } else { " " }
                $num   = $i + 1
                $name  = $ScriptList[$i].Name.PadRight(28)
                $desc  = $ScriptList[$i].Desc

                Write-Host "  [" -NoNewline
                if ($selected[$i]) {
                    Write-Host $check -ForegroundColor Green -NoNewline
                } else {
                    Write-Host $check -NoNewline
                }
                Write-Host "] " -NoNewline
                Write-Host "$num. " -ForegroundColor Yellow -NoNewline
                Write-Host "$name " -NoNewline
                Write-Host $desc -ForegroundColor DarkGray
            }
        }

        Write-Host ""
        Write-Host "  " -NoNewline
        $input = Read-Host $LogMessages.messages.menuPrompt

        $isEnterPressed = [string]::IsNullOrWhiteSpace($input)
        if ($isEnterPressed) { break }

        $upperInput = $input.Trim().ToUpper()

        $isSelectAll = $upperInput -eq "A"
        if ($isSelectAll) {
            for ($i = 0; $i -lt $ScriptList.Count; $i++) { $selected[$i] = $true }
            continue
        }

        $isSelectNone = $upperInput -eq "N"
        if ($isSelectNone) {
            for ($i = 0; $i -lt $ScriptList.Count; $i++) { $selected[$i] = $false }
            continue
        }

        # Toggle individual numbers
        $numbers = $input -split '\s+' | ForEach-Object { $_.Trim() }
        foreach ($n in $numbers) {
            $isValidNumber = $n -match '^\d+$'
            if ($isValidNumber) {
                $idx = [int]$n - 1
                $isInRange = $idx -ge 0 -and $idx -lt $ScriptList.Count
                if ($isInRange) {
                    $selected[$idx] = -not $selected[$idx]
                }
            }
        }
    }

    # Return only selected scripts
    $result = @()
    for ($i = 0; $i -lt $ScriptList.Count; $i++) {
        $isSelected = $selected[$i]
        if ($isSelected) {
            $result += $ScriptList[$i]
        }
    }

    return $result
}

function Show-DryRun {
    param(
        [array]$ScriptList,
        $LogMessages
    )

    Write-Host ""
    Write-Log $LogMessages.messages.dryRunBanner -Level "warn"
    Write-Host ""

    foreach ($script in $ScriptList) {
        $isDisabled = -not $script.Enabled
        if ($isDisabled) {
            $msg = $LogMessages.messages.dryRunSkipped -replace '\{id\}', $script.Id -replace '\{name\}', $script.Name
            Write-Log $msg -Level "skip"
        } else {
            $msg = $LogMessages.messages.dryRunItem -replace '\{id\}', $script.Id -replace '\{name\}', $script.Name -replace '\{desc\}', $script.Desc
            Write-Log $msg -Level "info"
        }
    }

    $enabledCount = @($ScriptList | Where-Object { $_.Enabled }).Count
    Write-Host ""
    Write-Log ($LogMessages.messages.dryRunComplete -replace '\{count\}', $enabledCount) -Level "success"
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
