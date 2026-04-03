---
name: File naming conventions
description: All script/config file and folder names must be lowercase-hyphenated (kebab-case), never PascalCase
type: preference
---
1. All file names use lowercase-hyphenated (kebab-case): `run.ps1`, `log-messages.json`, `config.json`
2. Never use PascalCase or camelCase for file names (e.g. ~~Fix-VSCodeContextMenu.ps1~~)
3. Folder names also use lowercase-hyphenated: `01-vscode-context-menu-fix`
4. PowerShell functions *inside* scripts may still use Verb-Noun PascalCase per PS convention
