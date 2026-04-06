# --------------------------------------------------------------------------
#  Script 12 -- Install All Dev Tools
#  Orchestrator: front-loads all questions, then runs scripts unattended.
#  Supports: quick menu (All Dev / All Dev+DB / Custom), -All, -Skip, -Only.
# --------------------------------------------------------------------------
param(
    [string]$Skip,
    [string]$Only,
    [switch]$All,
    [switch]$DryRun,
    [Alias("D")][switch]$Defaults,
    [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$scriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Definition
$sharedDir   = Join-Path (Split-Path -Parent $scriptDir) "shared"
$scriptsRoot = Split-Path -Parent $scriptDir

# -- Dot-source shared helpers ------------------------------------------------
. (Join-Path $sharedDir "logging.ps1")
. (Join-Path $sharedDir "resolved.ps1")
. (Join-Path $sharedDir "git-pull.ps1")
. (Join-Path $sharedDir "help.ps1")
. (Join-Path $sharedDir "dev-dir.ps1")

# -- Dot-source script helpers ------------------------------------------------
. (Join-Path $scriptDir "helpers\orchestrator.ps1")

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

# -- Initialize logging --------------------------------------------------------
Initialize-Logging -ScriptName $logMessages.scriptName

# -- Git pull ------------------------------------------------------------------
Invoke-GitPull

# -- Assert admin --------------------------------------------------------------
$hasAdminRights = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$isNotAdmin = -not $hasAdminRights
if ($isNotAdmin) {
    Write-Log $logMessages.messages.notAdmin -Level "error"
    return
}

# ==============================================================================
#  MODE A: Flag-based (non-interactive) or -Defaults
# ==============================================================================
$hasFilter = $Skip -or $Only
if ($hasFilter -or $All -or $DryRun -or $Defaults) {
    # With -Defaults, use all defaults for dev dir and env vars
    if ($Defaults) {
        Invoke-Questionnaire -Mode "alldev" -Config $config -LogMessages $logMessages -UseDefaults
        $devDir = $env:DEV_DIR
    } else {
        Write-Log $logMessages.messages.resolvingDevDir -Level "info"
        $devDir = Resolve-DevDir -Config $config.devDir
        $env:DEV_DIR = $devDir
        Write-Log ($logMessages.messages.devDirResolved -replace '\{path\}', $devDir) -Level "success"
    }
    Initialize-DevDir -Path $devDir

    # If -Defaults without -Only/-Skip, default to alldev
    $scriptList = if ($Defaults -and -not $hasFilter) {
        Get-ScriptListForMode -Mode "alldev" -Config $config
    } else {
        Resolve-ScriptList -Config $config -Skip $Skip -Only $Only
    }

    # Dry run
    if ($DryRun) {
        Show-DryRun -ScriptList $scriptList -LogMessages $logMessages
        Save-LogFile -Status "ok"
        return
    }

    # Run
    $results = Invoke-ScriptSequence -ScriptList $scriptList -ScriptsRoot $scriptsRoot -LogMessages $logMessages -Skip $Skip
    Show-Summary -Results $results -LogMessages $logMessages
    Write-Log $logMessages.messages.allComplete -Level "success"

    Save-ResolvedData -ScriptFolder "12-install-all-dev-tools" -Data @{
        devDir    = $devDir
        results   = $results
        defaults  = [bool]$Defaults
        timestamp = (Get-Date -Format "o")
    }
    Save-LogFile -Status "ok"
    return
}

# ==============================================================================
#  MODE B: Interactive (front-loaded questions, then unattended execution)
# ==============================================================================
while ($true) {
    # ── Step 1: Quick menu ────────────────────────────────────────────────────
    $mode = Show-QuickMenu -LogMessages $logMessages

    $isQuit = $mode -eq "quit"
    if ($isQuit) {
        Write-Log $logMessages.messages.menuNoneSelected -Level "warn"
        break
    }

    $isCustom = $mode -eq "custom"
    if ($isCustom) {
        # Custom: show the full interactive checkbox menu
        $fullList = Resolve-ScriptList -Config $config -Skip "" -Only ""
        $groups   = if ($config.groups) { $config.groups } else { $null }

        $scriptList = Show-InteractiveMenu -ScriptList $fullList -LogMessages $logMessages -Groups $groups

        $isUserQuit = $null -eq $scriptList
        if ($isUserQuit) {
            Write-Log $logMessages.messages.menuNoneSelected -Level "warn"
            continue
        }

        $hasNoSelection = $scriptList.Count -eq 0
        if ($hasNoSelection) {
            Write-Log $logMessages.messages.menuNoneSelected -Level "warn"
            continue
        }
    } else {
        # alldev or alldev+db: build list from mode
        $scriptList = Get-ScriptListForMode -Mode $mode -Config $config
    }

    # ── Step 2: Front-load all questions ──────────────────────────────────────
    Invoke-Questionnaire -Mode $mode -Config $config -LogMessages $logMessages -UseDefaults:$Defaults

    # Dev dir is now set in $env:DEV_DIR by the questionnaire
    $devDir = $env:DEV_DIR
    Initialize-DevDir -Path $devDir

    # ── Step 3: Run scripts unattended ────────────────────────────────────────
    Write-Log ($logMessages.messages.menuRunning -replace '\{count\}', $scriptList.Count) -Level "info"

    $results = Invoke-ScriptSequence -ScriptList $scriptList -ScriptsRoot $scriptsRoot -LogMessages $logMessages -Skip $Skip

    # ── Step 4: Summary ──────────────────────────────────────────────────────
    Show-Summary -Results $results -LogMessages $logMessages
    Write-Log $logMessages.messages.allComplete -Level "success"

    Save-ResolvedData -ScriptFolder "12-install-all-dev-tools" -Data @{
        mode      = $mode
        devDir    = $devDir
        results   = $results
        timestamp = (Get-Date -Format "o")
    }

    # Loop back
    Write-Host ""
    Write-Log $logMessages.messages.menuLoopBack -Level "info"
}

Save-LogFile -Status "ok"
