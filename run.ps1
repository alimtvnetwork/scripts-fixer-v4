<#
.SYNOPSIS
    Root-level script dispatcher. Runs a numbered script after pulling latest changes.

.DESCRIPTION
    Performs a git pull via the shared helper, sets $env:SCRIPTS_ROOT_RUN = "1"
    so child scripts skip their own git pull, then delegates to
    scripts/<NN>-*/run.ps1 based on the -I parameter.

    When run with no parameters, performs a git pull and shows help.
    Use -Install to run scripts by keyword (e.g. -Install vscode,python,go).
    Use -Clean to wipe all .resolved/ data before running, forcing fresh detection.
    Use -CleanOnly to wipe .resolved/ without running any script.
    Use -Help to see all available scripts and usage information.

.PARAMETER I
    The script number to run (e.g. 1, 2, 3). Maps to folders like 01-*, 02-*, etc.

.PARAMETER Install
    Comma-separated keywords to install (e.g. vscode, nodejs, python, go, git).
    See install-keywords.json for the full mapping.

.PARAMETER Clean
    Wipe all .resolved/ data before running the script.

.PARAMETER CleanOnly
    Wipe all .resolved/ data and exit without running any script.

.PARAMETER Help
    Show usage information and list all available scripts.

.EXAMPLE
    .\run.ps1                        # git pull, show help
    .\run.ps1 -Install vscode        # install VS Code
    .\run.ps1 -Install nodejs,pnpm   # install Node.js + pnpm
    .\run.ps1 -Install python        # install Python + pip
    .\run.ps1 -Install go,git,cpp    # install Go, Git, and C++
    .\run.ps1 -Install all-dev       # interactive dev tools menu
    .\run.ps1 -d                     # shortcut for -I 12 (interactive menu)
    .\run.ps1 -I 1                   # run scripts/01-*/run.ps1
    .\run.ps1 -I 1 -Clean           # wipe .resolved/, then run script 01
    .\run.ps1 -CleanOnly             # wipe .resolved/ and exit
    .\run.ps1 -Help                  # show all available scripts

.NOTES
    Author : Lovable AI
    Version: 6.0.0
#>

param(
    [int]$I,

    [string]$Install,

    [switch]$d,

    [switch]$a,

    [switch]$v,

    [switch]$w,

    [switch]$t,

    [switch]$Merge,

    [switch]$Clean,

    [switch]$CleanOnly,

    [switch]$Help
)

$ErrorActionPreference = "Stop"
$RootDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# ── Help function ────────────────────────────────────────────────────
function Show-RootHelp {
    Write-Host ""
    Write-Host "  Dev Tools Setup Scripts" -ForegroundColor Cyan
    Write-Host "  =======================" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Usage:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "    .\run.ps1 -Install <keywords>       " -NoNewline; Write-Host "Install by keyword (comma-separated)" -ForegroundColor DarkGray
    Write-Host "    .\run.ps1 -I <number>               " -NoNewline; Write-Host "Run a specific script by ID" -ForegroundColor DarkGray
    Write-Host "    .\run.ps1 -d                         " -NoNewline; Write-Host "Shortcut for -I 12 (interactive menu)" -ForegroundColor DarkGray
    Write-Host "    .\run.ps1 -a                         " -NoNewline; Write-Host "Shortcut for -I 13 (audit mode)" -ForegroundColor DarkGray
    Write-Host "    .\run.ps1 -v                         " -NoNewline; Write-Host "Shortcut for -I 1  (install VS Code)" -ForegroundColor DarkGray
    Write-Host "    .\run.ps1 -w                         " -NoNewline; Write-Host "Shortcut for -I 14 (install Winget)" -ForegroundColor DarkGray
    Write-Host "    .\run.ps1 -t                         " -NoNewline; Write-Host "Shortcut for -I 15 (Windows tweaks)" -ForegroundColor DarkGray
    Write-Host "    .\run.ps1 -I <number> -Merge        " -NoNewline; Write-Host "Run with merge flag (script 02)" -ForegroundColor DarkGray
    Write-Host "    .\run.ps1 -I <number> -Clean        " -NoNewline; Write-Host "Wipe cache, then run" -ForegroundColor DarkGray
    Write-Host "    .\run.ps1 -CleanOnly                 " -NoNewline; Write-Host "Wipe all cached data" -ForegroundColor DarkGray
    Write-Host "    .\run.ps1 -Help                      " -NoNewline; Write-Host "Show this help" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Install by Keyword:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "    .\run.ps1 -Install vscode            " -NoNewline; Write-Host "Install Visual Studio Code" -ForegroundColor DarkGray
    Write-Host "    .\run.ps1 -Install nodejs             " -NoNewline; Write-Host "Install Node.js + Yarn + Bun" -ForegroundColor DarkGray
    Write-Host "    .\run.ps1 -Install pnpm               " -NoNewline; Write-Host "Install Node.js + pnpm (auto-chains)" -ForegroundColor DarkGray
    Write-Host "    .\run.ps1 -Install python             " -NoNewline; Write-Host "Install Python + pip" -ForegroundColor DarkGray
    Write-Host "    .\run.ps1 -Install go                 " -NoNewline; Write-Host "Install Go + configure GOPATH" -ForegroundColor DarkGray
    Write-Host "    .\run.ps1 -Install git                " -NoNewline; Write-Host "Install Git + LFS + GitHub CLI" -ForegroundColor DarkGray
    Write-Host "    .\run.ps1 -Install cpp                " -NoNewline; Write-Host "Install C++ MinGW-w64 compiler" -ForegroundColor DarkGray
    Write-Host "    .\run.ps1 -Install php                " -NoNewline; Write-Host "Install PHP via Chocolatey" -ForegroundColor DarkGray
    Write-Host "    .\run.ps1 -Install powershell         " -NoNewline; Write-Host "Install latest PowerShell" -ForegroundColor DarkGray
    Write-Host "    .\run.ps1 -Install winget             " -NoNewline; Write-Host "Install Winget package manager" -ForegroundColor DarkGray
    Write-Host "    .\run.ps1 -Install settings-sync      " -NoNewline; Write-Host "Sync VSCode settings + extensions" -ForegroundColor DarkGray
    Write-Host "    .\run.ps1 -Install context-menu       " -NoNewline; Write-Host "Fix VSCode right-click context menu" -ForegroundColor DarkGray
    Write-Host "    .\run.ps1 -Install all-dev            " -NoNewline; Write-Host "Interactive dev tools menu (pick what to install)" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "    Combine keywords:" -ForegroundColor Magenta
    Write-Host "    .\run.ps1 -Install nodejs,pnpm       " -NoNewline; Write-Host "Install Node.js + pnpm" -ForegroundColor DarkGray
    Write-Host "    .\run.ps1 -Install go,git,cpp        " -NoNewline; Write-Host "Install Go, Git, and C++" -ForegroundColor DarkGray
    Write-Host "    .\run.ps1 -Install python,php        " -NoNewline; Write-Host "Install Python + PHP" -ForegroundColor DarkGray
    Write-Host "    .\run.ps1 -Install vscode,nodejs,git " -NoNewline; Write-Host "Install VS Code, Node.js, and Git" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Available Keywords:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "    Keyword              Maps to                         Script ID" -ForegroundColor DarkGray
    Write-Host "    -------------------  ------------------------------  ---------" -ForegroundColor DarkGray
    Write-Host "    vscode, vs-code      VS Code                         01"
    Write-Host "    choco, chocolatey    Chocolatey                      02"
    Write-Host "    nodejs, node         Node.js + Yarn + Bun            03"
    Write-Host "    pnpm                 Node.js + pnpm                  03, 04"
    Write-Host "    python, pip          Python + pip                    05"
    Write-Host "    go, golang           Go                              06"
    Write-Host "    git, gh              Git + LFS + GitHub CLI          07"
    Write-Host "    github-desktop       GitHub Desktop                  08"
    Write-Host "    cpp, c++, gcc        C++ (MinGW-w64)                 09"
    Write-Host "    context-menu         VSCode context menu fix         10"
    Write-Host "    settings-sync        VSCode settings sync            11"
    Write-Host "    all-dev, all         Interactive dev tools menu      12"
    Write-Host "    audit                Audit mode                      13"
    Write-Host "    winget               Winget package manager          14"
    Write-Host "    tweaks               Windows tweaks                  15"
    Write-Host "    php                  PHP                             16"
    Write-Host "    powershell, pwsh     PowerShell (latest)             17"
    Write-Host ""
    Write-Host "  Available Scripts:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "    ID  Name                          Description" -ForegroundColor DarkGray
    Write-Host "    --  ----------------------------  ------------------------------------------------" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "    Core Tools" -ForegroundColor Magenta
    Write-Host "    01  Install VS Code               " -NoNewline; Write-Host "Install Visual Studio Code (Stable/Insiders)" -ForegroundColor DarkGray
    Write-Host "    02  Chocolatey                    " -NoNewline; Write-Host "Install Chocolatey package manager" -ForegroundColor DarkGray
    Write-Host "    03  Node.js + Yarn + Bun          " -NoNewline; Write-Host "Install Node.js LTS, Yarn, Bun, verify npx" -ForegroundColor DarkGray
    Write-Host "    04  pnpm                          " -NoNewline; Write-Host "Install pnpm, configure global store" -ForegroundColor DarkGray
    Write-Host "    05  Python                        " -NoNewline; Write-Host "Install Python, configure pip user site" -ForegroundColor DarkGray
    Write-Host "    06  Golang                        " -NoNewline; Write-Host "Install Go, configure GOPATH and go env" -ForegroundColor DarkGray
    Write-Host "    07  Git + LFS + gh                " -NoNewline; Write-Host "Install Git, Git LFS, GitHub CLI, configure settings" -ForegroundColor DarkGray
    Write-Host "    08  GitHub Desktop                " -NoNewline; Write-Host "Install GitHub Desktop via Chocolatey" -ForegroundColor DarkGray
    Write-Host "    09  C++ (MinGW-w64)               " -NoNewline; Write-Host "Install MinGW-w64 C++ compiler, verify g++/gcc/make" -ForegroundColor DarkGray
    Write-Host "    16  PHP                           " -NoNewline; Write-Host "Install PHP via Chocolatey" -ForegroundColor DarkGray
    Write-Host "    17  PowerShell (latest)           " -NoNewline; Write-Host "Install latest PowerShell via Winget/Chocolatey" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "    Optional" -ForegroundColor Magenta
    Write-Host "    10  VSCode Context Menu Fix       " -NoNewline; Write-Host "Add/repair VSCode right-click context menu entries" -ForegroundColor DarkGray
    Write-Host "    11  VSCode Settings Sync          " -NoNewline; Write-Host "Sync VSCode settings, keybindings, and extensions" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "    Orchestrator" -ForegroundColor Magenta
    Write-Host "    12  Install All Dev Tools         " -NoNewline; Write-Host "Interactive grouped menu: pick tools or install everything" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "    Utilities" -ForegroundColor Magenta
    Write-Host "    13  Audit Mode                    " -NoNewline; Write-Host "Scan configs, specs, suggestions for stale IDs" -ForegroundColor DarkGray
    Write-Host "    14  Install Winget                " -NoNewline; Write-Host "Install/verify Winget package manager (standalone)" -ForegroundColor DarkGray
    Write-Host "    15  Windows Tweaks                " -NoNewline; Write-Host "Chris Titus Windows Utility (tweaks and debloating)" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Script 12 (Install All Dev Tools):" -ForegroundColor Yellow
    Write-Host "    .\run.ps1 -I 12                         " -NoNewline; Write-Host "Interactive menu -- pick what to install" -ForegroundColor DarkGray
    Write-Host "    .\run.ps1 -I 12 -- -All                 " -NoNewline; Write-Host "Install everything without prompting" -ForegroundColor DarkGray
    Write-Host "    .\run.ps1 -I 12 -- -Skip 04,06          " -NoNewline; Write-Host "Skip pnpm and Go" -ForegroundColor DarkGray
    Write-Host "    .\run.ps1 -I 12 -- -Only 02,03          " -NoNewline; Write-Host "Run only Package Managers + Node.js" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Per-script help:" -ForegroundColor Yellow
    Write-Host "    .\run.ps1 -I <number> -- -Help          " -NoNewline; Write-Host "Show help for a specific script" -ForegroundColor DarkGray
    Write-Host ""
}

# ── Resolve keywords to script IDs ──────────────────────────────────
function Resolve-InstallKeywords {
    param(
        [string]$Keywords
    )

    $keywordsFile = Join-Path $RootDir "scripts\shared\install-keywords.json"
    $isKeywordsFileMissing = -not (Test-Path $keywordsFile)
    if ($isKeywordsFileMissing) {
        Write-Host "  [ FAIL ] " -ForegroundColor Red -NoNewline
        Write-Host "Keyword mapping not found: $keywordsFile"
        return $null
    }

    $keywordMap = (Get-Content $keywordsFile -Raw | ConvertFrom-Json).keywords

    $tokens = $Keywords -split "," | ForEach-Object { $_.Trim().ToLower() } | Where-Object { $_.Length -gt 0 }
    $scriptIds = [System.Collections.Generic.List[int]]::new()
    $hasError = $false

    foreach ($token in $tokens) {
        # Try exact match first, then try without hyphens
        $ids = $keywordMap.$token
        if ($null -eq $ids) {
            $stripped = $token -replace '-', ''
            $ids = $keywordMap.$stripped
        }
        $isUnknown = $null -eq $ids
        if ($isUnknown) {
            Write-Host "  [ FAIL ] " -ForegroundColor Red -NoNewline
            Write-Host "Unknown keyword: '$token'"
            $hasError = $true
            continue
        }

        foreach ($id in $ids) {
            $isAlreadyAdded = $scriptIds -contains $id
            if (-not $isAlreadyAdded) {
                $scriptIds.Add($id)
            }
        }
    }

    if ($hasError) {
        Write-Host ""
        Write-Host "  Run .\run.ps1 -Help to see all available keywords" -ForegroundColor Cyan
        return $null
    }

    # Sort by ID for logical execution order
    $sorted = $scriptIds | Sort-Object
    return $sorted
}

# ── Run a single script by ID ───────────────────────────────────────
function Invoke-ScriptById {
    param(
        [int]$ScriptId,
        [hashtable]$ExtraArgs = @{}
    )

    $prefix = "{0:D2}" -f $ScriptId
    $registryPath = Join-Path $RootDir "scripts\registry.json"
    $isRegistryAvailable = Test-Path $registryPath

    $scriptDir = $null
    if ($isRegistryAvailable) {
        $registry = Get-Content $registryPath -Raw | ConvertFrom-Json
        $folderName = $registry.scripts.$prefix

        $isRegistered = [bool]$folderName
        if ($isRegistered) {
            $scriptDir = Get-Item (Join-Path $RootDir "scripts\$folderName") -ErrorAction SilentlyContinue
        }
    } else {
        $pattern = Join-Path $RootDir "scripts/$prefix-*"
        $scriptDir = @(Get-Item $pattern -ErrorAction SilentlyContinue |
            Where-Object { $_.PSIsContainer -and (Test-Path (Join-Path $_.FullName "run.ps1")) }) |
            Select-Object -First 1
    }

    $isScriptMissing = -not $scriptDir -or -not (Test-Path $scriptDir.FullName)
    if ($isScriptMissing) {
        Write-Host ""
        Write-Host "  [ FAIL ] " -ForegroundColor Red -NoNewline
        Write-Host "No script folder found for ID $prefix"
        return $false
    }

    $scriptFile = Join-Path $scriptDir.FullName "run.ps1"
    $isRunFileMissing = -not (Test-Path $scriptFile)
    if ($isRunFileMissing) {
        Write-Host "  [ FAIL ] " -ForegroundColor Red -NoNewline
        Write-Host "run.ps1 not found in $($scriptDir.Name)"
        return $false
    }

    # Clean & create logs folder
    $logsDir = Join-Path $scriptDir.FullName "logs"
    if (Test-Path $logsDir) {
        Remove-Item -Path $logsDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    New-Item -Path $logsDir -ItemType Directory -Force | Out-Null

    Write-Host ""
    Write-Host "  [ RUN   ] " -ForegroundColor Magenta -NoNewline
    Write-Host "Executing: $($scriptDir.Name)\run.ps1"
    Write-Host ""

    & $scriptFile @ExtraArgs
    return $true
}

# ── No params = git pull + help ──────────────────────────────────────
$hasNoParams = -not $I -and -not $Install -and -not $d -and -not $a -and -not $v -and -not $w -and -not $t -and -not $Help -and -not $CleanOnly -and -not $Clean
if ($hasNoParams) {
    Remove-Item Env:\SCRIPTS_ROOT_RUN -ErrorAction SilentlyContinue
    $sharedGitPull = Join-Path $RootDir "scripts\shared\git-pull.ps1"
    $isHelperAvailable = Test-Path $sharedGitPull
    if ($isHelperAvailable) {
        . $sharedGitPull
        Invoke-GitPull -RepoRoot $RootDir
    }
    Show-RootHelp
    exit 0
}

# ── Help ─────────────────────────────────────────────────────────────
if ($Help) {
    Show-RootHelp
    exit 0
}

# ── Handle -CleanOnly (no -I required) ───────────────────────────────
if ($CleanOnly) {
    $resolvedDir = Join-Path $RootDir ".resolved"
    if (Test-Path $resolvedDir) {
        Get-ChildItem -Path $resolvedDir -Recurse -Force | Remove-Item -Recurse -Force
        Write-Host "  [ CLEAN ] " -ForegroundColor Green -NoNewline
        Write-Host "All .resolved/ data wiped"
    } else {
        Write-Host "  [ SKIP  ] " -ForegroundColor DarkGray -NoNewline
        Write-Host "Nothing to clean -- .resolved/ does not exist"
    }
    exit 0
}

# ── Handle -Clean ────────────────────────────────────────────────────
if ($Clean) {
    $resolvedDir = Join-Path $RootDir ".resolved"
    if (Test-Path $resolvedDir) {
        Get-ChildItem -Path $resolvedDir -Recurse -Force | Remove-Item -Recurse -Force
        Write-Host "  [ CLEAN ] " -ForegroundColor Green -NoNewline
        Write-Host "All .resolved/ data wiped -- fresh detection will run"
    } else {
        Write-Host "  [ SKIP  ] " -ForegroundColor DarkGray -NoNewline
        Write-Host "Nothing to clean -- .resolved/ does not exist"
    }
    Write-Host ""
}

# ── Load shared git-pull helper ──────────────────────────────────────
$sharedGitPull = Join-Path $RootDir "scripts\shared\git-pull.ps1"
$isHelperMissing = -not (Test-Path $sharedGitPull)
if ($isHelperMissing) {
    Write-Host "  [ FAIL ] " -ForegroundColor Red -NoNewline
    Write-Host "Shared helper not found: $sharedGitPull"
    exit 1
}
. $sharedGitPull

# ── Git Pull ─────────────────────────────────────────────────────────
Invoke-GitPull -RepoRoot $RootDir

# ── Set flag so child scripts skip git pull ──────────────────────────
$env:SCRIPTS_ROOT_RUN = "1"

# ── Handle -Install keyword mode ─────────────────────────────────────
$hasInstallKeyword = $Install.Length -gt 0
if ($hasInstallKeyword) {
    $scriptIds = Resolve-InstallKeywords -Keywords $Install

    $isResolveFailed = $null -eq $scriptIds
    if ($isResolveFailed) { exit 1 }

    $totalScripts = $scriptIds.Count
    Write-Host ""
    Write-Host "  [ INFO ] " -ForegroundColor Cyan -NoNewline
    Write-Host "Installing $totalScripts tool(s): $($scriptIds -join ', ')"
    Write-Host ""

    $successCount = 0
    $failCount    = 0

    foreach ($id in $scriptIds) {
        $result = Invoke-ScriptById -ScriptId $id
        if ($result) { $successCount++ } else { $failCount++ }
    }

    Write-Host ""
    Write-Host "  ======================================" -ForegroundColor DarkGray
    Write-Host "  [ DONE ] " -ForegroundColor Green -NoNewline
    Write-Host "$successCount of $totalScripts completed successfully"
    if ($failCount -gt 0) {
        Write-Host "  [ WARN ] " -ForegroundColor Yellow -NoNewline
        Write-Host "$failCount script(s) failed"
    }

    Remove-Item Env:\SCRIPTS_ROOT_RUN -ErrorAction SilentlyContinue
    exit 0
}

# ── Expand shortcuts ──────────────────────────────────────────────────
if ($d) { $I = 12 }
if ($a) { $I = 13 }
if ($v) { $I = 1 }
if ($w) { $I = 14 }
if ($t) { $I = 15 }

# ── Validate -I is provided ──────────────────────────────────────────
$isMissingParam = -not $I
if ($isMissingParam) {
    Write-Host "  [ FAIL ] " -ForegroundColor Red -NoNewline
    Write-Host "Missing -I parameter. Usage: .\run.ps1 -I <number>"
    Write-Host ""
    Write-Host "  Run .\run.ps1 -Help to see all available scripts" -ForegroundColor Cyan
    exit 1
}

# ── Delegate to single script ────────────────────────────────────────
$scriptArgs = @{}
if ($Merge) { $scriptArgs["Merge"] = $true }

$result = Invoke-ScriptById -ScriptId $I -ExtraArgs $scriptArgs

$isScriptFailed = -not $result
if ($isScriptFailed) { exit 1 }

# ── Clean up env flag ────────────────────────────────────────────────
Remove-Item Env:\SCRIPTS_ROOT_RUN -ErrorAction SilentlyContinue
