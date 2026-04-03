<#
.SYNOPSIS
    Shared --help display helper.

.DESCRIPTION
    Provides Show-ScriptHelp for consistent help output across all scripts.
    Supports two calling conventions:
      Old-style: Show-ScriptHelp -Name -Version -Description -Commands -Flags -Examples
      New-style: Show-ScriptHelp -LogMessages $logMessages
#>

function Show-ScriptHelp {
    param(
        [string]$Name,
        [string]$Version,
        [string]$Description,
        [hashtable[]]$Commands = @(),
        [string[]]$Examples = @(),
        [hashtable[]]$Flags = @(),
        [PSObject]$LogMessages
    )

    # New-style: extract from LogMessages object
    if ($LogMessages) {
        $isNameMissing        = -not $Name -and $LogMessages.scriptName
        $isVersionMissing     = -not $Version -and $LogMessages.version
        $isDescriptionMissing = -not $Description -and $LogMessages.description
        if ($isNameMissing)        { $Name = $LogMessages.scriptName }
        if ($isVersionMissing)     { $Version = $LogMessages.version }
        if ($isDescriptionMissing) { $Description = $LogMessages.description }

        # Extract commands from log messages help block
        if ($Commands.Count -eq 0 -and $LogMessages.help -and $LogMessages.help.commands) {
            foreach ($prop in $LogMessages.help.commands.PSObject.Properties) {
                $Commands += @{ Name = $prop.Name; Description = $prop.Value }
            }
        }

        # Extract examples
        if ($Examples.Count -eq 0 -and $LogMessages.help -and $LogMessages.help.examples) {
            $Examples = @($LogMessages.help.examples)
        }
    }

    Write-Host ""
    Write-Host "  $Name -- v$Version" -ForegroundColor Cyan
    Write-Host "  $Description" -ForegroundColor Gray
    Write-Host ""

    if ($Commands.Count -gt 0) {
        Write-Host "  Commands:" -ForegroundColor Yellow
        foreach ($cmd in $Commands) {
            $label = "    {0,-16}" -f $cmd.Name
            Write-Host $label -ForegroundColor White -NoNewline
            Write-Host $cmd.Description -ForegroundColor Gray
        }
        Write-Host ""
    }

    if ($Flags.Count -gt 0) {
        Write-Host "  Flags:" -ForegroundColor Yellow
        foreach ($flag in $Flags) {
            $label = "    {0,-16}" -f $flag.Name
            Write-Host $label -ForegroundColor White -NoNewline
            Write-Host $flag.Description -ForegroundColor Gray
        }
        Write-Host ""
    }

    if ($Examples.Count -gt 0) {
        Write-Host "  Examples:" -ForegroundColor Yellow
        foreach ($ex in $Examples) {
            Write-Host "    $ex" -ForegroundColor DarkGray
        }
        Write-Host ""
    }
}
