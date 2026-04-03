<#
.SYNOPSIS
    Shared --help display helper.

.DESCRIPTION
    Provides Show-ScriptHelp for consistent help output across all scripts.
#>

function Show-ScriptHelp {
    <#
    .SYNOPSIS
        Displays formatted help text for a script.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Version,

        [Parameter(Mandatory)]
        [string]$Description,

        [hashtable[]]$Commands = @(),

        [string[]]$Examples = @(),

        [hashtable[]]$Flags = @()
    )

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
