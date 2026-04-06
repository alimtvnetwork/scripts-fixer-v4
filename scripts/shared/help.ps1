<#
.SYNOPSIS
    Shared --help display helper.

.DESCRIPTION
    Provides Show-ScriptHelp for consistent help output across all scripts.
    Supports two calling conventions:
      Old-style: Show-ScriptHelp -Name -Version -Description -Commands -Flags -Examples
      New-style: Show-ScriptHelp -LogMessages $logMessages
#>

# -- Bootstrap shared log messages --------------------------------------------
if (-not (Get-Variable -Name SharedLogMessages -Scope Script -ErrorAction SilentlyContinue)) {
    $sharedLogPath = Join-Path $PSScriptRoot "log-messages.json"
    $isSharedLogFound = Test-Path $sharedLogPath
    if ($isSharedLogFound) {
        $script:SharedLogMessages = Get-Content $sharedLogPath -Raw | ConvertFrom-Json
    }
}

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

    $slm = $script:SharedLogMessages

    # New-style: extract from LogMessages object
    if ($LogMessages) {
        $isNameMissing        = -not $Name -and $LogMessages.scriptName
        $isDescriptionMissing = -not $Description -and $LogMessages.description
        if ($isNameMissing)        { $Name = $LogMessages.scriptName }
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
    $headerLine = $slm.messages.helpHeader -replace '\{name\}', $Name -replace '\{version\}', $Version
    Write-Host $headerLine -ForegroundColor Cyan
    $descLine = $slm.messages.helpDescription -replace '\{description\}', $Description
    Write-Host $descLine -ForegroundColor Gray
    Write-Host ""

    if ($Commands.Count -gt 0) {
        Write-Host $slm.messages.helpCommandsLabel -ForegroundColor Yellow
        foreach ($cmd in $Commands) {
            $label = "{0,-16}" -f $cmd.Name
            $line = $slm.messages.helpCommandItem -replace '\{label\}', $label -replace '\{description\}', $cmd.Description
            Write-Host $line -ForegroundColor Gray
        }
        Write-Host ""
    }

    if ($Flags.Count -gt 0) {
        Write-Host $slm.messages.helpFlagsLabel -ForegroundColor Yellow
        foreach ($flag in $Flags) {
            $label = "{0,-16}" -f $flag.Name
            $line = $slm.messages.helpFlagItem -replace '\{label\}', $label -replace '\{description\}', $flag.Description
            Write-Host $line -ForegroundColor Gray
        }
        Write-Host ""
    }

    if ($Examples.Count -gt 0) {
        Write-Host $slm.messages.helpExamplesLabel -ForegroundColor Yellow
        foreach ($ex in $Examples) {
            $line = $slm.messages.helpExampleItem -replace '\{example\}', $ex
            Write-Host $line -ForegroundColor DarkGray
        }
        Write-Host ""
    }
}
