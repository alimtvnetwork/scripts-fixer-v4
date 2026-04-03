<#
.SYNOPSIS
    Restores "Open with Code" to the Windows right-click context menu.

.DESCRIPTION
    Reads paths from config.json and log messages from log-messages.json,
    then creates the required registry entries for files, folders, and
    folder backgrounds. Supports both VS Code Stable and Insiders editions.
    Must be run as Administrator.

.NOTES
    Author : Lovable AI
    Version: 2.0.0
#>

# ── Helpers ──────────────────────────────────────────────────────────

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("ok","fail","info","warn","skip")]
        [string]$Status = "info"
    )

    $badge  = $script:LogMessages.status.$Status
    $colors = @{
        ok   = "Green"
        fail = "Red"
        info = "Cyan"
        warn = "Yellow"
        skip = "DarkGray"
    }

    Write-Host "  $badge " -ForegroundColor $colors[$Status] -NoNewline
    Write-Host $Message
}

function Write-Banner {
    param([string[]]$Lines, [string]$Color = "Magenta")
    Write-Host ""
    foreach ($line in $Lines) { Write-Host $line -ForegroundColor $Color }
    Write-Host ""
}

# ── Core Functions ───────────────────────────────────────────────────

function Assert-Admin {
    Write-Log "Checking Administrator privileges..." "info"
    $identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    $isAdmin   = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    Write-Log "Current user: $($identity.Name)" "info"
    Write-Log "Is Administrator: $isAdmin" $(if ($isAdmin) { "ok" } else { "fail" })
    return $isAdmin
}

function Initialize-Logging {
    param([string]$ScriptDir)

    $logsDir = Join-Path $ScriptDir "logs"
    Write-Host "  [ INFO ] Log directory: $logsDir" -ForegroundColor Cyan

    # Clean and recreate
    if (Test-Path $logsDir) {
        Write-Host "  [ INFO ] Removing old logs folder..." -ForegroundColor Cyan
        Remove-Item -Path $logsDir -Recurse -Force -Confirm:$false
    }
    New-Item -Path $logsDir -ItemType Directory -Force -Confirm:$false | Out-Null
    Write-Host "  [  OK  ] Logs folder created" -ForegroundColor Green

    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $logFile   = Join-Path $logsDir "run-$timestamp.log"
    Write-Host "  [ INFO ] Transcript file: $logFile" -ForegroundColor Cyan

    Start-Transcript -Path $logFile -Force | Out-Null
    return $logFile
}

function Import-JsonConfig {
    param(
        [string]$FilePath,
        [string]$Label
    )

    Write-Log "Loading $Label from: $FilePath"
    if (-not (Test-Path $FilePath)) {
        Write-Log "$Label not found at path: $FilePath" "fail"
        return $null
    }

    $content = Get-Content $FilePath -Raw
    Write-Log "$Label file size: $($content.Length) chars" "info"

    $parsed = $content | ConvertFrom-Json
    Write-Log "$Label loaded successfully" "ok"
    return $parsed
}


function Resolve-VsCodePath {
    param(
        [PSCustomObject]$PathConfig,
        [string]$PreferredType
    )

    Write-Log "Preferred installation type: $PreferredType"

    # Try preferred path
    $rawPath = $PathConfig.$PreferredType
    Write-Log "Raw config value ($PreferredType): $rawPath"
    $exePath = [System.Environment]::ExpandEnvironmentVariables($rawPath)
    Write-Log "Expanded path: $exePath"

    $exists = Test-Path $exePath
    Write-Log "File exists at expanded path: $exists" $(if ($exists) { "ok" } else { "warn" })

    if ($exists) { return $exePath }

    # Fallback
    $fallbackType = if ($PreferredType -eq "user") { "system" } else { "user" }
    Write-Log "Trying fallback type: $fallbackType" "warn"

    $fallbackRaw = $PathConfig.$fallbackType
    Write-Log "Raw config value ($fallbackType): $fallbackRaw"
    $fallbackExe = [System.Environment]::ExpandEnvironmentVariables($fallbackRaw)
    Write-Log "Expanded fallback path: $fallbackExe"

    $fallbackExists = Test-Path $fallbackExe
    Write-Log "File exists at fallback path: $fallbackExists" $(if ($fallbackExists) { "ok" } else { "fail" })

    if ($fallbackExists) { return $fallbackExe }

    Write-Log "No valid VS Code executable found for either type" "fail"
    return $null
}

function Register-ContextMenu {
    param(
        [string]$StepLabel,
        [string]$RegistryPath,
        [string]$Label,
        [string]$IconValue,
        [string]$CommandArg
    )

    Write-Log "$StepLabel"
    Write-Log "  Registry path : $RegistryPath"
    Write-Log "  Label         : $Label"
    Write-Log "  Icon          : $IconValue"
    Write-Log "  Command       : $CommandArg"

    try {
        Write-Log "  Creating registry key..." "info"
        New-Item -LiteralPath $RegistryPath -Force -Confirm:$false -ErrorAction Stop | Out-Null
        Write-Log "  Key created" "ok"

        Write-Log "  Setting (Default) = $Label" "info"
        Set-Item -LiteralPath $RegistryPath -Value $Label -Force -Confirm:$false -ErrorAction Stop
        Write-Log "  (Default) set" "ok"

        Write-Log "  Setting Icon = $IconValue" "info"
        Set-ItemProperty -LiteralPath $RegistryPath -Name "Icon" -Value $IconValue -Force -Confirm:$false -ErrorAction Stop
        Write-Log "  Icon set" "ok"

        $cmdPath = "$RegistryPath\command"
        Write-Log "  Creating command subkey: $cmdPath" "info"
        New-Item -LiteralPath $cmdPath -Force -Confirm:$false -ErrorAction Stop | Out-Null
        Write-Log "  Command subkey created" "ok"

        Write-Log "  Setting command (Default) = $CommandArg" "info"
        Set-Item -LiteralPath $cmdPath -Value $CommandArg -Force -Confirm:$false -ErrorAction Stop
        Write-Log "  Command value set" "ok"

        return $true
    } catch {
        Write-Log "  FAILED: $_" "fail"
        Write-Log "  Stack: $($_.ScriptStackTrace)" "fail"
        return $false
    }
}

function Test-RegistryEntry {
    param(
        [string]$RegistryPath,
        [string]$Label
    )

    Write-Log "  Verifying: $RegistryPath"
    if (Test-Path -LiteralPath $RegistryPath) {
        Write-Log "  [pass] $Label -- $RegistryPath" "ok"
        return $true
    } else {
        Write-Log "  [miss] $Label -- $RegistryPath" "fail"
        return $false
    }
}

function Invoke-Edition {
    param(
        [PSCustomObject]$Edition,
        [string]$EditionName,
        [string]$InstallType,
        [hashtable]$Steps
    )

    Write-Host ""
    Write-Host "  +----------------------------------------------" -ForegroundColor DarkCyan
    Write-Host "  |  Edition: $($Edition.contextMenuLabel)" -ForegroundColor Cyan
    Write-Host "  +----------------------------------------------" -ForegroundColor DarkCyan

    # Resolve exe
    Write-Log $Steps.detectInstall
    $VsCodeExe = Resolve-VsCodePath -PathConfig $Edition.vscodePath -PreferredType $InstallType

    if (-not $VsCodeExe) {
        Write-Log "$($Edition.contextMenuLabel): executable not found -- skipping" "warn"
        return $false
    }
    Write-Log "Using executable: $VsCodeExe" "ok"

    $Label   = $Edition.contextMenuLabel
    $IconVal = "`"$VsCodeExe`""

    # Define entries
    $entries = @(
        @{ Step = $Steps.regFile; Path = $Edition.registryPaths.file;       CmdArg = "`"$VsCodeExe`" `"%1`"" },
        @{ Step = $Steps.regDir;  Path = $Edition.registryPaths.directory;  CmdArg = "`"$VsCodeExe`" `"%V`"" },
        @{ Step = $Steps.regBg;   Path = $Edition.registryPaths.background; CmdArg = "`"$VsCodeExe`" `"%V`"" }
    )

    $allOk = $true

    # Register
    foreach ($entry in $entries) {
        $result = Register-ContextMenu `
            -StepLabel  $entry.Step `
            -RegistryPath $entry.Path `
            -Label      $Label `
            -IconValue  $IconVal `
            -CommandArg $entry.CmdArg
        if (-not $result) { $allOk = $false }
    }

    # Verify
    Write-Log $Steps.verify
    foreach ($entry in $entries) {
        $result = Test-RegistryEntry -RegistryPath $entry.Path -Label $entry.Step
        if (-not $result) { $allOk = $false }
    }

    return $allOk
}

# ── Main ─────────────────────────────────────────────────────────────

function Main {
    $ErrorActionPreference = "Stop"
    $ScriptDir = Split-Path -Parent $MyInvocation.PSCommandPath

    # If PSCommandPath is empty (PS 2.0), fall back
    if (-not $ScriptDir) {
        $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
    }

    Write-Host "  [ INFO ] Script directory: $ScriptDir" -ForegroundColor Cyan

    # Load shared git-pull helper and run
    $sharedGitPull = Join-Path $ScriptDir "..\shared\git-pull.ps1"
    if (Test-Path $sharedGitPull) {
        . $sharedGitPull
        $repoRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)
        Invoke-GitPull -RepoRoot $repoRoot
    } else {
        Write-Host "  [ WARN  ] " -ForegroundColor Yellow -NoNewline
        Write-Host "Shared git-pull helper not found -- skipping git pull"
    }

    # Start logging
    $logFile = Initialize-Logging -ScriptDir $ScriptDir

    try {
        # Load log messages
        $logPath = Join-Path $ScriptDir "log-messages.json"
        $script:LogMessages = Import-JsonConfig -FilePath $logPath -Label "log-messages.json"
        if (-not $script:LogMessages) { exit 1 }

        Write-Banner $script:LogMessages.banner

        # Check admin
        if (-not (Assert-Admin)) {
            Write-Log $script:LogMessages.errors.notAdmin "fail"
            Write-Host ""
            Write-Host "  Tip: Right-click PowerShell -> 'Run as Administrator'" -ForegroundColor Yellow
            exit 1
        }

        # Load config
        $cfgPath = Join-Path $ScriptDir "config.json"
        $Config = Import-JsonConfig -FilePath $cfgPath -Label "config.json"
        if (-not $Config) { exit 1 }

        $installType     = $Config.installationType
        $enabledEditions = $Config.enabledEditions
        $totalSuccess    = $true

        Write-Log "Installation type preference: $installType" "info"
        Write-Log "Enabled editions: $($enabledEditions -join ', ')" "info"

        # Process each edition
        foreach ($editionName in $enabledEditions) {
            $edition = $Config.editions.$editionName

            if (-not $edition) {
                Write-Log "Unknown edition '$editionName' in enabledEditions -- skipping" "warn"
                $totalSuccess = $false
                continue
            }

            $result = Invoke-Edition `
                -Edition     $edition `
                -EditionName $editionName `
                -InstallType $installType `
                -Steps       @{
                    detectInstall = $script:LogMessages.steps.detectInstall
                    regFile       = $script:LogMessages.steps.regFile
                    regDir        = $script:LogMessages.steps.regDir
                    regBg         = $script:LogMessages.steps.regBg
                    verify        = $script:LogMessages.steps.verify
                }

            if (-not $result) { $totalSuccess = $false }
        }

        # Summary
        Write-Host ""
        if ($totalSuccess) {
            Write-Log $script:LogMessages.steps.done "ok"
        } else {
            Write-Log "Completed with some warnings -- check output above." "warn"
        }

        Write-Banner $script:LogMessages.footer "Green"

    } catch {
        Write-Host ""
        Write-Log "Unhandled error: $_" "fail"
        Write-Log "Stack: $($_.ScriptStackTrace)" "fail"
        Write-Host ""
        Write-Log "Log saved to: $logFile" "info"
    } finally {
        Stop-Transcript -ErrorAction SilentlyContinue | Out-Null
        Write-Host "  [ LOG  ] Transcript saved: $logFile" -ForegroundColor DarkGray
    }
}

# ── Entry Point ──────────────────────────────────────────────────────
Main
