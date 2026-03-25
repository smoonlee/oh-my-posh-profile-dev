
#Requires -RunAsAdministrator

param (
    [string] $nerdFontName = '',
    [switch] $resetProfile,
    [switch] $resetModules,
    [switch] $factoryReset
)

function Invoke-SystemCheck {
    # Initialise System Checks for OS, PowerShell Configuration and Prerequisites
    Write-Host "`n[Pwsh Profile]: Checking System Configuration..."

    # Confirm Administrator privileges (enforced by #Requires -RunAsAdministrator)
    Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
    Write-Host -ForegroundColor 'Green' "Running as Administrator"

    Write-Host "[Pwsh Profile]: Checking OS Version..."
    $os = Get-CimInstance Win32_OperatingSystem
    $displayVersion = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').DisplayVersion
    Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
    Write-Host -ForegroundColor 'Cyan' "$($os.Caption) - $displayVersion - Build $($os.BuildNumber)"

    Write-Host "`n[Pwsh Profile]: Checking PowerShell Versions..."

    # Check for Windows PowerShell 5.x
    $pwsh5Path = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
    if (Test-Path $pwsh5Path) {
        $pwsh5Version = (& $pwsh5Path -NoProfile -Command '$PSVersionTable.PSVersion.ToString()') 2>$null
        Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
        Write-Host -ForegroundColor 'Green' "Windows PowerShell $pwsh5Version - $pwsh5Path"
    } else {
        Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
        Write-Host -ForegroundColor 'Red' "Windows PowerShell 5.x - Not Installed"
    }

    # Check for PowerShell 7.x
    $pwsh7Cmd = Get-Command pwsh -ErrorAction SilentlyContinue
    $pwsh7Path = if ($pwsh7Cmd) { $pwsh7Cmd.Source } else { $null }
    if ($pwsh7Path) {
        $pwsh7Version = (& $pwsh7Path -NoProfile -Command '$PSVersionTable.PSVersion.ToString()') 2>$null
        Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
        Write-Host -ForegroundColor 'Green' "PowerShell $pwsh7Version - $pwsh7Path"
    } else {
        Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
        Write-Host -ForegroundColor 'Red' "PowerShell 7.x - Not Installed"
    }

    # Patch PS5 core modules for backwards compatibility when PS7 is the primary session
    if ($pwsh7Path -and (Test-Path $pwsh5Path)) {
        Write-Host "`n[Pwsh Profile]: Patching PowerShell 5 core modules for backwards compatibility..."

        $ps5CoreModules = @(
            'PackageManagement',
            'PowerShellGet',
            'PSReadLine',
            'Pester'
        )

        foreach ($moduleName in $ps5CoreModules) {
            $patchScript = @"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
`$installed = Get-Module -Name '$moduleName' -ListAvailable -ErrorAction SilentlyContinue |
    Sort-Object Version -Descending | Select-Object -First 1
`$latest = Find-Module -Name '$moduleName' -Repository PSGallery -ErrorAction SilentlyContinue
if (`$latest -and `$installed -and ([Version]`$latest.Version -gt [Version]`$installed.Version)) {
    Install-Module -Name '$moduleName' -Scope CurrentUser -Force -AllowClobber -SkipPublisherCheck -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
    Write-Output "UPDATED|`$(`$installed.Version)|`$(`$latest.Version)"
} elseif (`$installed) {
    Write-Output "LATEST|`$(`$installed.Version)"
} else {
    Install-Module -Name '$moduleName' -Scope CurrentUser -Force -AllowClobber -SkipPublisherCheck -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
    Write-Output "INSTALLED"
}
"@
            $result = (& $pwsh5Path -NoProfile -Command $patchScript 2>$null 3>$null) | Select-Object -Last 1
            Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
            if ($result -like 'UPDATED|*') {
                $parts = $result -split '\|'
                Write-Host -ForegroundColor 'Green' "PS5 Patched: $moduleName ($($parts[1]) -> $($parts[2]))"
            } elseif ($result -like 'LATEST|*') {
                $parts = $result -split '\|'
                Write-Host -ForegroundColor 'Green' "PS5 Latest: $moduleName $($parts[1])"
            } elseif ($result -eq 'INSTALLED') {
                Write-Host -ForegroundColor 'Green' "PS5 Installed: $moduleName"
            } else {
                Write-Host -ForegroundColor 'Red' "PS5 Failed: $moduleName"
            }
        }
    }

    # Patch PackageManagement and NuGet providers if running under PowerShell 5
    if ($PSVersionTable.PSVersion.Major -le 5) {
        Write-Host "`n[Pwsh Profile]: Patching PowerShell 5 Package Providers..."

        # Force TLS 1.2 for package downloads
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        # Check NuGet provider
        $nuget = Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue
        if (-not $nuget -or $nuget.Version -lt [Version]'2.8.5.201') {
            Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
            Write-Host -ForegroundColor 'Yellow' "Installing NuGet provider..."
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser | Out-Null
            $nuget = Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue
            Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
            Write-Host -ForegroundColor 'Green' "NuGet provider $($nuget.Version) - Installed"
        } else {
            Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
            Write-Host -ForegroundColor 'Green' "NuGet provider $($nuget.Version) - OK"
        }

        # Update PackageManagement module
        $pkgMgmt = Get-Module -Name PackageManagement -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
        if ($pkgMgmt.Version -lt [Version]'1.4.7') {
            Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
            Write-Host -ForegroundColor 'Yellow' "Updating PackageManagement module..."
            Install-Module -Name PackageManagement -MinimumVersion 1.4.7 -Force | Out-Null
            Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
            Write-Host -ForegroundColor 'Green' "PackageManagement updated"
        } else {
            Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
            Write-Host -ForegroundColor 'Green' "PackageManagement $($pkgMgmt.Version) - OK"
        }
    }

    # Check for WinGet
    Write-Host "`n[Pwsh Profile]: Checking WinGet..."
    $wingetCmd = Get-Command winget -ErrorAction SilentlyContinue
    if ($wingetCmd) {
        $wingetVer = (winget --version) 2>$null
        Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
        Write-Host -ForegroundColor 'Green' "WinGet $wingetVer - Installed"
        Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
        Write-Host -ForegroundColor 'Yellow' "Updating WinGet sources..."
        winget source update --disable-interactivity 2>$null | Out-Null
        Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
        Write-Host -ForegroundColor 'Green' "WinGet sources updated"
    } else {
        Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
        Write-Host -ForegroundColor 'Red' "WinGet - Not Installed"
    }
}

function Invoke-Reset {
    param (
        [switch] $ResetProfile,
        [switch] $ResetModules,
        [switch] $FactoryReset
    )

    # FactoryReset implies both ResetProfile and ResetModules
    if ($FactoryReset) {
        $ResetProfile = $true
        $ResetModules = $true
    }

    Write-Host "`n[Pwsh Profile]: Reset Operations Starting..."

    # --- Profile Reset ---
    if ($ResetProfile) {
        Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
        Write-Host -ForegroundColor 'Yellow' "Resetting profile symlinks..."

        $ps7ProfileDir = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell'
        $ps5ProfileDir = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'WindowsPowerShell'
        $profileName = 'Microsoft.PowerShell_profile.ps1'
        $vscodeProfileName = 'Microsoft.VSCode_profile.ps1'

        foreach ($dir in @($ps7ProfileDir, $ps5ProfileDir)) {
            foreach ($name in @($profileName, $vscodeProfileName)) {
                $path = Join-Path $dir $name
                if (Test-Path $path) {
                    $item = Get-Item $path -ErrorAction SilentlyContinue
                    if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
                        Remove-Item -Path $path -Force
                        Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
                        Write-Host -ForegroundColor 'Green' "Removed symlink: $path"
                    } else {
                        $bakPath = "$path.bak"
                        Copy-Item -Path $path -Destination $bakPath -Force
                        Remove-Item -Path $path -Force
                        Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
                        Write-Host -ForegroundColor 'Green' "Backed up and removed: $path -> $bakPath"
                    }
                }
            }
        }

        Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
        Write-Host -ForegroundColor 'Green' "Profile reset complete - symlinks will be recreated"
    }

    # --- Module Reset ---
    if ($ResetModules) {
        Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
        Write-Host -ForegroundColor 'Yellow' "Resetting PowerShell modules..."

        $ps7ModulesPath = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell\Modules'
        $ps5ModulesPath = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'WindowsPowerShell\Modules'

        # Unload any modules loaded from user module paths (best effort - .NET assemblies remain locked)
        Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
        Write-Host -ForegroundColor 'Yellow' "Unloading user modules..."
        foreach ($modPath in @($ps7ModulesPath, $ps5ModulesPath)) {
            if (Test-Path $modPath) {
                $loadedModules = Get-Module | Where-Object { $_.ModuleBase -like "$modPath*" }
                foreach ($mod in $loadedModules) {
                    try {
                        Remove-Module -Name $mod.Name -Force -ErrorAction Stop
                    } catch {
                        # Ignore - format file errors from other modules, DLL locks, etc.
                    }
                    Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
                    Write-Host -ForegroundColor 'Cyan' "Unloaded: $($mod.Name)"
                }
            }
        }

        # Track folders that need background cleanup (locked DLLs prevent in-process deletion)
        $pendingCleanup = @()

        foreach ($modPath in @($ps7ModulesPath, $ps5ModulesPath)) {
            if (Test-Path $modPath) {
                $item = Get-Item $modPath -ErrorAction SilentlyContinue
                if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
                    Remove-Item -Path $modPath -Force
                    Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
                    Write-Host -ForegroundColor 'Green' "Removed symlink: $modPath"
                } else {
                    # Try direct deletion first
                    Remove-Item -Path $modPath -Recurse -Force -ErrorAction SilentlyContinue 2>$null
                    if (Test-Path $modPath) {
                        # DLLs still locked by the CLR - rename folder and schedule background cleanup
                        $removingPath = "$modPath.removing"
                        if (Test-Path $removingPath) { Remove-Item -Path $removingPath -Recurse -Force -ErrorAction SilentlyContinue 2>$null }
                        Rename-Item -Path $modPath -NewName (Split-Path $removingPath -Leaf) -Force
                        $pendingCleanup += $removingPath
                        Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
                        Write-Host -ForegroundColor 'Yellow' "Renamed locked folder: $modPath -> $(Split-Path $removingPath -Leaf)"
                    } else {
                        Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
                        Write-Host -ForegroundColor 'Green' "Removed modules folder: $modPath"
                    }
                }
            }
        }

        # Spawn a background process to clean up locked folders after this session exits
        if ($pendingCleanup.Count -gt 0) {
            $cleanupCommands = ($pendingCleanup | ForEach-Object { "rd /s /q `"$_`"" }) -join ' & '
            Start-Process -FilePath 'cmd.exe' -ArgumentList "/c timeout /t 5 /nobreak >nul & $cleanupCommands" -WindowStyle Hidden
            Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
            Write-Host -ForegroundColor 'Cyan' "Background cleanup scheduled for locked module folders (5 second delay)"
        }

        # Remove any .bak modules folder from previous symlink operations
        $bakModPath = "$ps5ModulesPath.bak"
        if (Test-Path $bakModPath) {
            Remove-Item -Path $bakModPath -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
            Write-Host -ForegroundColor 'Green' "Removed backup: $bakModPath"
        }

        # Also clean up any stale .removing folders from previous runs
        foreach ($modPath in @($ps7ModulesPath, $ps5ModulesPath)) {
            $staleRemoving = "$modPath.removing"
            if (Test-Path $staleRemoving) {
                Remove-Item -Path $staleRemoving -Recurse -Force -ErrorAction SilentlyContinue
                if (-not (Test-Path $staleRemoving)) {
                    Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
                    Write-Host -ForegroundColor 'Green' "Cleaned up stale folder: $staleRemoving"
                }
            }
        }

        Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
        Write-Host -ForegroundColor 'Green' "Module reset complete - modules will be reinstalled"
    }

    # --- Factory Reset (additional cleanup beyond profile + modules) ---
    if ($FactoryReset) {
        # Uninstall all WinGet apps (mirrors lists from Install-WinGetApps)
        Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
        Write-Host -ForegroundColor 'Yellow' "Factory reset - uninstalling WinGet apps..."

        $allAppIds = @(
            'Microsoft.PowerShell',
            'Microsoft.AzureCLI',
            'Microsoft.Azure.Kubelogin',
            'Kubernetes.kubectl',
            'Helm.Helm',
            'Git.Git',
            'GitHub.cli',
            'Amazon.AWSCLI',
            'Hashicorp.Terraform',
            'Microsoft.Bicep',
            'Microsoft.VisualStudioCode',
            'FireDaemon.OpenSSL',
            'Ookla.Speedtest.CLI',
            'JanDeDobbeleer.OhMyPosh'
        )

        $wingetCmd = Get-Command winget -ErrorAction SilentlyContinue
        if ($wingetCmd) {
            foreach ($app in $allAppIds) {
                Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
                Write-Host -ForegroundColor 'Yellow' "Uninstalling: $app"
                winget uninstall --id $app --exact --silent --accept-source-agreements --disable-interactivity 2>$null | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
                    Write-Host -ForegroundColor 'Green' "Uninstalled: $app"
                } else {
                    Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
                    Write-Host -ForegroundColor 'Cyan' "Skipped (not installed or already removed): $app"
                }
            }
        } else {
            Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
            Write-Host -ForegroundColor 'Red' "WinGet not available - cannot uninstall apps"
        }

        # Remove Nerd Font files and registry
        Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
        Write-Host -ForegroundColor 'Yellow' "Removing Nerd Font files..."

        $fontsFolder = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
        $nerdFonts = Get-ChildItem -Path $fontsFolder -Filter '*Nerd*' -ErrorAction SilentlyContinue
        foreach ($file in $nerdFonts) {
            $fontRegPath = "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
            $regEntries = Get-ItemProperty -Path $fontRegPath -ErrorAction SilentlyContinue
            if ($regEntries) {
                $regEntries.PSObject.Properties | Where-Object { $_.Value -eq $file.FullName } | ForEach-Object {
                    Remove-ItemProperty -Path $fontRegPath -Name $_.Name -ErrorAction SilentlyContinue
                }
            }
            Remove-Item -Path $file.FullName -Force -ErrorAction SilentlyContinue
        }

        $versionKey = "HKCU:\Software\NerdFonts"
        if (Test-Path $versionKey) {
            Remove-Item -Path $versionKey -Recurse -Force
        }

        if ($nerdFonts) {
            Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
            Write-Host -ForegroundColor 'Green' "Removed Nerd Font files and registry entries"
        } else {
            Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
            Write-Host -ForegroundColor 'Cyan' "No Nerd Font files found to remove"
        }

        # Remove VS Code PowerShell extension
        $vscodeExtDir = "$env:USERPROFILE\.vscode\extensions"
        $pwshExt = Get-ChildItem -Path $vscodeExtDir -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like 'ms-vscode.powershell*' }
        foreach ($ext in $pwshExt) {
            Remove-Item -Path $ext.FullName -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
            Write-Host -ForegroundColor 'Green' "Removed VS Code extension: $($ext.Name)"
        }

        Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
        Write-Host -ForegroundColor 'Green' "Factory reset complete - full reinstall will now run"
    }
}

function Invoke-NerdFontInstall {
    param (
        [string] $fontName
    )

    if (-not $fontName) {
        Write-Host -ForegroundColor 'White' -NoNewline "`n[Pwsh Profile]: "
        Write-Host -ForegroundColor 'Yellow' "No Nerd Font specified - skipping font install"
        return
    }

    Write-Host "`n[Pwsh Profile]: Nerd Font Installation - $fontName"

    # Warn if VS Code or Windows Terminal are running
    $vscodeProc = Get-Process -Name 'Code' -ErrorAction SilentlyContinue
    $wtProc = Get-Process -Name 'WindowsTerminal' -ErrorAction SilentlyContinue
    if ($vscodeProc) {
        Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
        Write-Host -ForegroundColor 'Yellow' "WARNING: VS Code is running - restart it after install to use the new font"
    }
    if ($wtProc) {
        Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
        Write-Host -ForegroundColor 'Yellow' "WARNING: Windows Terminal is running - restart it after install to use the new font"
    }

    # Force TLS 1.2 for GitHub API
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    # Get latest release version from GitHub
    Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
    Write-Host -ForegroundColor 'Cyan' "Checking latest Nerd Fonts release..."
    $releaseUrl = 'https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest'
    try {
        $release = Invoke-RestMethod -Uri $releaseUrl -Headers @{ 'User-Agent' = 'PowerShell' } -ErrorAction Stop
        $latestVersion = $release.tag_name
    } catch {
        Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
        Write-Host -ForegroundColor 'Red' "Failed to check GitHub releases (API rate limit or network error)"
        Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
        Write-Host -ForegroundColor 'Yellow' "Skipping Nerd Font install - try again later"
        return
    }

    Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
    Write-Host -ForegroundColor 'Cyan' "Latest version: $latestVersion"

    # Track installed version via registry marker
    $versionKey = "HKCU:\Software\NerdFonts"
    $installedVersion = $null
    if (Test-Path $versionKey) {
        $installedVersion = (Get-ItemProperty -Path $versionKey -Name $fontName -ErrorAction SilentlyContinue).$fontName
    }

    # Check if the font is already installed at the latest version
    $fontsFolder = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
    $fontInstalled = Get-ChildItem -Path $fontsFolder -Filter "*$fontName*Nerd*" -ErrorAction SilentlyContinue
    if (-not $fontInstalled) {
        # Also check system fonts folder
        $fontInstalled = Get-ChildItem -Path "$env:SystemRoot\Fonts" -Filter "*$fontName*Nerd*" -ErrorAction SilentlyContinue
    }

    if ($fontInstalled -and $installedVersion -eq $latestVersion) {
        Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
        Write-Host -ForegroundColor 'Green' "$fontName Nerd Font $latestVersion - Already installed"
        return
    }

    # Remove old font files if upgrading
    if ($fontInstalled -and $installedVersion -and $installedVersion -ne $latestVersion) {
        Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
        Write-Host -ForegroundColor 'Yellow' "Upgrading $fontName Nerd Font from $installedVersion to $latestVersion..."

        foreach ($file in $fontInstalled) {
            # Remove font registry entry
            $regPath = "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
            $regEntries = Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue
            if ($regEntries) {
                $regEntries.PSObject.Properties | Where-Object { $_.Value -eq $file.FullName } | ForEach-Object {
                    Remove-ItemProperty -Path $regPath -Name $_.Name -ErrorAction SilentlyContinue
                }
            }
            Remove-Item -Path $file.FullName -Force -ErrorAction SilentlyContinue
        }

        Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
        Write-Host -ForegroundColor 'Green' "Old font files removed"
    }

    # Download the font archive
    $downloadUrl = "https://github.com/ryanoasis/nerd-fonts/releases/download/$latestVersion/$fontName.zip"
    $tempDir = Join-Path $env:TEMP "NerdFont-$fontName"
    $zipPath = Join-Path $env:TEMP "$fontName.zip"

    if (Test-Path $tempDir) { Remove-Item -Path $tempDir -Recurse -Force }
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

    Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
    Write-Host -ForegroundColor 'Cyan' "Downloading $fontName.zip..."
    try {
        Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -UseBasicParsing -ErrorAction Stop
    } catch {
        Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
        Write-Host -ForegroundColor 'Red' "Failed to download font: $($_.Exception.Message)"
        return
    }

    # Extract
    Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
    Write-Host -ForegroundColor 'Cyan' "Extracting font files..."
    Expand-Archive -Path $zipPath -DestinationPath $tempDir -Force

    # Install only Regular variant .ttf files
    $fontFiles = Get-ChildItem -Path $tempDir -Filter '*Regular*.ttf' -Recurse
    if (-not $fontFiles) {
        # Fallback: try all .ttf files if no Regular variant found
        $fontFiles = Get-ChildItem -Path $tempDir -Filter '*.ttf' -Recurse
    }

    if (-not $fontFiles) {
        Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
        Write-Host -ForegroundColor 'Red' "No .ttf font files found in archive"
        return
    }

    # Install fonts to user fonts folder
    if (-not (Test-Path $fontsFolder)) {
        New-Item -ItemType Directory -Path $fontsFolder -Force | Out-Null
    }

    $regPath = "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
    $installFailed = $false
    foreach ($font in $fontFiles) {
        $destPath = Join-Path $fontsFolder $font.Name
        try {
            Copy-Item -Path $font.FullName -Destination $destPath -Force -ErrorAction Stop

            # Register font in user registry
            $fontRegName = "$([System.IO.Path]::GetFileNameWithoutExtension($font.Name)) (TrueType)"
            New-ItemProperty -Path $regPath -Name $fontRegName -Value $destPath -PropertyType String -Force | Out-Null

            Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
            Write-Host -ForegroundColor 'Green' "Installed: $($font.Name)"
        } catch {
            Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
            Write-Host -ForegroundColor 'Red' "Failed: $($font.Name) - file is locked (close apps using this font and re-run)"
            $installFailed = $true
        }
    }

    if ($installFailed) {
        Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
        Write-Host -ForegroundColor 'Yellow' "Some fonts could not be updated - close VS Code / Windows Terminal and re-run"
        # Don't update the version marker so next run will retry
    } else {
        # Record installed version only if all fonts succeeded
        if (-not (Test-Path $versionKey)) {
            New-Item -Path $versionKey -Force | Out-Null
        }
        New-ItemProperty -Path $versionKey -Name $fontName -Value $latestVersion -PropertyType String -Force | Out-Null
    }

    # Cleanup temp files
    Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue

    if (-not $installFailed) {
        Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
        Write-Host -ForegroundColor 'Green' "$fontName Nerd Font $latestVersion installed successfully"
    }

    # Remind about restarts
    if ($vscodeProc -or $wtProc) {
        Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
        Write-Host -ForegroundColor 'Yellow' "Remember to restart VS Code / Windows Terminal to use the new font"
    }
}

function Install-WinGetApps {
    # Machine-scope installs (system-wide)
    $machineApps = @(
        # PowerShell & Azure
        'Microsoft.PowerShell',
        'Microsoft.AzureCLI',
        'Microsoft.Azure.Kubelogin',

        # Containers & Orchestration
        'Kubernetes.kubectl',
        'Helm.Helm',

        # Source Control
        'Git.Git',
        'GitHub.cli',

        # Multi-Cloud & IaC
        'Amazon.AWSCLI',
        'Hashicorp.Terraform',
        'Microsoft.Bicep',

        # Dev Tools & Editors
        'Microsoft.VisualStudioCode',

        # Utilities
        'FireDaemon.OpenSSL',
        'Ookla.Speedtest.CLI'
    )

    # User-scope installs (packages that don't support machine-scope)
    $userApps = @(
        'JanDeDobbeleer.OhMyPosh'
    )

    Write-Host "`n[Pwsh Profile]: Checking WinGet Apps..."

    $wingetCmd = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $wingetCmd) {
        Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
        Write-Host -ForegroundColor 'Red' "WinGet not available - skipping app installs"
        return
    }

    # Build combined list with scope metadata
    $allApps = @()
    foreach ($app in $machineApps) { $allApps += @{ Id = $app; Scope = 'Machine' } }
    foreach ($app in $userApps) { $allApps += @{ Id = $app; Scope = 'User' } }

    foreach ($entry in $allApps) {
        $app = $entry.Id
        $scope = $entry.Scope

        # Check if already installed
        $installed = winget list --id $app --exact --accept-source-agreements 2>$null
        if ($LASTEXITCODE -eq 0 -and $installed -match $app) {
            # Try upgrade
            Write-Host " "
            Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
            Write-Host -ForegroundColor 'Cyan' "Checking for update: $app"
            winget upgrade --id $app --exact --silent --accept-package-agreements --accept-source-agreements --disable-interactivity 2>$null | Out-Null
            $upgradeExit = $LASTEXITCODE
            if ($upgradeExit -eq 0) {
                Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
                Write-Host -ForegroundColor 'Green' "Upgraded: $app"
            } elseif ($upgradeExit -eq -1978335189) {
                # APPINSTALLER_CLI_ERROR_UPDATE_NOT_APPLICABLE
                Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
                Write-Host -ForegroundColor 'Green' "Up to date: $app"
            } else {
                Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
                Write-Host -ForegroundColor 'Yellow' "Upgrade returned exit code $upgradeExit for: $app"
            }
        } else {
            # Fresh install with appropriate scope
            Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
            Write-Host -ForegroundColor 'Yellow' "Installing [$scope]: $app"
            winget install --scope $scope --id $app --exact --silent --accept-package-agreements --accept-source-agreements --disable-interactivity 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
                Write-Host -ForegroundColor 'Green' "Installed: $app"
            } else {
                Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
                Write-Host -ForegroundColor 'Red' "Failed to install: $app"
            }
        }
    }

    # Refresh PATH so newly installed tools are available in this session
    Write-Host "`n[Pwsh Profile]: Refreshing System Environment Variables..."
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = "$machinePath;$userPath"
    Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
    Write-Host -ForegroundColor 'Green' "System Environment Variables refreshed"
}

function Install-PwshModules {
    Write-Host "`n[Pwsh Profile]: Installing PowerShell Modules..."

    $moduleList = @(
        'PackageManagement',
        'PowerShellGet',
        'PSReadLine',
        'Pester',
        'Terminal-Icons',
        'Posh-Git',
        'PSRule',
        'PSRule.Rules.Azure',
        'Microsoft.Graph',
        'Az'
    )

    # Determine module paths
    $ps7ModulesPath = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell\Modules'
    $ps5ModulesPath = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'WindowsPowerShell\Modules'

    # Check if PowerShell 7 is available (should be after WinGet installs)
    $pwsh7Cmd = Get-Command pwsh -ErrorAction SilentlyContinue

    if ($pwsh7Cmd) {
        $targetModulesPath = $ps7ModulesPath
        Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
        Write-Host -ForegroundColor 'Green' "PowerShell 7 detected - modules will install to: $targetModulesPath"
    } else {
        $targetModulesPath = $ps5ModulesPath
        Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
        Write-Host -ForegroundColor 'Yellow' "PowerShell 7 not found - falling back to PS5 modules path: $targetModulesPath"
    }

    # Ensure target modules directory exists
    if (-not (Test-Path $targetModulesPath)) {
        New-Item -ItemType Directory -Path $targetModulesPath -Force | Out-Null
    }

    # Create symbolic link from PS5 modules folder to PS7 modules folder
    # This allows PS5 to access modules installed in the PS7 directory
    if ($pwsh7Cmd -and $targetModulesPath -eq $ps7ModulesPath) {
        if (Test-Path $ps5ModulesPath) {
            $item = Get-Item $ps5ModulesPath -ErrorAction SilentlyContinue
            if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
                Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
                Write-Host -ForegroundColor 'Green' "PS5 symlink already exists -> $($item.Target)"
            } else {
                # PS5 modules folder exists as a real directory - back it up and replace with symlink
                $backupPath = "$ps5ModulesPath.bak"
                Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
                Write-Host -ForegroundColor 'Yellow' "Backing up existing PS5 modules to: $backupPath"
                if (Test-Path $backupPath) { Remove-Item -Path $backupPath -Recurse -Force }
                Rename-Item -Path $ps5ModulesPath -NewName 'Modules.bak' -Force

                # Copy any existing PS5 modules into the PS7 folder before linking
                $existingModules = Get-ChildItem -Path $backupPath -Directory -ErrorAction SilentlyContinue
                foreach ($mod in $existingModules) {
                    $destMod = Join-Path $ps7ModulesPath $mod.Name
                    if (-not (Test-Path $destMod)) {
                        Copy-Item -Path $mod.FullName -Destination $destMod -Recurse -Force
                    }
                }

                New-Item -ItemType SymbolicLink -Path $ps5ModulesPath -Target $ps7ModulesPath -Force | Out-Null
                Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
                Write-Host -ForegroundColor 'Green' "Created symlink: $ps5ModulesPath -> $ps7ModulesPath"
            }
        } else {
            # PS5 modules folder doesn't exist at all - just create the symlink
            New-Item -ItemType SymbolicLink -Path $ps5ModulesPath -Target $ps7ModulesPath -Force | Out-Null
            Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
            Write-Host -ForegroundColor 'Green' "Created symlink: $ps5ModulesPath -> $ps7ModulesPath"
        }
    }

    # Force TLS 1.2 for PSGallery
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    # Ensure PSGallery is trusted
    $gallery = Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue
    if ($gallery -and $gallery.InstallationPolicy -ne 'Trusted') {
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
        Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
        Write-Host -ForegroundColor 'Green' "PSGallery set to Trusted"
    }

    # Install or update each module
    foreach ($moduleName in $moduleList) {
        $installed = Get-Module -Name $moduleName -ListAvailable -ErrorAction SilentlyContinue |
        Sort-Object Version -Descending | Select-Object -First 1

        if ($installed) {
            # Check for update using safe version comparison
            $latest = Find-Module -Name $moduleName -Repository PSGallery -ErrorAction SilentlyContinue
            if ($latest -and ([Version]$latest.Version -gt [Version]$installed.Version)) {
                Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
                Write-Host -ForegroundColor 'Yellow' "Updating: $moduleName ($($installed.Version) -> $($latest.Version))"
                Install-Module -Name $moduleName -Scope CurrentUser -Force -AllowClobber -ErrorAction SilentlyContinue
                $check = Get-Module -Name $moduleName -ListAvailable -ErrorAction SilentlyContinue |
                Sort-Object Version -Descending | Select-Object -First 1
                if ($check -and ([Version]$check.Version -ge [Version]$latest.Version)) {
                    Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
                    Write-Host -ForegroundColor 'Green' "Updated: $moduleName $($check.Version)"
                } else {
                    Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
                    Write-Host -ForegroundColor 'Red' "Failed to update: $moduleName"
                }
            } else {
                Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
                Write-Host -ForegroundColor 'Green' "Latest: $moduleName $($installed.Version)"
            }
        } else {
            Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
            Write-Host -ForegroundColor 'Yellow' "Installing: $moduleName"
            Install-Module -Name $moduleName -Scope CurrentUser -Force -AllowClobber -ErrorAction SilentlyContinue
            $check = Get-Module -Name $moduleName -ListAvailable -ErrorAction SilentlyContinue
            if ($check) {
                Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
                Write-Host -ForegroundColor 'Green' "Installed: $moduleName"
            } else {
                Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
                Write-Host -ForegroundColor 'Red' "Failed to install: $moduleName"
            }
        }
    }
}

function Update-VSCodePwshModule {
    Write-Host "`n[Pwsh Profile]: VS Code PowerShell Extension Setup..."

    # Check VS Code is installed (look for the main executable)
    $vscodePath = @(
        "$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe",
        "$env:ProgramFiles\Microsoft VS Code\Code.exe"
    )
    $vscodeInstalled = $vscodePath | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $vscodeInstalled) {
        Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
        Write-Host -ForegroundColor 'Yellow' "VS Code not installed - skipping extension setup"
        return
    }

    # Use the code CLI from the known VS Code installation path
    $codeCli = Join-Path (Split-Path $vscodeInstalled) 'bin\code.cmd'
    if (-not (Test-Path $codeCli)) {
        Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
        Write-Host -ForegroundColor 'Red' "VS Code CLI not found at $codeCli - skipping extension setup"
        return
    }

    # Install / update the PowerShell extension via CLI
    Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
    Write-Host -ForegroundColor 'Cyan' "Checking PowerShell extension via VS Code CLI..."

    & $codeCli --install-extension ms-vscode.powershell --force 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
        Write-Host -ForegroundColor 'Green' "PowerShell extension installed / up to date"
    } else {
        Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
        Write-Host -ForegroundColor 'Red' "Failed to install PowerShell extension"
        return
    }

    # Locate the installed extension folder
    $folderName = Get-ChildItem -Path "$env:USERPROFILE\.vscode\extensions" -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like 'ms-vscode.powershell*' } |
    Sort-Object Name | Select-Object -Last 1
    if (-not $folderName) {
        Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
        Write-Host -ForegroundColor 'Yellow' "PowerShell extension folder not found - skipping PSReadLine patch"
        return
    }
    $vsCodeModulePath = Join-Path "$env:USERPROFILE\.vscode\extensions" $folderName.Name
    $psReadLinePath = Join-Path $vsCodeModulePath 'modules\PSReadLine'

    Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
    Write-Host -ForegroundColor 'Cyan' "Extension: $($folderName.Name)"

    # Check if VS Code is running - font files / modules will be locked
    $vscodeProc = Get-Process -Name 'Code' -ErrorAction SilentlyContinue
    if ($vscodeProc) {
        Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
        Write-Host -ForegroundColor 'Yellow' "VS Code is running - cannot patch PSReadLine (close VS Code and re-run)"
        return
    }

    # Find the latest stable PSReadLine version from PSGallery
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $latestPSRL = Find-Module -Name 'PSReadLine' -Repository PSGallery -ErrorAction SilentlyContinue
    if (-not $latestPSRL) {
        Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
        Write-Host -ForegroundColor 'Red' "Could not query PSGallery for PSReadLine"
        return
    }
    $latestVersion = $latestPSRL.Version.ToString()

    # Check if latest stable is already present
    $installedVersions = Get-ChildItem -Path $psReadLinePath -Directory -ErrorAction SilentlyContinue
    $alreadyPatched = $installedVersions | Where-Object { $_.Name -eq $latestVersion }
    if ($alreadyPatched) {
        Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
        Write-Host -ForegroundColor 'Green' "PSReadLine $latestVersion already present in extension"
        return
    }

    # Remove any pre-release / beta versions that cause 'Assembly with same name is already loaded'
    foreach ($ver in $installedVersions) {
        Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
        Write-Host -ForegroundColor 'Yellow' "Removing bundled PSReadLine $($ver.Name)..."
        Remove-Item -Path $ver.FullName -Recurse -Force -ErrorAction SilentlyContinue
    }

    # Save the latest stable PSReadLine into the extension modules folder
    Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
    Write-Host -ForegroundColor 'Cyan' "Installing PSReadLine $latestVersion into extension..."
    Save-Module -Name 'PSReadLine' -Path (Join-Path $vsCodeModulePath 'modules') -Force -ErrorAction SilentlyContinue

    # Verify
    $check = Get-ChildItem -Path $psReadLinePath -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq $latestVersion }
    if ($check) {
        Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
        Write-Host -ForegroundColor 'Green' "PSReadLine $latestVersion patched into VS Code extension"
    } else {
        Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
        Write-Host -ForegroundColor 'Red' "Failed to save PSReadLine into extension"
    }
}

function Invoke-ProfileSetup {
    Write-Host "`n[Pwsh Profile]: Profile Setup..."

    $profileUrl = 'https://raw.githubusercontent.com/smoonlee/oh-my-posh-profile/refs/heads/v3.2.0-dev/Microsoft.PowerShell_profile.ps1'
    $profileName = 'Microsoft.PowerShell_profile.ps1'

    # Force TLS 1.2 for GitHub downloads
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    # Determine primary profile directory (PS7 preferred, PS5 fallback)
    $pwsh7Cmd = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($pwsh7Cmd) {
        $primaryDir = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell'
        $primaryLabel = 'PowerShell 7'
    } else {
        $primaryDir = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'WindowsPowerShell'
        $primaryLabel = 'PowerShell 5'
    }

    # Ensure profile directory exists
    if (-not (Test-Path $primaryDir)) {
        New-Item -ItemType Directory -Path $primaryDir -Force | Out-Null
    }

    $profilePath = Join-Path $primaryDir $profileName

    # --- Download PowerShell Profile ---
    Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
    Write-Host -ForegroundColor 'Cyan' "Downloading profile from GitHub..."

    try {
        $profileContent = (Invoke-WebRequest -Uri $profileUrl -UseBasicParsing -ErrorAction Stop).Content
    } catch {
        Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
        Write-Host -ForegroundColor 'Red' "Failed to download profile: $($_.Exception.Message)"
        $profileContent = $null
    }

    if ($profileContent) {
        # Compare with existing profile - skip if unchanged
        $profileUpdated = $false
        if (Test-Path $profilePath) {
            $existingContent = Get-Content -Path $profilePath -Raw -ErrorAction SilentlyContinue
            if ($existingContent -eq $profileContent) {
                Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
                Write-Host -ForegroundColor 'Green' "$primaryLabel profile already up to date"
            } else {
                # Back up existing profile before overwriting
                $backupPath = "$profilePath.bak"
                Copy-Item -Path $profilePath -Destination $backupPath -Force
                Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
                Write-Host -ForegroundColor 'Yellow' "Existing profile backed up to: $backupPath"
                $profileUpdated = $true
            }
        } else {
            $profileUpdated = $true
        }

        if ($profileUpdated) {
            [System.IO.File]::WriteAllText($profilePath, $profileContent)
            Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
            Write-Host -ForegroundColor 'Green' "$primaryLabel profile saved to: $profilePath"
        }
    }

    # Reminder: GitHub Copilot requires Oh My Posh authentication
    Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
    Write-Host -ForegroundColor 'Yellow' "If using 'GitHub Copilot' suggestions in Oh My Posh, run: oh-my-posh auth copilot"
    Write-Host " "

    # --- Ensure C:\Code directory exists ---
    $codeDir = 'c:\code'
    if (-not (Test-Path $codeDir)) {
        New-Item -ItemType Directory -Path $codeDir -Force | Out-Null

        Write-Host " "
        Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
        Write-Host -ForegroundColor 'Green' "Created directory: $codeDir"
    } else {
        Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
        Write-Host -ForegroundColor 'Green' "Directory exists: $codeDir"
    }

    # --- Update Windows Terminal Settings ---
    $wtSettingsUrl = 'https://raw.githubusercontent.com/smoonlee/oh-my-posh-profile/refs/heads/v3.2.0-dev/windows-terminal-settings.json'
    $wtSettingsPath = Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'

    if (-not (Test-Path (Split-Path $wtSettingsPath))) {
        Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
        Write-Host -ForegroundColor 'Yellow' "Windows Terminal not installed - skipping settings update"
    } else {
        # Detect installed Nerd Font from user fonts folder
        $fontsFolder = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
        $nerdFontFile = Get-ChildItem -Path $fontsFolder -Filter '*NerdFont-Regular*.ttf' -ErrorAction SilentlyContinue |
        Select-Object -First 1

        if (-not $nerdFontFile) {
            # Also check system fonts
            $nerdFontFile = Get-ChildItem -Path "$env:SystemRoot\Fonts" -Filter '*NerdFont-Regular*.ttf' -ErrorAction SilentlyContinue |
            Select-Object -First 1
        }

        if (-not $nerdFontFile) {
            Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
            Write-Host -ForegroundColor 'Yellow' "No Nerd Font detected - skipping Windows Terminal settings update"
        } else {
            # Extract font family name from filename
            # e.g. CaskaydiaCoveNerdFont-Regular.ttf -> CaskaydiaCove Nerd Font
            $fontBaseName = $nerdFontFile.BaseName
            if ($fontBaseName -match '^(.+?)NerdFont') {
                $fontFamily = "$($Matches[1]) Nerd Font"
            } else {
                $fontFamily = $fontBaseName -replace '-Regular', ''
            }

            Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
            Write-Host -ForegroundColor 'Cyan' "Detected Nerd Font: $fontFamily"

            # Download the Windows Terminal settings template
            Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
            Write-Host -ForegroundColor 'Cyan' "Downloading Windows Terminal settings from GitHub..."

            try {
                $wtContent = (Invoke-WebRequest -Uri $wtSettingsUrl -UseBasicParsing -ErrorAction Stop).Content
            } catch {
                Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
                Write-Host -ForegroundColor 'Red' "Failed to download WT settings: $($_.Exception.Message)"
                $wtContent = $null
            }

            if ($wtContent) {
                # Parse and update the font face in the settings JSON
                $wtJson = $wtContent | ConvertFrom-Json

                # Update default profile font face
                if ($wtJson.profiles -and $wtJson.profiles.defaults) {
                    if ($wtJson.profiles.defaults.font) {
                        $wtJson.profiles.defaults.font.face = $fontFamily
                    }
                }

                # Also update any individual profile font faces
                if ($wtJson.profiles -and $wtJson.profiles.list) {
                    foreach ($p in $wtJson.profiles.list) {
                        if ($p.font -and $p.font.face) {
                            $p.font.face = $fontFamily
                        }
                    }
                }

                # Convert back to JSON (depth 10 to preserve nested structure)
                $wtUpdated = $wtJson | ConvertTo-Json -Depth 10

                # Compare with existing settings (normalise both through JSON pipeline to avoid formatting differences)
                if (Test-Path $wtSettingsPath) {
                    $existingWt = Get-Content -Path $wtSettingsPath -Raw -ErrorAction SilentlyContinue
                    try {
                        $existingNormalized = ($existingWt | ConvertFrom-Json | ConvertTo-Json -Depth 10).Trim()
                    } catch {
                        # Existing file has comments or invalid JSON - force overwrite
                        $existingNormalized = $null
                    }
                    $updatedNormalized = $wtUpdated.Trim()
                    if ($existingNormalized -eq $updatedNormalized) {
                        Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
                        Write-Host -ForegroundColor 'Green' "Windows Terminal settings already up to date"
                    } else {
                        # Back up existing settings
                        $wtBackup = "$wtSettingsPath.bak"
                        Copy-Item -Path $wtSettingsPath -Destination $wtBackup -Force
                        Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
                        Write-Host -ForegroundColor 'Yellow' "Existing Terminal settings backed up to: $wtBackup"

                        [System.IO.File]::WriteAllText($wtSettingsPath, $wtUpdated)
                        Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
                        Write-Host -ForegroundColor 'Green' "Windows Terminal settings updated (font: $fontFamily)"
                    }
                } else {
                    [System.IO.File]::WriteAllText($wtSettingsPath, $wtUpdated)
                    Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
                    Write-Host -ForegroundColor 'Green' "Windows Terminal settings saved (font: $fontFamily)"
                }
            }
        }
    }
}

function Set-CrossPlatformProfileSupport {
    Write-Host "`n[Pwsh Profile]: Setting up cross-version profile symlinks..."

    $ps7ProfileDir = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell'
    $ps5ProfileDir = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'WindowsPowerShell'
    $profileName = 'Microsoft.PowerShell_profile.ps1'
    $vscodeProfileName = 'Microsoft.VSCode_profile.ps1'

    # Determine primary (source of truth) and secondary (symlink) based on running PS version
    $pwsh7Cmd = Get-Command pwsh -ErrorAction SilentlyContinue
    if ($pwsh7Cmd) {
        $primaryDir = $ps7ProfileDir
        $secondaryDir = $ps5ProfileDir
        $primaryLabel = 'PowerShell 7'
        $secondaryLabel = 'PowerShell 5'
    } else {
        $primaryDir = $ps5ProfileDir
        $secondaryDir = $ps7ProfileDir
        $primaryLabel = 'PowerShell 5'
        $secondaryLabel = 'PowerShell 7'
    }

    # Ensure primary profile directory exists
    if (-not (Test-Path $primaryDir)) {
        New-Item -ItemType Directory -Path $primaryDir -Force | Out-Null
    }

    $primaryProfile = Join-Path $primaryDir $profileName

    # Check that the primary profile file exists before linking
    if (-not (Test-Path $primaryProfile)) {
        Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
        Write-Host -ForegroundColor 'Yellow' "No profile found at $primaryProfile - skipping profile symlinks"
        return
    }

    # Ensure secondary profile directory exists
    if (-not (Test-Path $secondaryDir)) {
        New-Item -ItemType Directory -Path $secondaryDir -Force | Out-Null
    }

    # Link secondary PS profile -> primary profile
    $secondaryProfile = Join-Path $secondaryDir $profileName
    if (Test-Path $secondaryProfile) {
        $item = Get-Item $secondaryProfile -ErrorAction SilentlyContinue
        if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
            Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
            Write-Host -ForegroundColor 'Green' "$secondaryLabel profile symlink already exists"
        } else {
            # Back up existing real file, then replace with symlink
            Rename-Item -Path $secondaryProfile -NewName "$profileName.bak" -Force
            New-Item -ItemType SymbolicLink -Path $secondaryProfile -Target $primaryProfile -Force | Out-Null
            Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
            Write-Host -ForegroundColor 'Green' "Symlink: $secondaryLabel profile -> $primaryLabel profile"
        }
    } else {
        New-Item -ItemType SymbolicLink -Path $secondaryProfile -Target $primaryProfile -Force | Out-Null
        Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
        Write-Host -ForegroundColor 'Green' "Symlink: $secondaryLabel profile -> $primaryLabel profile"
    }

    # Link VS Code profile -> primary profile (in the primary directory)
    $vscodeProfile = Join-Path $primaryDir $vscodeProfileName
    if (Test-Path $vscodeProfile) {
        $item = Get-Item $vscodeProfile -ErrorAction SilentlyContinue
        if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
            Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
            Write-Host -ForegroundColor 'Green' "VS Code profile symlink already exists"
        } else {
            Rename-Item -Path $vscodeProfile -NewName "$vscodeProfileName.bak" -Force
            New-Item -ItemType SymbolicLink -Path $vscodeProfile -Target $primaryProfile -Force | Out-Null
            Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
            Write-Host -ForegroundColor 'Green' "Symlink: VS Code profile -> $primaryLabel profile"
        }
    } else {
        New-Item -ItemType SymbolicLink -Path $vscodeProfile -Target $primaryProfile -Force | Out-Null
        Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
        Write-Host -ForegroundColor 'Green' "Symlink: VS Code profile -> $primaryLabel profile"
    }
}

function Register-PSProfile {
    Write-Host "`n[Pwsh Profile]: Registering PowerShell Profile..."

    # Dot-source the profile to load it into the current session
    if (Test-Path $PROFILE.CurrentUserCurrentHost) {
        . $PROFILE.CurrentUserCurrentHost
        Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
        Write-Host -ForegroundColor 'Green' "Profile loaded: $($PROFILE.CurrentUserCurrentHost)"
        Write-Host " "
    } else {
        Write-Host -ForegroundColor 'White' -NoNewline "[Pwsh Profile]: "
        Write-Host -ForegroundColor 'Yellow' "No profile found at $($PROFILE.CurrentUserCurrentHost) - skipping"
        Write-Host " "
    }
}

# Run setup
Invoke-SystemCheck

if ($ResetProfile -or $ResetModules -or $FactoryReset) {
    Invoke-Reset -ResetProfile:$ResetProfile -ResetModules:$ResetModules -FactoryReset:$FactoryReset
    Write-Host "`n[Pwsh Profile]: Reset complete - exiting. Re-run without reset switches to install."
    exit 0
}

Invoke-NerdFontInstall -fontName $nerdFontName
Install-WinGetApps
Install-PwshModules
Update-VSCodePwshModule
Invoke-ProfileSetup
Set-CrossPlatformProfileSupport
Register-PSProfile
