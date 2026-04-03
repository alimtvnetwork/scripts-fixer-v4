# --------------------------------------------------------------------------
#  Audit helper -- individual check functions
# --------------------------------------------------------------------------

$_sharedDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "shared"
$_loggingPath = Join-Path $_sharedDir "logging.ps1"
if ((Test-Path $_loggingPath) -and -not (Get-Command Write-Log -ErrorAction SilentlyContinue)) {
    . $_loggingPath
}

function Write-CheckResult {
    param(
        [string]$CheckName,
        [bool]$Passed,
        [string[]]$Details,
        $LogMessages
    )

    if ($Passed) {
        $msg = $LogMessages.messages.checkPass -replace '\{check\}', $CheckName
        Write-Log $msg -Level "success"
    } else {
        $msg = $LogMessages.messages.checkFail -replace '\{check\}', $CheckName
        Write-Log $msg -Level "error"
        foreach ($d in $Details) {
            $detailMsg = $LogMessages.messages.detail -replace '\{detail\}', $d
            Write-Host "  $detailMsg" -ForegroundColor DarkGray
        }
    }
}

# --------------------------------------------------------------------------
#  Check 1: Registry vs folders
# --------------------------------------------------------------------------
function Test-RegistryVsFolders {
    param(
        [string]$RepoRoot,
        $Registry,
        $LogMessages
    )

    $issues = @()
    $scriptsDir = Join-Path $RepoRoot "scripts"

    # Every registry entry must have a matching folder
    foreach ($prop in $Registry.scripts.PSObject.Properties) {
        $id = $prop.Name
        $folder = $prop.Value
        $folderPath = Join-Path $scriptsDir $folder
        $isMissing = -not (Test-Path $folderPath)
        if ($isMissing) {
            $issues += "Registry ID '$id' maps to '$folder' but folder does not exist"
        }
    }

    # Every numbered folder must be in the registry
    $numberedFolders = Get-ChildItem -Path $scriptsDir -Directory | Where-Object { $_.Name -match '^\d{2}-' }
    foreach ($dir in $numberedFolders) {
        $prefix = $dir.Name.Substring(0, 2)
        $isInRegistry = $null -ne $Registry.scripts.$prefix
        if (-not $isInRegistry) {
            $issues += "Folder '$($dir.Name)' (prefix $prefix) not found in registry.json"
        }
    }

    $isPassed = $issues.Count -eq 0
    Write-CheckResult -CheckName "Registry vs folders" -Passed $isPassed -Details $issues -LogMessages $LogMessages
    return @{ Passed = $isPassed; Issues = $issues }
}

# --------------------------------------------------------------------------
#  Check 2: Orchestrator config vs registry
# --------------------------------------------------------------------------
function Test-OrchestratorConfig {
    param(
        [string]$RepoRoot,
        $Registry,
        $LogMessages
    )

    $issues = @()
    $configPath = Join-Path $RepoRoot "scripts\12-install-all-dev-tools\config.json"
    $isConfigMissing = -not (Test-Path $configPath)
    if ($isConfigMissing) {
        $issues += "Orchestrator config.json not found"
        Write-CheckResult -CheckName "Orchestrator config vs registry" -Passed $false -Details $issues -LogMessages $LogMessages
        return @{ Passed = $false; Issues = $issues }
    }

    $orchConfig = Get-Content $configPath -Raw | ConvertFrom-Json

    # Check sequence IDs
    foreach ($id in $orchConfig.sequence) {
        $isInRegistry = $null -ne $Registry.scripts.$id
        if (-not $isInRegistry) {
            $issues += "Sequence ID '$id' not found in registry.json"
        }
    }

    # Check scripts block IDs
    foreach ($prop in $orchConfig.scripts.PSObject.Properties) {
        $id = $prop.Name
        $isInRegistry = $null -ne $Registry.scripts.$id
        if (-not $isInRegistry) {
            $issues += "Scripts block ID '$id' not found in registry.json"
        }
        # Also verify folder matches registry
        if ($isInRegistry) {
            $registryFolder = $Registry.scripts.$id
            $configFolder = $prop.Value.folder
            $isMismatch = $registryFolder -ne $configFolder
            if ($isMismatch) {
                $issues += "ID '$id': registry says '$registryFolder' but orchestrator config says '$configFolder'"
            }
        }
    }

    $isPassed = $issues.Count -eq 0
    Write-CheckResult -CheckName "Orchestrator config vs registry" -Passed $isPassed -Details $issues -LogMessages $LogMessages
    return @{ Passed = $isPassed; Issues = $issues }
}

# --------------------------------------------------------------------------
#  Check 3: Orchestrator groups vs scripts
# --------------------------------------------------------------------------
function Test-OrchestratorGroups {
    param(
        [string]$RepoRoot,
        $LogMessages
    )

    $issues = @()
    $configPath = Join-Path $RepoRoot "scripts\12-install-all-dev-tools\config.json"
    $isConfigMissing = -not (Test-Path $configPath)
    if ($isConfigMissing) {
        $issues += "Orchestrator config.json not found"
        Write-CheckResult -CheckName "Orchestrator groups vs scripts" -Passed $false -Details $issues -LogMessages $LogMessages
        return @{ Passed = $false; Issues = $issues }
    }

    $orchConfig = Get-Content $configPath -Raw | ConvertFrom-Json
    $hasGroups = $null -ne $orchConfig.groups

    if ($hasGroups) {
        foreach ($group in $orchConfig.groups) {
            foreach ($gid in $group.ids) {
                $isInScripts = $null -ne $orchConfig.scripts.$gid
                if (-not $isInScripts) {
                    $issues += "Group '$($group.label)' references ID '$gid' not found in scripts block"
                }
            }
        }
    }

    $isPassed = $issues.Count -eq 0
    Write-CheckResult -CheckName "Orchestrator groups vs scripts" -Passed $isPassed -Details $issues -LogMessages $LogMessages
    return @{ Passed = $isPassed; Issues = $issues }
}

# --------------------------------------------------------------------------
#  Check 4: Spec folder coverage
# --------------------------------------------------------------------------
function Test-SpecCoverage {
    param(
        [string]$RepoRoot,
        $Registry,
        $LogMessages
    )

    $issues = @()
    $specDir = Join-Path $RepoRoot "spec"

    foreach ($prop in $Registry.scripts.PSObject.Properties) {
        $id = $prop.Name
        $folder = $prop.Value
        $specPath = Join-Path $specDir "$folder\readme.md"
        $isMissing = -not (Test-Path $specPath)
        if ($isMissing) {
            $issues += "No spec found for ID '$id' (expected spec/$folder/readme.md)"
        }
    }

    $isPassed = $issues.Count -eq 0
    Write-CheckResult -CheckName "Spec folder coverage" -Passed $isPassed -Details $issues -LogMessages $LogMessages
    return @{ Passed = $isPassed; Issues = $issues }
}

# --------------------------------------------------------------------------
#  Check 5: Config + log-messages existence
# --------------------------------------------------------------------------
function Test-ConfigLogMessages {
    param(
        [string]$RepoRoot,
        $Registry,
        $LogMessages
    )

    $issues = @()
    $scriptsDir = Join-Path $RepoRoot "scripts"

    foreach ($prop in $Registry.scripts.PSObject.Properties) {
        $id = $prop.Name
        $folder = $prop.Value
        $folderPath = Join-Path $scriptsDir $folder
        $isFolderMissing = -not (Test-Path $folderPath)
        if ($isFolderMissing) { continue }

        $configPath = Join-Path $folderPath "config.json"
        $logMsgPath = Join-Path $folderPath "log-messages.json"

        $isConfigMissing = -not (Test-Path $configPath)
        $isLogMsgMissing = -not (Test-Path $logMsgPath)

        if ($isConfigMissing) {
            $issues += "ID '$id' ($folder): missing config.json"
        }
        if ($isLogMsgMissing) {
            $issues += "ID '$id' ($folder): missing log-messages.json"
        }
    }

    $isPassed = $issues.Count -eq 0
    Write-CheckResult -CheckName "Config + log-messages existence" -Passed $isPassed -Details $issues -LogMessages $LogMessages
    return @{ Passed = $isPassed; Issues = $issues }
}

# --------------------------------------------------------------------------
#  Check 6 & 7: Stale ID references in markdown files
# --------------------------------------------------------------------------
function Test-StaleRefsInMarkdown {
    param(
        [string]$SearchDir,
        [string]$CheckName,
        $Registry,
        $LogMessages
    )

    $issues = @()
    $isSearchDirMissing = -not (Test-Path $SearchDir)
    if ($isSearchDirMissing) {
        Write-CheckResult -CheckName $CheckName -Passed $true -Details @() -LogMessages $LogMessages
        return @{ Passed = $true; Issues = @() }
    }

    # Build set of valid IDs and folder names
    $validIds = @()
    $validFolders = @()
    foreach ($prop in $Registry.scripts.PSObject.Properties) {
        $validIds += $prop.Name
        $validFolders += $prop.Value
    }

    $mdFiles = Get-ChildItem -Path $SearchDir -Filter "*.md" -Recurse
    foreach ($file in $mdFiles) {
        $content = Get-Content $file.FullName -Raw

        # Look for "Script NN" references
        $scriptRefs = [regex]::Matches($content, 'Script\s+(\d{2})')
        foreach ($match in $scriptRefs) {
            $refId = $match.Groups[1].Value
            $isValid = $refId -in $validIds
            if (-not $isValid) {
                $issues += "$($file.Name): references 'Script $refId' but no such ID in registry"
            }
        }

        # Look for "scripts/NN-" folder references
        $folderRefs = [regex]::Matches($content, 'scripts/(\d{2}-[a-zA-Z0-9-]+)')
        foreach ($match in $folderRefs) {
            $refFolder = $match.Groups[1].Value
            $isValid = $refFolder -in $validFolders
            if (-not $isValid) {
                $issues += "$($file.Name): references folder '$refFolder' not found in registry"
            }
        }
    }

    $isPassed = $issues.Count -eq 0
    Write-CheckResult -CheckName $CheckName -Passed $isPassed -Details $issues -LogMessages $LogMessages
    return @{ Passed = $isPassed; Issues = $issues }
}

# --------------------------------------------------------------------------
#  Check 8: Stale ID references in PowerShell files
# --------------------------------------------------------------------------
function Test-StaleRefsInPowerShell {
    param(
        [string]$RepoRoot,
        $Registry,
        $LogMessages
    )

    $issues = @()
    $scriptsDir = Join-Path $RepoRoot "scripts"

    # Build valid folder names
    $validFolders = @()
    foreach ($prop in $Registry.scripts.PSObject.Properties) {
        $validFolders += $prop.Value
    }

    $ps1Files = Get-ChildItem -Path $scriptsDir -Filter "*.ps1" -Recurse
    foreach ($file in $ps1Files) {
        $content = Get-Content $file.FullName -Raw

        # Look for hardcoded folder references like "01-install-vscode"
        $folderRefs = [regex]::Matches($content, '(\d{2}-[a-zA-Z0-9]+-[a-zA-Z0-9-]+)')
        foreach ($match in $folderRefs) {
            $refFolder = $match.Groups[1].Value
            # Skip if it matches a valid folder
            $isValid = $refFolder -in $validFolders
            # Skip common false positives (dates, version strings, etc.)
            $isFalsePositive = $refFolder -match '^\d{2}-\d{2}' -or $refFolder -match 'yyyyMMdd'
            if (-not $isValid -and -not $isFalsePositive) {
                $relativePath = $file.FullName.Replace($RepoRoot, '').TrimStart('\', '/')
                $issues += "${relativePath}: references folder '$refFolder' not found in registry"
            }
        }
    }

    $isPassed = $issues.Count -eq 0
    Write-CheckResult -CheckName "Stale refs in PowerShell" -Passed $isPassed -Details $issues -LogMessages $LogMessages
    return @{ Passed = $isPassed; Issues = $issues }
}