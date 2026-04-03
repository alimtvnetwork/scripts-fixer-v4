# --------------------------------------------------------------------------
#  Script 10 -- VS Code Settings Sync
#  Imports settings, keybindings, and extensions for VS Code.
# --------------------------------------------------------------------------
param(
    [switch]$Merge,
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$sharedDir = Join-Path (Split-Path -Parent $scriptDir) "shared"

# -- Dot-source shared helpers ------------------------------------------------
. (Join-Path $sharedDir "logging.ps1")
. (Join-Path $sharedDir "resolved.ps1")
. (Join-Path $sharedDir "git-pull.ps1")
. (Join-Path $sharedDir "help.ps1")
. (Join-Path $sharedDir "json-utils.ps1")

# -- Dot-source script helpers ------------------------------------------------
. (Join-Path $scriptDir "helpers\sync.ps1")

# -- Load config & log messages -----------------------------------------------
$config      = Import-JsonConfig (Join-Path $scriptDir "config.json")
$logMessages = Import-JsonConfig (Join-Path $scriptDir "log-messages.json")

# -- Help ---------------------------------------------------------------------
if ($Help) {
    Show-ScriptHelp -LogMessages $logMessages
    return
}

# -- Banner --------------------------------------------------------------------
Write-Banner -Title $logMessages.scriptName -Version $logMessages.version

# -- Git pull ------------------------------------------------------------------
Invoke-GitPull

# -- Disabled check ------------------------------------------------------------
$isDisabled = -not $config.enabled
if ($isDisabled) {
    Write-Log $logMessages.messages.scriptDisabled -Level "warn"
    return
}

# -- Resolve source files ------------------------------------------------------
$sources = Resolve-SourceFiles -ScriptDir $scriptDir -LogMessages $logMessages

$hasNoSettings = -not $sources.Settings
if ($hasNoSettings) {
    Write-Log $logMessages.messages.noSettingsSource -Level "error"
    return
}

$enabledEditions = $config.enabledEditions
$isAllSuccessful = $true

Write-Log ($logMessages.messages.enabledEditions -replace '\{editions\}', ($enabledEditions -join ', ')) -Level "info"
Write-Log ($logMessages.messages.extensionCount -replace '\{count\}', $sources.Extensions.Count) -Level "info"
if ($Merge) {
    Write-Log $logMessages.messages.mergeEnabled -Level "info"
} else {
    Write-Log $logMessages.messages.replaceMode -Level "info"
}

# -- Process each edition ------------------------------------------------------
foreach ($editionName in $enabledEditions) {
    $edition = $config.editions.$editionName

    $isEditionMissing = -not $edition
    if ($isEditionMissing) {
        Write-Log ($logMessages.messages.unknownEdition -replace '\{name\}', $editionName) -Level "warn"
        $isAllSuccessful = $false
        continue
    }

    $result = Invoke-Edition `
        -Edition      $edition `
        -EditionName  $editionName `
        -Sources      $sources `
        -BackupSuffix $config.backupSuffix `
        -MergeMode    $Merge.IsPresent `
        -ScriptDir    $scriptDir `
        -LogMessages  $logMessages

    $hasFailed = -not $result
    if ($hasFailed) { $isAllSuccessful = $false }
}

# -- Summary -------------------------------------------------------------------
if ($isAllSuccessful) {
    Write-Log $logMessages.messages.done -Level "success"
} else {
    Write-Log $logMessages.messages.completedWithWarnings -Level "warn"
}

# -- Save resolved state -------------------------------------------------------
Save-ResolvedData -ScriptFolder "10-vscode-settings-sync" -Data @{
    editions   = ($enabledEditions -join ',')
    mergeMode  = $Merge.IsPresent
    extensions = $sources.Extensions.Count
    timestamp  = (Get-Date -Format "o")
}
