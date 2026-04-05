# --------------------------------------------------------------------------
#  Script 30 -- Install Databases (Orchestrator)
#  Interactive database installer menu that dispatches to individual
#  numbered DB scripts (18-29).
# --------------------------------------------------------------------------
param(
    [switch]$All,
    [string]$Skip,
    [string]$Only,
    [switch]$DryRun,
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$sharedDir = Join-Path (Split-Path -Parent $scriptDir) "shared"
$scriptsRoot = Split-Path -Parent $scriptDir

$script:ScriptDir = $scriptDir

# -- Dot-source shared helpers ------------------------------------------------
. (Join-Path $sharedDir "logging.ps1")
. (Join-Path $sharedDir "resolved.ps1")
. (Join-Path $sharedDir "git-pull.ps1")
. (Join-Path $sharedDir "help.ps1")
. (Join-Path $sharedDir "dev-dir.ps1")

# -- Dot-source script helpers ------------------------------------------------
. (Join-Path $scriptDir "helpers\menu.ps1")

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

# -- Assert admin --------------------------------------------------------------
$hasAdminRights = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$isNotAdmin = -not $hasAdminRights
if ($isNotAdmin) {
    Write-Log $logMessages.messages.notAdmin -Level "error"
    return
}

# -- Resolve dev directory -----------------------------------------------------
$devDir = Resolve-DevDir -Config $config.devDir
Initialize-DevDir -Path $devDir
$env:DEV_DIR = $devDir

# -- Build database list -------------------------------------------------------
$sequence = $config.sequence
$dbs      = $config.databases

# Apply -Only filter
$hasOnly = -not [string]::IsNullOrWhiteSpace($Only)
if ($hasOnly) {
    $onlyList = $Only -split ',' | ForEach-Object { $_.Trim().ToLower() }
    $sequence = $sequence | Where-Object { $_ -in $onlyList }
}

# Apply -Skip filter
$hasSkip = -not [string]::IsNullOrWhiteSpace($Skip)
if ($hasSkip) {
    $skipList = $Skip -split ',' | ForEach-Object { $_.Trim().ToLower() }
    $sequence = $sequence | Where-Object { $_ -notin $skipList }
}

# -- Helper: invoke an individual DB script ------------------------------------
function Invoke-DbScript {
    param(
        [string]$Folder,
        [string]$Name,
        [switch]$DryRun
    )

    $scriptPath = Join-Path $scriptsRoot $Folder "run.ps1"
    $hasScript = Test-Path $scriptPath
    if (-not $hasScript) {
        Write-Log "Script not found: $scriptPath" -Level "error"
        return "fail"
    }

    if ($DryRun) {
        Write-Host "  [DRY] Would run: $Folder\run.ps1" -ForegroundColor Yellow
        return "skip"
    }

    Write-Log "Running $Name ($Folder)..." -Level "info"
    try {
        & $scriptPath
        return "ok"
    } catch {
        Write-Log "Failed: $($_.Exception.Message)" -Level "error"
        return "fail"
    }
}

# -- Show summary --------------------------------------------------------------
function Show-DbSummary {
    param($SelectedKeys, $Results, $Dbs)

    Write-Host ""
    Write-Host "  $($logMessages.messages.summaryTitle)" -ForegroundColor Cyan
    foreach ($key in $SelectedKeys) {
        $dbConfig = $Dbs.$key
        $status = $Results[$key]
        $isOk = $status -eq "ok"
        $isFail = $status -eq "fail"
        if ($isOk) {
            Write-Host "    " -NoNewline; Write-Host "[OK]   " -ForegroundColor Green -NoNewline; Write-Host $dbConfig.name
        } elseif ($isFail) {
            Write-Host "    " -NoNewline; Write-Host "[FAIL] " -ForegroundColor Red -NoNewline; Write-Host $dbConfig.name
        } else {
            Write-Host "    " -NoNewline; Write-Host "[SKIP] " -ForegroundColor DarkGray -NoNewline; Write-Host $dbConfig.name
        }
    }
    Write-Host ""
}

# -- Interactive menu (loop) or direct install ---------------------------------
$selectedKeys = @()

if ($All) {
    $selectedKeys = $sequence
} elseif ($hasOnly) {
    $selectedKeys = $sequence
} else {
    # Interactive menu loop
    while ($true) {
        $selectedKeys = Show-DbMenu -Config $config -LogMessages $logMessages

        $isQuit = $selectedKeys.Count -eq 0
        if ($isQuit) { return }

        # Run individual scripts for each selected DB
        $results = @{}
        foreach ($key in $selectedKeys) {
            $dbConfig = $dbs.$key
            $hasNoConfig = -not $dbConfig
            if ($hasNoConfig) { continue }

            $results[$key] = Invoke-DbScript -Folder $dbConfig.folder -Name $dbConfig.name -DryRun:$DryRun
        }

        Show-DbSummary -SelectedKeys $selectedKeys -Results $results -Dbs $dbs

        # Save resolved state
        Save-ResolvedData -ScriptFolder "databases" -Data @{
            results   = $results
            timestamp = (Get-Date -Format "o")
        }

        Write-Log $logMessages.messages.loopBack -Level "info"
    }
}

# -- Non-interactive install (for -All or -Only) -------------------------------
if ($selectedKeys.Count -gt 0 -and ($All -or $hasOnly)) {
    $results = @{}
    foreach ($key in $selectedKeys) {
        $dbConfig = $dbs.$key
        $hasNoConfig = -not $dbConfig
        if ($hasNoConfig) { continue }

        $results[$key] = Invoke-DbScript -Folder $dbConfig.folder -Name $dbConfig.name -DryRun:$DryRun
    }

    Show-DbSummary -SelectedKeys $selectedKeys -Results $results -Dbs $dbs
}

Write-Host ""
Write-Log $logMessages.messages.setupComplete -Level "success"
