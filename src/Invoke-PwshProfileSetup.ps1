[CmdletBinding()]
param (
  # This region is refreshed by scripts/Update-NerdFontsCatalog.ps1.
  # BEGIN GENERATED NERD FONT VALIDATESET
  [ValidateSet(
    '0xProto',
    '3270',
    'AdwaitaMono',
    'Agave',
    'AnnotationM',
    'AnonymicePro',
    'Arimo',
    'AtkynsonMono',
    'AurulentSansM',
    'BigBlueTerm',
    'BitstromWera',
    'BlexMono',
    'CaskaydiaCove',
    'CaskaydiaMono',
    'CodeNewRoman',
    'ComicShannsMono',
    'CommitMono',
    'Cousine',
    'D2KodingLigature',
    'DaddyTimeMono',
    'DejaVuSansM',
    'DepartureMono',
    'DroidSansM',
    'EnvyCodeR',
    'FantasqueSansM',
    'FiraCode',
    'FiraMono',
    'GeistMono',
    'GohuFont',
    'GoMono',
    'GoogleSansCode',
    'Hack',
    'Hasklug',
    'HeavyData',
    'Hurmit',
    'iMWriting',
    'Inconsolata',
    'Inconsolata LGC',
    'InconsolataGo',
    'IntoneMono',
    'Iosevka',
    'IosevkaTerm',
    'IosevkaTermSlab',
    'JetBrainsMono',
    'Lekton',
    'Lilex',
    'LiterationMono',
    'M+',
    'MartianMono',
    'MesloLG',
    'Monaspice',
    'Monofur',
    'Monoid',
    'Mononoki',
    'Noto',
    'OpenDyslexic',
    'Overpass',
    'ProFont',
    'ProggyClean',
    'RecMono',
    'RobotoMono',
    'SauceCodePro',
    'ShureTechMono',
    'SpaceMono',
    'Symbols',
    'Terminess',
    'Tinos',
    'Ubuntu',
    'UbuntuMono',
    'UbuntuSans',
    'VictorMono',
    'ZedMono'
  )]
  [Parameter(Position = 0)]
  [Alias('NerdFont')]
  [string] $nerdFontName = ''
  # END GENERATED NERD FONT VALIDATESET

  ,
  [ValidateSet('All', 'NerdFont', 'Winget')]
  [string] $RunPhase = 'All'
)

function Write-PwshProfileStatus {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [string] $Stage,

    [Parameter(Mandatory)]
    [string] $Message,

    [ValidateSet('Info', 'Action', 'Success', 'Warning')]
    [string] $Type = 'Info'
  )

  $color = switch ($Type) {
    'Action' { 'Cyan' }
    'Success' { 'Green' }
    'Warning' { 'Yellow' }
    default { 'Gray' }
  }

  $sectionStages = @('Action', 'Admin', 'Download', 'Install', 'Terminal', 'Winget', 'Complete')
  if ($script:LastPwshProfileStatusStage -and
    $Stage -ne $script:LastPwshProfileStatusStage -and
    $Stage -in $sectionStages) {
    Write-Host ''
  }

  Write-Host ('[{0,-8}] ' -f $Stage) -ForegroundColor DarkGray -NoNewline
  Write-Host $Message -ForegroundColor $color
  $script:LastPwshProfileStatusStage = $Stage
}

function Write-PwshProfileHeader {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [string] $Title,

    [Parameter(Mandatory)]
    [string] $Subtitle
  )

  $line = '═' * 64
  Write-Host ''
  Write-Host $line -ForegroundColor DarkCyan
  Write-Host "  $Title" -ForegroundColor Cyan
  Write-Host "  $Subtitle" -ForegroundColor Gray
  Write-Host $line -ForegroundColor DarkCyan
  Write-Host ''
  $script:LastPwshProfileStatusStage = $null
}

function Test-PwshProfileAdministrator {
  [CmdletBinding()]
  param ()

  if (-not [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform(
      [System.Runtime.InteropServices.OSPlatform]::Windows
    )) {
    return $false
  }

  $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = [System.Security.Principal.WindowsPrincipal]::new($identity)
  return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-WindowsSudoConsoleMode {
  [CmdletBinding()]
  param ()

  $sudo = Get-Command sudo -ErrorAction SilentlyContinue
  if (-not $sudo) {
    return $null
  }

  $configuration = (& $sudo.Source config 2>&1 | Out-String).Trim()
  if ($LASTEXITCODE -ne 0 -or $configuration -match '(?i)disabled') {
    return $null
  }

  if ($configuration -match '(?i)inline|input\s+closed|disableInput|normal') {
    return [pscustomobject]@{
      Command = $sudo.Source
      Mode = 'CurrentConsole'
    }
  }

  [pscustomobject]@{
    Command = $sudo.Source
    Mode = 'NewWindow'
  }
}

function Start-PwshProfileElevated {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [string] $ScriptPath,

    [string] $NerdFontName,

    [ValidateSet('NerdFont', 'Winget')]
    [string] $RunPhase,

    [string] $Purpose = 'configuration'
  )

  if (-not [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform(
      [System.Runtime.InteropServices.OSPlatform]::Windows
    )) {
    throw 'Administrator elevation for Nerd Font installation is supported only on Windows.'
  }

  $pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
  if (-not $pwsh) {
    throw 'PowerShell 7 (pwsh) is required to start the elevated font installation session.'
  }

  $escapedScriptPath = $ScriptPath.Replace("'", "''")
  $command = "& '$escapedScriptPath'"
  if ($NerdFontName) {
    $escapedFontName = $NerdFontName.Replace("'", "''")
    $command = "$command -NerdFontName '$escapedFontName'"
  }
  if ($RunPhase) {
    $command = "$command -RunPhase '$RunPhase'"
  }
  $encodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
  $arguments = @(
    '-NoProfile',
    '-ExecutionPolicy', 'Bypass',
    '-EncodedCommand', $encodedCommand
  )

  $sudoConfiguration = Get-WindowsSudoConsoleMode
  if ($sudoConfiguration -and $sudoConfiguration.Mode -eq 'CurrentConsole') {
    Write-PwshProfileStatus -Stage 'Admin' -Type Action -Message "Approve the UAC prompt; $Purpose will continue in this terminal."
    & $sudoConfiguration.Command $pwsh.Source @arguments
    if ($LASTEXITCODE -ne 0) {
      throw "The Administrator PowerShell session exited with code $LASTEXITCODE."
    }
    Write-PwshProfileStatus -Stage 'Admin' -Type Success -Message 'Elevated installation completed.'
    return
  }

  Write-PwshProfileStatus -Stage 'Admin' -Type Action -Message "Approve the UAC prompt; $Purpose will continue in a separate PowerShell window."
  if (-not $sudoConfiguration) {
    Write-Verbose 'For same-terminal elevation, enable Windows sudo in Inline or Input closed mode.'
  }

  try {
    $process = Start-Process -FilePath $pwsh.Source -Verb RunAs -ArgumentList $arguments -Wait -PassThru -ErrorAction Stop
  } catch {
    throw "Unable to start an Administrator PowerShell session. $($_.Exception.Message)"
  }

  if ($process.ExitCode -ne 0) {
    throw "The Administrator PowerShell session exited with code $($process.ExitCode)."
  }

  Write-PwshProfileStatus -Stage 'Admin' -Type Success -Message 'Elevated installation completed.'
}

function Get-NerdFontsCatalog {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [uri] $RemoteUri
  )

  Write-PwshProfileStatus -Stage 'Catalog' -Message 'Loading the latest Nerd Fonts metadata...'
  Write-Verbose "Catalog source: $RemoteUri"

  $headers = @{
    Accept = 'application/vnd.github.raw+json'
    'User-Agent' = 'oh-my-posh-profile-setup'
  }

  try {
    $catalogJson = (Invoke-WebRequest -Uri $RemoteUri -Headers $headers -UseBasicParsing -ErrorAction Stop).Content
  } catch {
    throw "Unable to load the public Nerd Fonts catalog from '$RemoteUri'. $($_.Exception.Message)"
  }

  try {
    $catalog = $catalogJson | ConvertFrom-Json -ErrorAction Stop
  } catch {
    throw "The Nerd Fonts catalog is not valid JSON. $($_.Exception.Message)"
  }

  if (-not $catalog.NerdFontsVersion -or @($catalog.Fonts).Count -eq 0) {
    throw 'The Nerd Fonts catalog is missing NerdFontsVersion or font entries.'
  }

  Write-PwshProfileStatus -Stage 'Catalog' -Type Success -Message "Loaded $(@($catalog.Fonts).Count) fonts from release $($catalog.NerdFontsVersion)."

  $catalog
}

function Resolve-NerdFont {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [object] $Catalog,

    [Parameter(Mandatory)]
    [string] $Name
  )

  $font = $Catalog.Fonts |
    Where-Object FriendlyName -EQ $Name |
    Select-Object -First 1

  if (-not $font) {
    throw "Nerd Font '$Name' was not found in the generated catalog."
  }

  $font
}

function Get-WindowsFontDirectories {
  [CmdletBinding()]
  param ()

  if (-not [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform(
      [System.Runtime.InteropServices.OSPlatform]::Windows
    )) {
    throw 'The Windows Fonts directory is available only on Windows.'
  }

  $fontDirectories = @(
    Join-Path $env:WINDIR 'Fonts'
    Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
  ) | Where-Object {
    Test-Path -LiteralPath $_ -PathType Container
  } | Select-Object -Unique

  if (@($fontDirectories).Count -eq 0) {
    throw 'No Windows system or per-user Fonts directories were found.'
  }

  $fontDirectories
}

function ConvertTo-NerdFontMatchName {
  [CmdletBinding()]
  param (
    [AllowEmptyString()]
    [string] $Name
  )

  ($Name -replace '[^a-zA-Z0-9]', '').ToLowerInvariant()
}

function Find-InstalledNerdFont {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [object] $Font,

    [Parameter(Mandatory)]
    [string[]] $FontDirectories
  )

  $existingFontDirectories = @(
    $FontDirectories | Where-Object {
      Test-Path -LiteralPath $_ -PathType Container
    } | Select-Object -Unique
  )
  if ($existingFontDirectories.Count -eq 0) {
    throw "No font directories were found: $($FontDirectories -join ', ')"
  }

  $matchNames = @(
    @(
      $Font.FriendlyName
      $Font.ArchiveName
    ) | ForEach-Object {
      ConvertTo-NerdFontMatchName -Name ([string]$_)
    } | Where-Object {
      $_.Length -ge 3
    } | Sort-Object -Unique
  )

  Get-ChildItem -LiteralPath $existingFontDirectories -File -ErrorAction Stop |
    Where-Object Extension -In @('.ttf', '.otf', '.ttc') |
    Where-Object {
    $fileName = ConvertTo-NerdFontMatchName -Name $_.BaseName
    $matchesFontName = $matchNames.Where({ $fileName.Contains($_) }).Count -gt 0
    $hasNerdFontMarker = $fileName.Contains('nerdfont') -or
    $matchNames.Where({ $fileName.Contains("${_}nf") }).Count -gt 0

    $matchesFontName -and $hasNerdFontMarker
  } |
    Sort-Object FullName -Unique
}

function ConvertTo-NerdFontsReleaseVersion {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [string] $Version
  )

  try {
    [version]($Version.Trim().TrimStart('v'))
  } catch {
    throw "Invalid Nerd Fonts release version '$Version'."
  }
}

function Get-NerdFontInstallDecision {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [bool] $IsInstalled,

    [AllowNull()]
    [object] $InstallState,

    [Parameter(Mandatory)]
    [string] $LatestNerdFontsVersion,

    [Parameter(Mandatory)]
    [string] $LatestFontVersion
  )

  if (-not $IsInstalled) {
    return [pscustomobject]@{
      RequiresInstall = $true
      UpdateAvailable = $false
      InstalledVersion = $null
      IsNewerThanCatalog = $false
      IsUntracked = $false
      Reason = 'not installed'
    }
  }

  if (-not $InstallState -or -not $InstallState.NerdFontsVersion) {
    return [pscustomobject]@{
      RequiresInstall = $false
      UpdateAvailable = $false
      InstalledVersion = $null
      IsNewerThanCatalog = $false
      IsUntracked = $true
      Reason = 'installed release is unknown'
    }
  }

  $installedVersion = [string]$InstallState.NerdFontsVersion
  $installedRelease = ConvertTo-NerdFontsReleaseVersion -Version $installedVersion
  $latestRelease = ConvertTo-NerdFontsReleaseVersion -Version $LatestNerdFontsVersion
  $fontVersionChanged = [string]$InstallState.FontVersion -ne $LatestFontVersion

  if ($installedRelease -gt $latestRelease) {
    return [pscustomobject]@{
      RequiresInstall = $false
      UpdateAvailable = $false
      InstalledVersion = $installedVersion
      IsNewerThanCatalog = $true
      IsUntracked = $false
      Reason = 'installed release is newer than the catalog'
    }
  }

  if ($installedRelease -lt $latestRelease -or $fontVersionChanged) {
    $reason = if ($installedRelease -lt $latestRelease) {
      "Nerd Fonts $installedVersion → $LatestNerdFontsVersion"
    } else {
      "font version $($InstallState.FontVersion) → $LatestFontVersion"
    }

    return [pscustomobject]@{
      RequiresInstall = $true
      UpdateAvailable = $true
      InstalledVersion = $installedVersion
      IsNewerThanCatalog = $false
      IsUntracked = $false
      Reason = $reason
    }
  }

  [pscustomobject]@{
    RequiresInstall = $false
    UpdateAvailable = $false
    InstalledVersion = $installedVersion
    IsNewerThanCatalog = $false
    IsUntracked = $false
    Reason = 'current'
  }
}

function Get-NerdFontInstallState {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [string] $RegistryPath,

    [Parameter(Mandatory)]
    [string] $ArchiveName
  )

  if (-not (Test-Path -LiteralPath $RegistryPath)) {
    return $null
  }

  $registryState = Get-ItemProperty -LiteralPath $RegistryPath -ErrorAction SilentlyContinue
  if (-not $registryState -or -not $registryState.PSObject.Properties[$ArchiveName]) {
    return $null
  }

  $stateJson = $registryState.PSObject.Properties[$ArchiveName].Value
  if (-not $stateJson) {
    return $null
  }

  try {
    $stateJson | ConvertFrom-Json -ErrorAction Stop
  } catch {
    Write-Warning "Ignoring invalid install state for '$ArchiveName'."
    $null
  }
}

function Set-NerdFontInstallState {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [string] $RegistryPath,

    [Parameter(Mandatory)]
    [object] $Font,

    [Parameter(Mandatory)]
    [string] $NerdFontsVersion
  )

  if (-not (Test-Path -LiteralPath $RegistryPath)) {
    New-Item -Path $RegistryPath -Force | Out-Null
  }

  $state = [ordered]@{
    NerdFontsVersion = $NerdFontsVersion
    FontVersion = [string]$Font.FontVersion
    InstalledAt = [DateTimeOffset]::UtcNow.ToString('o')
  } | ConvertTo-Json -Compress

  New-ItemProperty -LiteralPath $RegistryPath -Name ([string]$Font.ArchiveName) -Value $state -PropertyType String -Force | Out-Null
}

function Select-NerdFontInstallFiles {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [object] $Font,

    [Parameter(Mandatory)]
    [string] $ExtractPath
  )

  $matchNames = @(
    @($Font.FriendlyName, $Font.ArchiveName) | ForEach-Object {
      ConvertTo-NerdFontMatchName -Name ([string]$_)
    } | Where-Object { $_.Length -ge 3 } | Sort-Object -Unique
  )

  $patchedFiles = @(
    Get-ChildItem -LiteralPath $ExtractPath -Recurse -File |
      Where-Object Extension -In @('.ttf', '.otf', '.ttc') |
      Where-Object {
      $fileName = ConvertTo-NerdFontMatchName -Name $_.BaseName
      $matchesFontName = $matchNames.Where({ $fileName.Contains($_) }).Count -gt 0
      $hasNerdFontMarker = $fileName.Contains('nerdfont') -or
      $matchNames.Where({ $fileName.Contains("${_}nf") }).Count -gt 0
      $matchesFontName -and $hasNerdFontMarker
    }
  )

  $regularFiles = @($patchedFiles | Where-Object { $_.BaseName -match '(?i)regular' })
  if ($regularFiles.Count -gt 0) {
    $patchedFiles = $regularFiles
  }

  $friendlyName = ConvertTo-NerdFontMatchName -Name ([string]$Font.FriendlyName)
  $preferredFiles = @(
    $patchedFiles | Where-Object {
      (ConvertTo-NerdFontMatchName -Name $_.BaseName) -eq "${friendlyName}nerdfontregular"
    }
  )
  if ($preferredFiles.Count -gt 0) {
    return $preferredFiles
  }

  $patchedFiles | Sort-Object FullName -Unique
}

function Remove-NerdFontRegistration {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [System.IO.FileInfo[]] $FontFiles
  )

  $registryPaths = @(
    'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
    'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
  )

  foreach ($registryPath in $registryPaths) {
    if (-not (Test-Path -LiteralPath $registryPath)) {
      continue
    }

    $properties = (Get-ItemProperty -LiteralPath $registryPath).PSObject.Properties
    foreach ($fontFile in $FontFiles) {
      $properties | Where-Object {
        $_.Name -notmatch '^PS' -and
        ([System.IO.Path]::GetFileName([string]$_.Value) -eq $fontFile.Name -or
          [string]$_.Value -eq $fontFile.FullName)
      } | ForEach-Object {
        Remove-ItemProperty -LiteralPath $registryPath -Name $_.Name -ErrorAction SilentlyContinue
      }
    }
  }
}

function Send-WindowsFontChange {
  [CmdletBinding()]
  param ()

  if (-not ('PwshProfile.NativeMethods' -as [type])) {
    Add-Type -TypeDefinition @'
namespace PwshProfile {
  using System;
  using System.Runtime.InteropServices;

  public static class NativeMethods {
    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
    public static extern IntPtr SendMessageTimeout(
      IntPtr hWnd, uint Msg, UIntPtr wParam, IntPtr lParam,
      uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
  }
}
'@
  }

  $result = [UIntPtr]::Zero
  [void][PwshProfile.NativeMethods]::SendMessageTimeout(
    [IntPtr]0xffff,
    0x001D,
    [UIntPtr]::Zero,
    [IntPtr]::Zero,
    0x0002,
    5000,
    [ref]$result
  )
}

function Get-NerdFontFaceName {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [System.IO.FileInfo] $FontFile
  )

  try {
    Add-Type -AssemblyName System.Drawing -ErrorAction Stop
    $fontCollection = [System.Drawing.Text.PrivateFontCollection]::new()
    try {
      $fontCollection.AddFontFile($FontFile.FullName)
      $familyName = @($fontCollection.Families | Select-Object -ExpandProperty Name) |
        Where-Object { $_ -match '(?i)\b(NF|Nerd Font)\b' } |
        Select-Object -First 1

      if (-not $familyName) {
        $familyName = $fontCollection.Families | Select-Object -ExpandProperty Name -First 1
      }

      if ($familyName) {
        return $familyName
      }
    } finally {
      $fontCollection.Dispose()
    }
  } catch {
    Write-Verbose "Unable to read font family metadata from '$($FontFile.FullName)': $($_.Exception.Message)"
  }

  if ($FontFile.BaseName -match '^(?<family>.+?)NerdFont') {
    return "$($Matches.family) NF"
  }

  $FontFile.BaseName -replace '-Regular$', ''
}

function Get-WindowsTerminalSettingsPaths {
  [CmdletBinding()]
  param ()

  @(
    Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'
    Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json'
  ) | Where-Object {
    Test-Path -LiteralPath $_ -PathType Leaf
  }
}

function Set-ObjectPropertyValue {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [object] $InputObject,

    [Parameter(Mandatory)]
    [string] $Name,

    [Parameter(Mandatory)]
    [AllowNull()]
    [object] $Value
  )

  if ($InputObject.PSObject.Properties[$Name]) {
    $InputObject.$Name = $Value
  } else {
    Add-Member -InputObject $InputObject -MemberType NoteProperty -Name $Name -Value $Value
  }
}

function Update-WindowsTerminalFontFace {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [string] $FontFace,

    [int] $FontSize = 10,

    [switch] $PostInstall,

    [string[]] $SettingsPaths = @(Get-WindowsTerminalSettingsPaths)
  )

  if ($SettingsPaths.Count -eq 0) {
    Write-PwshProfileStatus -Stage 'Terminal' -Type Warning -Message 'Windows Terminal settings were not found; font update skipped.'
    return
  }

  foreach ($settingsPath in $SettingsPaths) {
    $settingsJson = Get-Content -LiteralPath $settingsPath -Raw -ErrorAction Stop
    try {
      $settings = $settingsJson | ConvertFrom-Json -ErrorAction Stop
    } catch {
      Write-PwshProfileStatus -Stage 'Terminal' -Type Warning -Message "Could not parse settings at $settingsPath; font update skipped."
      continue
    }

    $changed = $false
    if (-not $settings.profiles) {
      Set-ObjectPropertyValue -InputObject $settings -Name 'profiles' -Value ([pscustomobject]@{})
      $changed = $true
    }
    if (-not $settings.profiles.defaults) {
      Set-ObjectPropertyValue -InputObject $settings.profiles -Name 'defaults' -Value ([pscustomobject]@{})
      $changed = $true
    }
    if (-not $settings.profiles.defaults.font) {
      Set-ObjectPropertyValue -InputObject $settings.profiles.defaults -Name 'font' -Value ([pscustomobject]@{})
      $changed = $true
    }
    if ($settings.profiles.defaults.font.face -ne $FontFace) {
      Set-ObjectPropertyValue -InputObject $settings.profiles.defaults.font -Name 'face' -Value $FontFace
      $changed = $true
    }
    if ($settings.profiles.defaults.font.size -ne $FontSize) {
      Set-ObjectPropertyValue -InputObject $settings.profiles.defaults.font -Name 'size' -Value $FontSize
      $changed = $true
    }

    if ($settings.profiles.list) {
      foreach ($profile in @($settings.profiles.list)) {
        if ($profile.font -and $profile.font.face -and $profile.font.face -ne $FontFace) {
          $profile.font.face = $FontFace
          $changed = $true
        }
        if ($profile.font -and $profile.font.size -and $profile.font.size -ne $FontSize) {
          $profile.font.size = $FontSize
          $changed = $true
        }
      }
    }

    if (-not $changed) {
      $statusSuffix = if ($PostInstall) { 'confirmed' } else { 'already configured' }
      Write-PwshProfileStatus -Stage 'Terminal' -Type Success -Message "Font Install: $FontFace $statusSuffix"
      Write-PwshProfileStatus -Stage 'Terminal' -Type Success -Message "Font Size: $FontSize $statusSuffix"
      continue
    }

    $backupTimestamp = [DateTimeOffset]::UtcNow.ToString('yyyyMMddHHmmss')
    $backupPath = "$settingsPath.$backupTimestamp.bak"
    Copy-Item -LiteralPath $settingsPath -Destination $backupPath -Force
    $updatedJson = $settings | ConvertTo-Json -Depth 100
    [System.IO.File]::WriteAllText(
      [System.IO.Path]::GetFullPath($settingsPath),
      "$updatedJson`n",
      [System.Text.UTF8Encoding]::new($false)
    )
    Write-PwshProfileStatus -Stage 'Terminal' -Type Success -Message "Config Backup: $backupPath"
    Write-PwshProfileStatus -Stage 'Terminal' -Type Success -Message "Font Install: $FontFace"
    Write-PwshProfileStatus -Stage 'Terminal' -Type Success -Message "Font Size: $FontSize"
  }
}

function Update-WindowsTerminalFromNerdFontFiles {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [AllowEmptyCollection()]
    [System.IO.FileInfo[]] $FontFiles,

    [switch] $PostInstall,

    [string[]] $SettingsPaths = @(Get-WindowsTerminalSettingsPaths)
  )

  if ($FontFiles.Count -eq 0) {
    Write-PwshProfileStatus -Stage 'Terminal' -Type Warning -Message 'No installed font files were found; settings update skipped.'
    return
  }

  $fontFace = Get-NerdFontFaceName -FontFile $FontFiles[0]
  Write-PwshProfileStatus -Stage 'Font' -Type Success -Message "Windows font family: $fontFace"
  Write-PwshProfileStatus -Stage 'Terminal' -Message "font.face: $fontFace"
  Write-PwshProfileStatus -Stage 'VS Code' -Message "terminal.integrated.fontFamily: $fontFace"
  Write-PwshProfileStatus -Stage 'VS Code' -Message "editor.fontFamily: '$fontFace', Consolas, 'Courier New', monospace"
  Update-WindowsTerminalFontFace -FontFace $fontFace -PostInstall:$PostInstall -SettingsPaths $SettingsPaths
}

function Install-NerdFont {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [object] $Font,

    [Parameter(Mandatory)]
    [string] $NerdFontsVersion,

    [Parameter(Mandatory)]
    [AllowEmptyCollection()]
    [System.IO.FileInfo[]] $ExistingFiles,

    [Parameter(Mandatory)]
    [string] $StateRegistryPath
  )

  if (-not (Test-PwshProfileAdministrator)) {
    throw 'Nerd Font installation must run in an Administrator PowerShell session.'
  }

  $tempRoot = Join-Path $env:TEMP "NerdFont-$($Font.ArchiveName)-$([guid]::NewGuid().ToString('N'))"
  $archivePath = "$tempRoot.zip"
  New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

  try {
    Write-PwshProfileStatus -Stage 'Download' -Type Action -Message "$($Font.FriendlyName) from Nerd Fonts $NerdFontsVersion"
    Invoke-WebRequest -Uri $Font.DownloadUrl -OutFile $archivePath -UseBasicParsing -ErrorAction Stop
    Expand-Archive -LiteralPath $archivePath -DestinationPath $tempRoot -Force

    $installFiles = @(Select-NerdFontInstallFiles -Font $Font -ExtractPath $tempRoot)
    if ($installFiles.Count -eq 0) {
      throw "No installable Nerd Font files were found in '$($Font.DownloadUrl)'."
    }

    if ($ExistingFiles.Count -gt 0) {
      Remove-NerdFontRegistration -FontFiles $ExistingFiles
      foreach ($existingFile in $ExistingFiles) {
        Remove-Item -LiteralPath $existingFile.FullName -Force -ErrorAction Stop
      }
    }

    $systemFontDirectory = Join-Path $env:WINDIR 'Fonts'
    $systemFontRegistry = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
    $installedFiles = [System.Collections.Generic.List[System.IO.FileInfo]]::new()
    foreach ($fontFile in $installFiles) {
      $destination = Join-Path $systemFontDirectory $fontFile.Name
      Copy-Item -LiteralPath $fontFile.FullName -Destination $destination -Force -ErrorAction Stop
      $fontType = if ($fontFile.Extension -ieq '.otf') { 'OpenType' } else { 'TrueType' }
      $registryName = "$($fontFile.BaseName) ($fontType)"
      New-ItemProperty -LiteralPath $systemFontRegistry -Name $registryName -Value $fontFile.Name -PropertyType String -Force | Out-Null
      Write-PwshProfileStatus -Stage 'Install' -Type Success -Message $destination
      $installedFiles.Add((Get-Item -LiteralPath $destination))
    }

    Send-WindowsFontChange
    Set-NerdFontInstallState -RegistryPath $StateRegistryPath -Font $Font -NerdFontsVersion $NerdFontsVersion
    $installedFiles
  } finally {
    Remove-Item -LiteralPath $archivePath -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
  }
}

function Get-WingetPackageDefinitions {
  [CmdletBinding()]
  param ()

  @(
    [pscustomobject]@{ Id = 'Amazon.AWSCLI'; Name = 'AWS CLI'; Scope = 'machine' }
    [pscustomobject]@{ Id = 'Git.Git'; Name = 'Git'; Scope = 'machine' }
    [pscustomobject]@{ Id = 'GitHub.cli'; Name = 'GitHub CLI'; Scope = 'machine' }
    [pscustomobject]@{ Id = 'Hashicorp.Terraform'; Name = 'Terraform'; Scope = 'machine' }
    [pscustomobject]@{ Id = 'Helm.Helm'; Name = 'Helm'; Scope = 'machine' }
    [pscustomobject]@{ Id = 'JanDeDobbeleer.OhMyPosh'; Name = 'Oh My Posh'; Scope = 'user' }
    [pscustomobject]@{ Id = 'Kubernetes.kubectl'; Name = 'kubectl'; Scope = 'machine' }
    [pscustomobject]@{ Id = 'Microsoft.Azure.Kubelogin'; Name = 'Azure Kubelogin'; Scope = 'machine' }
    [pscustomobject]@{ Id = 'Microsoft.AzureCLI'; Name = 'Azure CLI'; Scope = 'machine' }
    [pscustomobject]@{ Id = 'Ookla.Speedtest.CLI'; Name = 'Speedtest CLI'; Scope = 'machine' }
  )
}

function Get-WingetCommand {
  [CmdletBinding()]
  param ()

  $winget = Get-Command winget -ErrorAction SilentlyContinue
  if (-not $winget) {
    throw 'Winget was not found. Install App Installer from Microsoft Store, then rerun this script.'
  }

  $winget.Source
}

function Update-WingetSources {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [string] $WingetPath
  )

  $wingetVersion = (& $WingetPath --version 2>$null | Select-Object -First 1)
  if ($wingetVersion) {
    Write-PwshProfileStatus -Stage 'Winget' -Type Success -Message "Version: $wingetVersion"
  }

  Write-PwshProfileStatus -Stage 'Winget' -Type Action -Message 'Updating sources...'
  $sourceUpdateOutput = & $WingetPath source update --disable-interactivity 2>&1
  $sourceUpdateExitCode = $LASTEXITCODE
  $sourceUpdateOutput | ForEach-Object {
    $line = ([string]$_).Trim()
    if ($line) {
      Write-PwshProfileStatus -Stage 'Winget' -Message $line
    }
  }

  if ($sourceUpdateExitCode -ne 0) {
    throw "Winget source update failed with exit code $sourceUpdateExitCode."
  }

  Write-PwshProfileStatus -Stage 'Winget' -Type Success -Message 'Sources updated.'
  Write-Host ''
}

function Test-WingetPackageInstalled {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [string] $PackageId,

    [Parameter(Mandatory)]
    [string] $WingetPath
  )

  $output = & $WingetPath list --id $PackageId --exact --source winget --accept-source-agreements --disable-interactivity 2>$null | Out-String
  $LASTEXITCODE -eq 0 -and $output -match [regex]::Escape($PackageId)
}

function Test-WingetPackageUpgradeAvailable {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [string] $PackageId,

    [Parameter(Mandatory)]
    [string] $WingetPath
  )

  $output = & $WingetPath upgrade --id $PackageId --exact --source winget --accept-source-agreements --disable-interactivity 2>$null | Out-String
  $LASTEXITCODE -eq 0 -and $output -match [regex]::Escape($PackageId)
}

function Invoke-WingetElevatedPackageAction {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [string] $WingetPath,

    [Parameter(Mandatory)]
    [string[]] $Arguments,

    [Parameter(Mandatory)]
    [string] $PackageId
  )

  $sudoConfiguration = Get-WindowsSudoConsoleMode
  if ($sudoConfiguration -and $sudoConfiguration.Mode -eq 'CurrentConsole') {
    & $sudoConfiguration.Command $WingetPath @Arguments
    if ($LASTEXITCODE -ne 0) {
      throw "Elevated Winget command failed for '$PackageId' with exit code $LASTEXITCODE."
    }
    return
  }

  Write-PwshProfileStatus -Stage 'Admin' -Type Action -Message "Approve the UAC prompt; only '$PackageId' will run elevated."
  $process = Start-Process -FilePath $WingetPath -Verb RunAs -ArgumentList $Arguments -Wait -PassThru -ErrorAction Stop
  if ($process.ExitCode -ne 0) {
    throw "Elevated Winget command failed for '$PackageId' with exit code $($process.ExitCode)."
  }
}

function Invoke-WingetPackageAction {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [object] $Package,

    [Parameter(Mandatory)]
    [string] $WingetPath,

    [Parameter(Mandatory)]
    [ValidateSet('install', 'upgrade')]
    [string] $Action
  )

  $arguments = @(
    $Action,
    '--id', $Package.Id,
    '--exact',
    '--source', 'winget',
    '--scope', $Package.Scope,
    '--silent',
    '--accept-package-agreements',
    '--accept-source-agreements',
    '--disable-interactivity'
  )

  Write-Host ''
  $displayAction = if ($Action -eq 'install') { 'Installing' } else { 'Upgrading' }
  Write-PwshProfileStatus -Stage 'Winget' -Type Action -Message "$displayAction $($Package.Id) [$($Package.Scope)]"
  if ($Package.Scope -eq 'machine' -and -not (Test-PwshProfileAdministrator)) {
    Invoke-WingetElevatedPackageAction -WingetPath $WingetPath -Arguments $arguments -PackageId $Package.Id
    return
  }

  & $WingetPath @arguments
  if ($LASTEXITCODE -ne 0) {
    throw "Winget $Action failed for '$($Package.Id)' with exit code $LASTEXITCODE."
  }
}

function Show-WingetPackageInventory {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [object[]] $Packages
  )

  Write-PwshProfileStatus -Stage 'Winget' -Message 'Package inventory:'
  $Packages |
    Sort-Object Scope, Id |
    Format-Table -Property `
    @{ Label = 'Package ID'; Expression = { $_.Id } },
  @{ Label = 'Scope'; Expression = { $_.Scope } } `
    -AutoSize |
    Out-String -Width 160 |
    ForEach-Object {
    $_ -split '\r?\n'
  } |
    ForEach-Object {
    $_.TrimEnd()
  } |
    Where-Object { $_ } |
    ForEach-Object {
    Write-PwshProfileStatus -Stage 'Winget' -Message $_
  }
  Write-Host ''
}

function Invoke-WingetConfiguration {
  [CmdletBinding()]
  param (
    [string] $ScriptPath,
    [string] $NerdFontName
  )

  Write-PwshProfileHeader -Title 'Pwsh Profile Installer' -Subtitle 'Winget Package Configuration'

  $wingetPath = Get-WingetCommand
  Update-WingetSources -WingetPath $wingetPath

  $packages = @(Get-WingetPackageDefinitions)
  Show-WingetPackageInventory -Packages $packages
  Write-PwshProfileStatus -Stage 'Winget' -Message "Checking $($packages.Count) package(s)..."

  $packageStates = @(
    foreach ($package in $packages) {
      [pscustomobject]@{
        Package = $package
        Installed = Test-WingetPackageInstalled -PackageId $package.Id -WingetPath $wingetPath
      }
    }
  )

  foreach ($state in $packageStates) {
    if ($state.Installed) {
      Write-PwshProfileStatus -Stage 'Winget' -Type Success -Message "$($state.Package.Id) installed [$($state.Package.Scope)]"
      if (Test-WingetPackageUpgradeAvailable -PackageId $state.Package.Id -WingetPath $wingetPath) {
        Write-PwshProfileStatus -Stage 'Winget' -Type Action -Message "$($state.Package.Id) update available [$($state.Package.Scope)]"
        Invoke-WingetPackageAction -Package $state.Package -WingetPath $wingetPath -Action upgrade
      } else {
        Write-PwshProfileStatus -Stage 'Winget' -Type Success -Message "$($state.Package.Id) latest [$($state.Package.Scope)]"
      }
    } else {
      Invoke-WingetPackageAction -Package $state.Package -WingetPath $wingetPath -Action install
    }
  }
}

$nerdFontsCatalogUri = 'https://raw.githubusercontent.com/smoonlee/oh-my-posh-profile-dev/main/NerdFontsCatalog.json'
$nerdFontStateRegistryPath = 'HKCU:\Software\smoonlee\OhMyPoshProfile\NerdFonts'
$nerdFontsVersion = $null
$nerdFontVersion = $null
$nerdFontArchiveName = $null
$nerdFontInstalled = $false
$installedNerdFontsVersion = $null
$nerdFontUpdateAvailable = $false
$installedNerdFontFiles = @()

if ($RunPhase -in @('All', 'NerdFont') -and $nerdFontName) {
  Write-PwshProfileHeader -Title 'Pwsh Profile Installer' -Subtitle 'Nerd Font Configuration'

  $nerdFontsCatalog = Get-NerdFontsCatalog -RemoteUri $nerdFontsCatalogUri
  $selectedNerdFont = Resolve-NerdFont -Catalog $nerdFontsCatalog -Name $nerdFontName

  # Download archives use ArchiveName.zip; keep the validated friendly name intact.
  $nerdFontArchiveName = $selectedNerdFont.ArchiveName
  $nerdFontVersion = $selectedNerdFont.FontVersion
  $nerdFontsVersion = $nerdFontsCatalog.NerdFontsVersion
  Write-PwshProfileStatus -Stage 'Font' -Message "Selected $nerdFontName (archive: $nerdFontArchiveName; font: $nerdFontVersion)."

  $windowsFontDirectories = @(Get-WindowsFontDirectories)
  Write-PwshProfileStatus -Stage 'Check' -Message "Searching $($windowsFontDirectories.Count) Windows font location(s)..."
  $installedNerdFontFiles = @(
    Find-InstalledNerdFont -Font $selectedNerdFont -FontDirectories $windowsFontDirectories
  )
  $nerdFontInstalled = $installedNerdFontFiles.Count -gt 0
  $installState = Get-NerdFontInstallState -RegistryPath $nerdFontStateRegistryPath -ArchiveName $nerdFontArchiveName
  $installDecision = Get-NerdFontInstallDecision `
    -IsInstalled $nerdFontInstalled `
    -InstallState $installState `
    -LatestNerdFontsVersion $nerdFontsVersion `
    -LatestFontVersion ([string]$nerdFontVersion)
  $installedNerdFontsVersion = $installDecision.InstalledVersion
  $nerdFontUpdateAvailable = $installDecision.UpdateAvailable

  if ($installDecision.IsNewerThanCatalog) {
    Write-PwshProfileStatus -Stage 'Version' -Type Warning -Message "Installed $installedNerdFontsVersion is newer than catalog $nerdFontsVersion; downgrade skipped."
  }

  if (-not $installDecision.RequiresInstall) {
    if ($installDecision.IsUntracked) {
      Write-PwshProfileStatus -Stage 'Installed' -Type Warning -Message "$nerdFontName found; release unknown, so it was left unchanged."
    } else {
      Write-PwshProfileStatus -Stage 'Current' -Type Success -Message "$nerdFontName at Nerd Fonts $installedNerdFontsVersion."
    }
    $installedNerdFontFiles | ForEach-Object {
      Write-PwshProfileStatus -Stage 'File' -Message $_.FullName
    }
    if ($installedNerdFontFiles.Count -gt 0) {
      Update-WindowsTerminalFromNerdFontFiles -FontFiles $installedNerdFontFiles
    }
  }
  else {

    Write-PwshProfileStatus -Stage 'Action' -Type Action -Message "$nerdFontName requires installation: $($installDecision.Reason)."
    if (-not (Test-PwshProfileAdministrator)) {
      Start-PwshProfileElevated -ScriptPath $PSCommandPath -NerdFontName $nerdFontName -RunPhase 'NerdFont' -Purpose 'Nerd Font installation'
      $installedNerdFontFiles = @(
        Find-InstalledNerdFont -Font $selectedNerdFont -FontDirectories $windowsFontDirectories
      )
      Update-WindowsTerminalFromNerdFontFiles -FontFiles $installedNerdFontFiles -PostInstall
      if ($RunPhase -eq 'NerdFont') {
        return
      }
    }
    else {

      $newlyInstalledFontFiles = @(
        Install-NerdFont `
          -Font $selectedNerdFont `
          -NerdFontsVersion $nerdFontsVersion `
          -ExistingFiles $installedNerdFontFiles `
          -StateRegistryPath $nerdFontStateRegistryPath
      )

      Update-WindowsTerminalFromNerdFontFiles -FontFiles $newlyInstalledFontFiles -PostInstall

      Write-PwshProfileStatus -Stage 'Complete' -Type Success -Message "$nerdFontName installed at Nerd Fonts $nerdFontsVersion."
    }
  }
}

if ($RunPhase -in @('All', 'Winget')) {
  Invoke-WingetConfiguration -ScriptPath $PSCommandPath -NerdFontName $nerdFontName
}
