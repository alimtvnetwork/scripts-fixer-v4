# Spec: Script 08 -- Install pnpm

## Purpose

Install pnpm globally via npm and configure the content-addressable store
inside the shared dev directory. Does **not** require admin privileges.

## Subcommands

| Command | Description |
|---------|-------------|
| `all` | Install pnpm + configure store (default) |
| `install` | Install/upgrade pnpm only |
| `configure` | Configure store path and PATH only |
| `-Help` | Show usage information |

## config.json

| Key | Type | Purpose |
|-----|------|---------|
| `enabled` | bool | Master toggle |
| `installMethod` | string | How to install (`npm`) |
| `devDirSubfolder` | string | Subfolder under dev dir |
| `store.setStorePath` | bool | Whether to set store-dir |
| `store.storePath` | string | Fallback store path |
| `path.updateUserPath` | bool | Add pnpm bin to PATH |

## Flow

1. Verify npm is available (requires Node.js from script 06)
2. Install pnpm via `npm install -g pnpm`
3. Configure `pnpm config set store-dir` to dev dir
4. Set `PNPM_HOME` and add to User PATH
5. Save resolved state

## Dependencies

- Shared: `logging.ps1`, `resolved.ps1`, `git-pull.ps1`, `help.ps1`, `path-utils.ps1`
- Requires: Node.js/npm (script 06), no admin needed
