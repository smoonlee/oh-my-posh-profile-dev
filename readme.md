# Oh My Posh Profile

A one-shot developer workstation bootstrap script for Windows. Run once as Administrator to install a full cloud/DevOps tool stack, configure PowerShell with Oh My Posh, and apply a custom Windows Terminal profile — all from a single command.

## Features

- Installs PowerShell 7, Azure CLI, kubectl, Helm, Git, Terraform, VS Code, Oh My Posh and more via WinGet
- Installs PowerShell modules (Az, Microsoft.Graph, PSReadLine, Terminal-Icons, Posh-Git, PSRule, Pester, etc.)
- Downloads and installs Nerd Fonts with registry-based version tracking
- Patches the VS Code PowerShell extension's bundled PSReadLine to prevent assembly conflicts
- Applies a pre-built Oh My Posh PowerShell profile and matching Windows Terminal settings
- Symlinks PS5, PS7 and VS Code profiles so all shells share a single profile and module set
- Supports clean teardown via reset switches for reprovisioning

## Prerequisites

- Windows 10/11
- Administrator privileges
- WinGet (App Installer) installed

## Usage

```powershell
# Basic install (no Nerd Font)
.\Install-PwshProfile.ps1

# Install with a specific Nerd Font
.\Install-PwshProfile.ps1 -nerdFontName "CascadiaCode"
```

### Parameters

| Parameter       | Type     | Default  | Description                                                                                                                           |
| --------------- | -------- | -------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| `-nerdFontName` | `string` | `''`     | Nerd Font to download and install (e.g. `CascadiaCode`)                                                                               |
| `-resetProfile` | `switch` | `$false` | Remove profile symlinks (backs up real files)                                                                                         |
| `-resetModules` | `switch` | `$false` | Unload and delete user PowerShell module folders                                                                                      |
| `-factoryReset` | `switch` | `$false` | Full teardown — implies `-resetProfile` and `-resetModules`, plus uninstalls WinGet apps, Nerd Fonts and VS Code PowerShell extension |

### Reset Examples

```powershell
# Remove profile symlinks only
.\Install-PwshProfile.ps1 -resetProfile

# Remove modules only
.\Install-PwshProfile.ps1 -resetModules

# Full factory reset
.\Install-PwshProfile.ps1 -factoryReset
```

> **Note:** Reset switches short-circuit the script — no installation steps run after a reset.

## What Gets Installed

### WinGet Apps

| Package                    | Scope   |
| -------------------------- | ------- |
| Microsoft.PowerShell       | Machine |
| Microsoft.AzureCLI         | Machine |
| Microsoft.Azure.Kubelogin  | Machine |
| Kubernetes.kubectl         | Machine |
| Helm.Helm                  | Machine |
| Git.Git                    | Machine |
| GitHub.cli                 | Machine |
| Amazon.AWSCLI              | Machine |
| Hashicorp.Terraform        | Machine |
| Microsoft.Bicep            | Machine |
| Microsoft.VisualStudioCode | Machine |
| FireDaemon.OpenSSL         | Machine |
| Ookla.Speedtest.CLI        | Machine |
| JanDeDobbeleer.OhMyPosh    | User    |

### PowerShell Modules

`PackageManagement`, `PowerShellGet`, `PSReadLine`, `Pester`, `Terminal-Icons`, `Posh-Git`, `PSRule`, `PSRule.Rules.Azure`, `Microsoft.Graph`, `Az`

## How It Works

1. **System Check** — Validates OS, detects PS5/PS7 paths, patches PS5 core modules for PS7 compatibility, checks WinGet sources
2. **Nerd Font Install** — Downloads the latest release from [ryanoasis/nerd-fonts](https://github.com/ryanoasis/nerd-fonts) and installs to the user fonts folder
3. **WinGet Apps** — Installs or upgrades the tool stack listed above
4. **PowerShell Modules** — Installs modules from PSGallery; symlinks the PS5 modules folder to the PS7 modules folder for shared access
5. **VS Code Extension** — Installs the PowerShell extension and replaces its bundled PSReadLine with the latest stable version
6. **Profile Setup** — Downloads the PowerShell profile and Windows Terminal settings, auto-detects the installed Nerd Font and patches the terminal config
7. **Cross-Platform Support** — Creates symlinks so PS5, PS7 and VS Code all share a single profile file
8. **Activate** — Dot-sources the profile into the current session

## Repository Contents

| File                             | Description                        |
| -------------------------------- | ---------------------------------- |
| `Install-PwshProfile.ps1`        | Main bootstrap script              |
| `windows-terminal-settings.json` | Windows Terminal settings template |
| `readme.md`                      | This file                          |
