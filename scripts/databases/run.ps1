# --------------------------------------------------------------------------
#  Script 18 -- Install Databases
#  Interactive database installer with SQL, NoSQL, file-based, graph,
#  and search engine support.
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

$script:ScriptDir = $scriptDir

# -- Dot-source shared helpers ------------------------------------------------
. (Join-Path $sharedDir "logging.ps1")
. (Join-Path $sharedDir "resolved.ps1")
. (Join-Path $sharedDir "git-pull.ps1")
. (Join-Path $sharedDir "help.ps1")
. (Join-Path $sharedDir "choco-utils.ps1")
. (Join-Path $sharedDir "dev-dir.ps1")

# -- Dot-source script helpers ------------------------------------------------
. (Join-Path $scriptDir "helpers\install-db.ps1")
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
$devDir = Initialize-DevDir -Path $devDir -Subdirectories @("databases")
$env:DEV_DIR = $devDir

# -- Resolve install path (prompt only in interactive mode) --------------------
$installPath = ""
$isInteractive = -not $All -and -not $Only -and -not $DryRun
if ($isInteractive) {
    $installPath = Get-InstallPath -DevDir $devDir -LogMessages $logMessages
} else {
    $installPath = Join-Path $devDir "databases"
}

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

        # Run installation
        $results = @{}
        foreach ($key in $selectedKeys) {
            $dbConfig = $dbs.$key
            $hasNoConfig = -not $dbConfig
            if ($hasNoConfig) { continue }

            if ($DryRun) {
                Write-Host "  [DRY] Would install: $($dbConfig.name)" -ForegroundColor Yellow
                $results[$key] = "skip"
                continue
            }

            $ok = Install-Database -DbKey $key -DbConfig $dbConfig -LogMessages $logMessages -InstallPath $installPath
            $results[$key] = if ($ok) { "ok" } else { "fail" }
        }

        # Summary
        Write-Host ""
        Write-Host "  $($logMessages.messages.summaryTitle)" -ForegroundColor Cyan
        foreach ($key in $selectedKeys) {
            $dbConfig = $dbs.$key
            $status = $results[$key]
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

        if ($DryRun) {
            Write-Host "  [DRY] Would install: $($dbConfig.name)" -ForegroundColor Yellow
            $results[$key] = "skip"
            continue
        }

        $ok = Install-Database -DbKey $key -DbConfig $dbConfig -LogMessages $logMessages -InstallPath $installPath
        $results[$key] = if ($ok) { "ok" } else { "fail" }
    }

    # Summary
    Write-Host ""
    Write-Host "  $($logMessages.messages.summaryTitle)" -ForegroundColor Cyan
    foreach ($key in $selectedKeys) {
        $dbConfig = $dbs.$key
        $status = $results[$key]
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
}

Write-Host ""
Write-Log $logMessages.messages.setupComplete -Level "success"