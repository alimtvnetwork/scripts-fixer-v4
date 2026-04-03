# --------------------------------------------------------------------------
#  Orchestrator helper -- Interactive menu + dry-run display
# --------------------------------------------------------------------------

# -- Bootstrap shared helpers --------------------------------------------------
$_sharedDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "shared"
$_loggingPath = Join-Path $_sharedDir "logging.ps1"
if ((Test-Path $_loggingPath) -and -not (Get-Command Write-Log -ErrorAction SilentlyContinue)) {
    . $_loggingPath
}

function Show-InteractiveMenu {
    param(
        $ScriptList,
        $LogMessages,
        $Groups
    )

    # Normalize: ensure $ScriptList is always a proper list
    $ScriptList = if ($ScriptList -is [hashtable]) { ,@($ScriptList) } else { @($ScriptList) }

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
    $result = New-Object System.Collections.ArrayList
    for ($i = 0; $i -lt $ScriptList.Count; $i++) {
        $isSelected = $selected[$i]
        if ($isSelected) {
            [void]$result.Add($ScriptList[$i])
        }
    }

    return ,@($result)
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