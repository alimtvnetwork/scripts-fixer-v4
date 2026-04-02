# Spec: VS Code Context Menu Fix

## Overview

A PowerShell utility that restores the **"Open with Code"** entry to the Windows
Explorer right-click context menu for files, folders, and folder backgrounds.

---

## Problem

After certain Windows updates or VS Code installations/reinstallations, the
context-menu entries for VS Code disappear. Users lose the ability to:

1. Right-click a **file** → "Open with Code"
2. Right-click a **folder** → "Open with Code"
3. Right-click the **background** of a folder (empty space) → "Open with Code"

## Solution

A structured PowerShell script that:

- Reads configuration (paths, labels) from an external **`config.json`**
- Reads all log/display messages from a separate **`log-messages.json`**
- Creates the required Windows Registry entries under `HKEY_CLASSES_ROOT`
- Provides colorful, structured terminal output with status badges

---

## File Structure

```
scripts/
└── vscode-context-menu-fix/
    ├── config.json                  # Paths & settings (user-editable)
    ├── log-messages.json            # All display strings & banners
    └── Fix-VSCodeContextMenu.ps1   # Main script

spec/
└── vscode-context-menu-fix/
    └── README.md                   # This specification
```

## config.json Schema

| Key                  | Type   | Description                                        |
|----------------------|--------|----------------------------------------------------|
| `vscodePath.user`    | string | Path for per-user VS Code install (with env vars)  |
| `vscodePath.system`  | string | Path for system-wide VS Code install               |
| `registryPaths.file` | string | Registry key for file context menu                 |
| `registryPaths.directory` | string | Registry key for folder context menu          |
| `registryPaths.background` | string | Registry key for folder background menu     |
| `contextMenuLabel`   | string | Label shown in the context menu                    |
| `installationType`   | string | `"user"` or `"system"` — which path to try first   |

## log-messages.json Schema

| Key       | Type     | Description                              |
|-----------|----------|------------------------------------------|
| `banner`  | string[] | ASCII art banner lines                   |
| `steps.*` | string   | Message for each step of the process     |
| `status.*`| string   | Badge labels: `[  OK  ]`, `[ FAIL ]` etc |
| `errors.*`| string   | Error message templates                  |
| `footer`  | string[] | Closing banner lines                     |

## Execution Flow

1. Load `log-messages.json` → display banner
2. Verify Administrator privileges
3. Load `config.json` → resolve VS Code exe path
4. Validate that the exe exists (with auto-fallback to the other install type)
5. Map `HKCR:` PSDrive if not already mapped
6. Create three registry entries (file, directory, background)
7. Verify each entry exists
8. Display summary footer

## Prerequisites

- **Windows 10/11**
- **PowerShell 5.1+**
- **Administrator privileges**
- **VS Code installed** (user or system)

## How to Run

```powershell
# Open PowerShell as Administrator, then:
cd scripts\vscode-context-menu-fix
.\Fix-VSCodeContextMenu.ps1
```

## Design Decisions

| Decision | Rationale |
|----------|-----------|
| External JSON configs | Easy to edit without touching script logic |
| Env-var expansion at runtime | Supports both user & system installs portably |
| Auto-fallback path detection | Reduces user friction if wrong type is selected |
| Colored status badges | Clear visual feedback in the terminal |
| Verification step | Confirms entries were actually written |
