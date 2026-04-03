# Spec: Shared Helpers

## Overview

Shared PowerShell modules that live in `scripts/shared/` and are dot-sourced
by individual scripts. This avoids duplicating common logic across scripts.

---

## File Structure

```
scripts/
└── shared/
    └── git-pull.ps1    # Provides Invoke-GitPull function
```

## git-pull.ps1

### Purpose

Provides `Invoke-GitPull` -- a function that runs `git pull` from the repo root.

### Skip Mechanism

| Scenario | Behavior |
|----------|----------|
| Script run directly (`.\scripts\01-...\run.ps1`) | `$env:SCRIPTS_ROOT_RUN` is not set -> git pull runs |
| Script run via root dispatcher (`.\run.ps1 -I 1`) | Root sets `$env:SCRIPTS_ROOT_RUN = "1"` before delegating -> git pull is skipped |

### Function Signature

```powershell
Invoke-GitPull -RepoRoot <string>
```

### How Child Scripts Use It

```powershell
# At the top of Main, before Initialize-Logging:
$sharedGitPull = Join-Path $ScriptDir "..\shared\git-pull.ps1"
if (Test-Path $sharedGitPull) {
    . $sharedGitPull
    $repoRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)
    Invoke-GitPull -RepoRoot $repoRoot
}
```

## Naming Conventions

| Rule | Example |
|------|---------|
| All file names use **lowercase-hyphenated** (kebab-case) | `git-pull.ps1` |
| Folder names also use lowercase-hyphenated | `shared` |
| PowerShell functions use Verb-Noun PascalCase per PS convention | `Invoke-GitPull` |

## Design Decisions

| Decision | Rationale |
|----------|-----------|
| Environment variable flag | Simple, no file I/O, works across process boundaries |
| Dot-sourcing (not module) | No module manifest overhead, just a simple function import |
| Graceful fallback | If shared helper is missing, scripts warn and continue |
| Root cleans flag after run | Prevents stale flag from affecting future standalone runs |
