# --------------------------------------------------------------------------
#  VS Code helper functions
# --------------------------------------------------------------------------

# -- Bootstrap shared helpers --------------------------------------------------
$_sharedDir = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "shared"
$_loggingPath = Join-Path $_sharedDir "logging.ps1"
if ((Test-Path $_loggingPath) -and -not (Get-Command Write-Log -ErrorAction SilentlyContinue)) {
    . $_loggingPath
}


function Install-VsCodeEdition {
    param(
        [string]$ChocoPackageName,
        [string]$Label,
        $LogMessages
    )

    Write-Log ($LogMessages.messages.installingEdition -replace '\{label\}', $Label) -Level "info"

    # Check if already installed
    $existing = choco list --local-only --exact $ChocoPackageName 2>&1
    $isInstalled = $LASTEXITCODE -eq 0 -and $existing -match $ChocoPackageName
    if ($isInstalled) {
        Write-Log ($LogMessages.messages.editionAlreadyInstalled -replace '\{label\}', $Label) -Level "info"
        Upgrade-ChocoPackage -PackageName $ChocoPackageName
        Write-Log ($LogMessages.messages.editionUpgradeSuccess -replace '\{label\}', $Label) -Level "success"
        return $true
    }

    Write-Log ($LogMessages.messages.editionNotFound -replace '\{label\}', $Label) -Level "warn"
    $installResult = Install-ChocoPackage -PackageName $ChocoPackageName
    if ($installResult) {
        Write-Log ($LogMessages.messages.editionInstallSuccess -replace '\{label\}', $Label) -Level "success"
    }
    return $installResult
}

function Invoke-VsCodeSetup {
    param(
        $Config,
        $LogMessages,
        [string]$Command
    )

    $editions = $Config.editions

    switch ($Command) {
        "stable" {
            Install-VsCodeEdition -ChocoPackageName $editions.stable.chocoPackageName `
                                   -Label $editions.stable.label `
                                   -LogMessages $LogMessages
        }
        "insiders" {
            Install-VsCodeEdition -ChocoPackageName $editions.insiders.chocoPackageName `
                                   -Label $editions.insiders.label `
                                   -LogMessages $LogMessages
        }
        "all" {
            # Check env var from orchestrator questionnaire first
            $hasEditionsEnv = -not [string]::IsNullOrWhiteSpace($env:VSCODE_EDITIONS)

            if ($hasEditionsEnv) {
                $editionsEnv = $env:VSCODE_EDITIONS
                Write-Log "Using VS Code editions from questionnaire: $editionsEnv" -Level "info"

                $isStable   = $editionsEnv -match "stable"
                $isInsiders = $editionsEnv -match "insiders"

                if ($isStable) {
                    Install-VsCodeEdition -ChocoPackageName $editions.stable.chocoPackageName `
                                           -Label $editions.stable.label `
                                           -LogMessages $LogMessages
                }
                if ($isInsiders) {
                    Install-VsCodeEdition -ChocoPackageName $editions.insiders.chocoPackageName `
                                           -Label $editions.insiders.label `
                                           -LogMessages $LogMessages
                }
            }
            elseif ($shouldPrompt) {
                Write-Host ""
                Write-Host $LogMessages.messages.editionPrompt -ForegroundColor Cyan
                Write-Host $LogMessages.messages.editionOptionStable
                Write-Host $LogMessages.messages.editionOptionInsiders
                Write-Host $LogMessages.messages.editionOptionBoth
                Write-Host ""
                $choice = Read-Host $LogMessages.messages.editionPromptInput

                $isDefaultOrStable = [string]::IsNullOrWhiteSpace($choice) -or $choice -eq "1"
                $isInsiders = $choice -eq "2"
                $isBoth = $choice -eq "3"

                if ($isDefaultOrStable) {
                    Install-VsCodeEdition -ChocoPackageName $editions.stable.chocoPackageName `
                                           -Label $editions.stable.label `
                                           -LogMessages $LogMessages
                }
                elseif ($isInsiders) {
                    Install-VsCodeEdition -ChocoPackageName $editions.insiders.chocoPackageName `
                                           -Label $editions.insiders.label `
                                           -LogMessages $LogMessages
                }
                elseif ($isBoth) {
                    Install-VsCodeEdition -ChocoPackageName $editions.stable.chocoPackageName `
                                           -Label $editions.stable.label `
                                           -LogMessages $LogMessages
                    Install-VsCodeEdition -ChocoPackageName $editions.insiders.chocoPackageName `
                                           -Label $editions.insiders.label `
                                           -LogMessages $LogMessages
                }
                else {
                    Install-VsCodeEdition -ChocoPackageName $editions.stable.chocoPackageName `
                                           -Label $editions.stable.label `
                                           -LogMessages $LogMessages
                }
            }
            else {
                # No prompt: install what's enabled in config
                if ($editions.stable.enabled) {
                    Install-VsCodeEdition -ChocoPackageName $editions.stable.chocoPackageName `
                                           -Label $editions.stable.label `
                                           -LogMessages $LogMessages
                }
                if ($editions.insiders.enabled) {
                    Install-VsCodeEdition -ChocoPackageName $editions.insiders.chocoPackageName `
                                           -Label $editions.insiders.label `
                                           -LogMessages $LogMessages
                }
            }
        }
    }
}
