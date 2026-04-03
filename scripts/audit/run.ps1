# --------------------------------------------------------------------------
#  Audit Mode
#  Scans all script configs, specs, and suggestions for stale IDs
#  or renumbering inconsistencies.
# --------------------------------------------------------------------------
param(
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$scriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Definition
$sharedDir  = Join-Path (Split-Path -Parent $scriptDir) "shared"
$repoRoot   = Split-Path -Parent (Split-Path -Parent $scriptDir)

# -- Dot-source shared helpers ------------------------------------------------
. (Join-Path $sharedDir "logging.ps1")
. (Join-Path $sharedDir "help.ps1")

# -- Dot-source audit helpers -------------------------------------------------
. (Join-Path $scriptDir "helpers\checks.ps1")

# -- Load config & log messages -----------------------------------------------
$config       = Import-JsonConfig (Join-Path $scriptDir "config.json")
$logMessages  = Import-JsonConfig (Join-Path $scriptDir "log-messages.json")

# -- Help ---------------------------------------------------------------------
if ($Help) {
    Show-ScriptHelp -LogMessages $logMessages
    return
}

# -- Banner -------------------------------------------------------------------
Write-Banner -Title $logMessages.scriptName -Version $logMessages.version

# -- Load registry ------------------------------------------------------------
$registryPath = Join-Path $repoRoot "scripts\registry.json"
$isRegistryMissing = -not (Test-Path $registryPath)
if ($isRegistryMissing) {
    Write-Log "registry.json not found at $registryPath" -Level "error"
    return
}
$registry = Get-Content $registryPath -Raw | ConvertFrom-Json

# -- Run checks ---------------------------------------------------------------
Write-Log $logMessages.messages.startingAudit -Level "info"
Write-Host ""

$allResults = New-Object System.Collections.ArrayList
$checks = $config.checks

if ($checks.registryVsFolders) {
    [void]$allResults.Add((Test-RegistryVsFolders -RepoRoot $repoRoot -Registry $registry -LogMessages $logMessages))
}

if ($checks.orchestratorConfig) {
    [void]$allResults.Add((Test-OrchestratorConfig -RepoRoot $repoRoot -Registry $registry -LogMessages $logMessages))
}

if ($checks.orchestratorGroups) {
    [void]$allResults.Add((Test-OrchestratorGroups -RepoRoot $repoRoot -LogMessages $logMessages))
}

if ($checks.specCoverage) {
    [void]$allResults.Add((Test-SpecCoverage -RepoRoot $repoRoot -Registry $registry -LogMessages $logMessages))
}

if ($checks.configLogMessages) {
    [void]$allResults.Add((Test-ConfigLogMessages -RepoRoot $repoRoot -Registry $registry -LogMessages $logMessages))
}

if ($checks.staleRefsSpecs) {
    $specDir = Join-Path $repoRoot "spec"
    [void]$allResults.Add((Test-StaleRefsInMarkdown -SearchDir $specDir -CheckName "Stale refs in specs" -Registry $registry -LogMessages $logMessages))
}

if ($checks.staleRefsSuggestions) {
    $suggestionsDir = Join-Path $repoRoot "suggestions"
    [void]$allResults.Add((Test-StaleRefsInMarkdown -SearchDir $suggestionsDir -CheckName "Stale refs in suggestions" -Registry $registry -LogMessages $logMessages))
}

if ($checks.staleRefsPowerShell) {
    [void]$allResults.Add((Test-StaleRefsInPowerShell -RepoRoot $repoRoot -Registry $registry -LogMessages $logMessages))
}

# -- Summary ------------------------------------------------------------------
Write-Host ""
Write-Log $logMessages.messages.summaryHeader -Level "info"

$passCount = @($allResults | Where-Object { $_.Passed }).Count
$failCount = @($allResults | Where-Object { -not $_.Passed }).Count

Write-Log ($logMessages.messages.summaryPass -replace '\{count\}', $passCount) -Level "success"

$hasFailures = $failCount -gt 0
if ($hasFailures) {
    Write-Log ($logMessages.messages.summaryFail -replace '\{count\}', $failCount) -Level "error"
    Write-Host ""
    Write-Log $logMessages.messages.someFailures -Level "warn"
} else {
    Write-Host ""
    Write-Log $logMessages.messages.allPassed -Level "success"
}