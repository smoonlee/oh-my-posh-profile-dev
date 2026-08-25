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
  [string] $nerdFontName
  # END GENERATED NERD FONT VALIDATESET

  ,
  [ValidateSet('All', 'NerdFont', 'Winget', 'Modules')]
  [string] $RunPhase = 'All',

  [switch] $Reset
)

function Write-PwshProfileStatus {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [string] $Stage,

    [Parameter(Mandatory)]
    [string] $Message,

    [ValidateSet('Info', 'Action', 'Current', 'Success', 'Warning', 'Danger')]
    [string] $Type = 'Info'
  )

  $color = switch ($Type) {
    'Action' { 'Cyan' }
    'Current' { 'Gray' }
    'Success' { 'Green' }
    'Warning' { 'Yellow' }
    'Danger' { 'Red' }
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

    [Parameter(Mandatory)]
    [string] $NerdFontName
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
  $escapedFontName = $NerdFontName.Replace("'", "''")
  $command = "& '$escapedScriptPath' -NerdFontName '$escapedFontName' -RunPhase 'NerdFont'"
  $encodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
  $arguments = @(
    '-NoProfile',
    '-ExecutionPolicy', 'Bypass',
    '-EncodedCommand', $encodedCommand
  )

  $sudoConfiguration = Get-WindowsSudoConsoleMode
  if ($sudoConfiguration -and $sudoConfiguration.Mode -eq 'CurrentConsole') {
    Write-PwshProfileStatus -Stage 'Admin' -Type Action -Message 'Approve the UAC prompt; Nerd Font installation will continue in this terminal.'
    & $sudoConfiguration.Command $pwsh.Source @arguments
    if ($LASTEXITCODE -ne 0) {
      throw "The Administrator PowerShell session exited with code $LASTEXITCODE."
    }
    Write-PwshProfileStatus -Stage 'Admin' -Type Success -Message 'Elevated installation completed.'
    return
  }

  Write-PwshProfileStatus -Stage 'Admin' -Type Action -Message 'Approve the UAC prompt; Nerd Font installation will continue in a separate PowerShell window.'
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

  Write-PwshProfileStatus -Stage 'Catalog' -Type Current -Message "Loaded $(@($catalog.Fonts).Count) fonts from release $($catalog.NerdFontsVersion)."

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

function Initialize-CodeDirectory {
  [CmdletBinding()]
  param (
    [string] $CodePath = 'C:\Code',

    [AllowEmptyString()]
    [string] $OneDrivePath = $env:OneDrive
  )

  $existingCodePath = Get-Item -LiteralPath $CodePath -Force -ErrorAction SilentlyContinue
  if ($existingCodePath) {
    if (-not $existingCodePath.PSIsContainer) {
      throw "'$CodePath' exists but is not a directory."
    }

    return $CodePath
  }

  $oneDriveCodePath = if ($OneDrivePath) { Join-Path $OneDrivePath 'Code' }
  if ($oneDriveCodePath -and (Test-Path -LiteralPath $oneDriveCodePath -PathType Container)) {
    try {
      New-Item -ItemType SymbolicLink -Path $CodePath -Target $oneDriveCodePath -ErrorAction Stop | Out-Null
      Write-PwshProfileStatus -Stage 'Terminal' -Type Success -Message "Starting directory linked: $CodePath -> $oneDriveCodePath"
      return $CodePath
    } catch {
      Write-PwshProfileStatus -Stage 'Terminal' -Type Warning -Message "Could not link '$CodePath' to '$oneDriveCodePath'; creating a local directory instead. $($_.Exception.Message)"
    }
  }

  New-Item -ItemType Directory -Path $CodePath -Force -ErrorAction Stop | Out-Null
  Write-PwshProfileStatus -Stage 'Terminal' -Type Success -Message "Starting directory created: $CodePath"
  $CodePath
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

function Set-WindowsTerminalProfileOrder {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [AllowEmptyCollection()]
    [object[]] $Profiles
  )

  $profileDefinitions = @(
    [pscustomobject]@{ Role = 'Pwsh7'; Name = 'Pwsh 7' }
    [pscustomobject]@{ Role = 'Pwsh5'; Name = 'Pwsh 5' }
    [pscustomobject]@{ Role = 'CommandPrompt'; Name = 'Command Prompt' }
    [pscustomobject]@{ Role = 'AzureCloudShell'; Name = 'Azure Cloud Shell' }
  )
  $selectedIndexes = [System.Collections.Generic.HashSet[int]]::new()
  $orderedProfiles = [System.Collections.Generic.List[object]]::new()
  $changed = $false

  foreach ($definition in $profileDefinitions) {
    for ($index = 0; $index -lt $Profiles.Count; $index++) {
      if ($selectedIndexes.Contains($index)) {
        continue
      }

      $profile = $Profiles[$index]
      $guid = ([string]$profile.guid).Trim('{}')
      $role = if ([string]$profile.source -eq 'Windows.Terminal.PowershellCore') {
        'Pwsh7'
      } elseif ($guid -ieq '61c54bbd-c2c6-5271-96e7-009a87ff44bf') {
        'Pwsh5'
      } elseif ($guid -ieq '0caa0dad-35be-5f56-a8ff-afceeeaa6101') {
        'CommandPrompt'
      } elseif ([string]$profile.source -eq 'Windows.Terminal.Azure') {
        'AzureCloudShell'
      }

      if ($role -ne $definition.Role) {
        continue
      }

      if ($profile.name -ne $definition.Name) {
        Set-ObjectPropertyValue -InputObject $profile -Name 'name' -Value $definition.Name
        $changed = $true
      }
      if ($index -ne $orderedProfiles.Count) {
        $changed = $true
      }

      [void]$selectedIndexes.Add($index)
      $orderedProfiles.Add($profile)
      break
    }
  }

  for ($index = 0; $index -lt $Profiles.Count; $index++) {
    if (-not $selectedIndexes.Contains($index)) {
      $orderedProfiles.Add($Profiles[$index])
    }
  }

  [pscustomobject]@{
    Profiles = $orderedProfiles.ToArray()
    Changed = $changed
  }
}

function Update-WindowsTerminalFontFace {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [string] $FontFace,

    [int] $FontSize = 9,

    [string] $StartingDirectory = 'C:\Code',

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
    if ($settings.profiles.defaults.startingDirectory -ne $StartingDirectory) {
      Set-ObjectPropertyValue -InputObject $settings.profiles.defaults -Name 'startingDirectory' -Value $StartingDirectory
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
      $profileOrder = Set-WindowsTerminalProfileOrder -Profiles @($settings.profiles.list)
      if ($profileOrder.Changed) {
        $settings.profiles.list = $profileOrder.Profiles
        $changed = $true
      }

      foreach ($terminalProfile in @($settings.profiles.list)) {
        if ($terminalProfile.font -and $terminalProfile.font.face -and $terminalProfile.font.face -ne $FontFace) {
          $terminalProfile.font.face = $FontFace
          $changed = $true
        }
        if ($terminalProfile.font -and $terminalProfile.font.size -and $terminalProfile.font.size -ne $FontSize) {
          $terminalProfile.font.size = $FontSize
          $changed = $true
        }
      }
    }

    if (-not $changed) {
      $statusSuffix = if ($PostInstall) { 'confirmed' } else { 'already configured' }
      $statusType = if ($PostInstall) { 'Success' } else { 'Current' }
      Write-PwshProfileStatus -Stage 'Terminal' -Type $statusType -Message "Font Face: $FontFace $statusSuffix"
      Write-PwshProfileStatus -Stage 'Terminal' -Type $statusType -Message "Font Size: $FontSize $statusSuffix"
      Write-PwshProfileStatus -Stage 'Terminal' -Type $statusType -Message "Starting Directory: $StartingDirectory $statusSuffix"
      Write-PwshProfileStatus -Stage 'Terminal' -Type $statusType -Message "Profile Order: Pwsh 7, Pwsh 5, Command Prompt, Azure Cloud Shell $statusSuffix"
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
    Write-PwshProfileStatus -Stage 'Terminal' -Type Success -Message "Font Face: $FontFace"
    Write-PwshProfileStatus -Stage 'Terminal' -Type Success -Message "Font Size: $FontSize"
    Write-PwshProfileStatus -Stage 'Terminal' -Type Success -Message "Starting Directory: $StartingDirectory"
    Write-PwshProfileStatus -Stage 'Terminal' -Type Success -Message 'Profile Order: Pwsh 7, Pwsh 5, Command Prompt, Azure Cloud Shell'
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

  try {
    $startingDirectory = Initialize-CodeDirectory
  } catch {
    Write-PwshProfileStatus -Stage 'Terminal' -Type Warning -Message "Could not prepare the starting directory: $($_.Exception.Message)"
    return
  }

  if ($FontFiles.Count -eq 0) {
    Write-PwshProfileStatus -Stage 'Terminal' -Type Warning -Message 'No installed font files were found; settings update skipped.'
    return
  }

  $fontFace = Get-NerdFontFaceName -FontFile $FontFiles[0]
  Update-WindowsTerminalFontFace -FontFace $fontFace -StartingDirectory $startingDirectory -PostInstall:$PostInstall -SettingsPaths $SettingsPaths
  Write-Host ''
  Write-PwshProfileStatus -Stage 'VS Code' -Message "Recommended terminal.integrated.fontFamily: $fontFace"
  Write-PwshProfileStatus -Stage 'VS Code' -Message "Recommended editor.fontFamily: '$fontFace', Consolas, 'Courier New', monospace"
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
    [pscustomobject]@{ Id = 'Amazon.AWSCLI'; Scope = 'machine' }
    [pscustomobject]@{ Id = 'FireDaemon.OpenSSL'; Scope = 'machine' }
    [pscustomobject]@{ Id = 'Git.Git'; Scope = 'machine' }
    [pscustomobject]@{ Id = 'GitHub.cli'; Scope = 'machine' }
    [pscustomobject]@{ Id = 'GitHub.Copilot'; Scope = 'machine' }
    [pscustomobject]@{ Id = 'Hashicorp.Terraform'; Scope = 'machine' }
    [pscustomobject]@{ Id = 'Helm.Helm'; Scope = 'machine' }
    [pscustomobject]@{ Id = 'JanDeDobbeleer.OhMyPosh'; Scope = 'user' }
    [pscustomobject]@{ Id = 'jqlang.jq'; Scope = 'machine' }
    [pscustomobject]@{ Id = 'Kubernetes.kubectl'; Scope = 'machine' }
    [pscustomobject]@{ Id = 'Microsoft.AzureCLI'; Scope = 'machine' }
    [pscustomobject]@{ Id = 'Microsoft.Azure.Kubelogin'; Scope = 'machine' }
    [pscustomobject]@{ Id = 'Microsoft.Bicep'; Scope = 'user' }
    [pscustomobject]@{ Id = 'MikeFarah.yq'; Scope = 'machine' }
    [pscustomobject]@{ Id = 'Ookla.Speedtest.CLI'; Scope = 'machine' }
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

function Get-LatestWingetRelease {
  [CmdletBinding()]
  param ()

  Invoke-RestMethod -Uri 'https://api.github.com/repos/microsoft/winget-cli/releases/latest' -ErrorAction Stop
}

function Update-WingetClient {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [string] $WingetPath
  )

  try {
    $currentVersionText = (& $WingetPath --version 2>$null | Select-Object -First 1)
    if (-not $currentVersionText) {
      Write-PwshProfileStatus -Stage 'Winget' -Type Warning -Message 'Could not determine the installed winget version; skipping self-update.'
      return
    }
    $currentVersion = [version]($currentVersionText.Trim().TrimStart('v'))

    $release = Invoke-WithRetry -Stage 'Winget' -Description 'Check latest winget release' -ScriptBlock {
      Get-LatestWingetRelease
    }
    $latestVersion = [version]($release.tag_name.TrimStart('v'))

    if ($currentVersion -ge $latestVersion) {
      Write-PwshProfileStatus -Stage 'Winget' -Type Current -Message "Version: $currentVersion [latest]"
      return
    }

    Write-PwshProfileStatus -Stage 'Winget' -Type Action -Message "Version: $currentVersion, updating to $latestVersion..."

    $bundleAsset = $release.assets | Where-Object { $_.name -like '*.msixbundle' } | Select-Object -First 1
    if (-not $bundleAsset) {
      Write-PwshProfileStatus -Stage 'Winget' -Type Warning -Message 'Latest winget release has no msixbundle asset; skipping self-update.'
      return
    }

    $tempRoot = Join-Path $env:TEMP "winget-update-$([guid]::NewGuid())"
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    try {
      $bundlePath = Join-Path $tempRoot $bundleAsset.name
      Invoke-WithRetry -Stage 'Winget' -Description 'Download winget package' -ScriptBlock {
        Invoke-WebRequest -Uri $bundleAsset.browser_download_url -OutFile $bundlePath -UseBasicParsing -ErrorAction Stop
      }

      Add-AppxPackage -Path $bundlePath -ForceApplicationShutdown -ErrorAction Stop
      Write-PwshProfileStatus -Stage 'Winget' -Type Success -Message "winget updated to $latestVersion."
    } finally {
      Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
  } catch {
    Write-PwshProfileStatus -Stage 'Winget' -Type Warning -Message "winget self-update failed: $($_.Exception.Message)"
  }
}

function Update-WingetSources {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [string] $WingetPath
  )

  Write-Host ''
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

function ConvertFrom-WingetTableRow {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [string[]] $Lines,

    [Parameter(Mandatory)]
    [string] $PackageId
  )

  $headerIndex = -1
  for ($i = 0; $i -lt $Lines.Count; $i++) {
    if ($Lines[$i] -match '^\s*Name\s+Id\s+Version') {
      $headerIndex = $i
      break
    }
  }
  if ($headerIndex -lt 0 -or $headerIndex + 2 -ge $Lines.Count) {
    return $null
  }

  $header = $Lines[$headerIndex]
  $columnStarts = [ordered]@{}
  foreach ($column in @('Name', 'Id', 'Version', 'Available', 'Source')) {
    $match = [regex]::Match($header, "\b$column\b")
    if ($match.Success) {
      $columnStarts[$column] = $match.Index
    }
  }

  $dataRow = $Lines[($headerIndex + 2)..($Lines.Count - 1)] | Where-Object { $_ -match [regex]::Escape($PackageId) } | Select-Object -First 1
  if (-not $dataRow) {
    return $null
  }

  $columns = @($columnStarts.Keys)
  $result = [ordered]@{}
  for ($i = 0; $i -lt $columns.Count; $i++) {
    $start = $columnStarts[$columns[$i]]
    if ($start -ge $dataRow.Length) {
      continue
    }
    $end = if ($i -lt $columns.Count - 1) { $columnStarts[$columns[$i + 1]] } else { $dataRow.Length }
    $length = [Math]::Min($end, $dataRow.Length) - $start
    $result[$columns[$i]] = $dataRow.Substring($start, $length).Trim()
  }

  [pscustomobject]$result
}

function Get-WingetPackageVersionInfo {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [string] $PackageId,

    [Parameter(Mandatory)]
    [string] $WingetPath,

    [Parameter(Mandatory)]
    [ValidateSet('list', 'upgrade')]
    [string] $Command
  )

  try {
    $output = & $WingetPath $Command --id $PackageId --exact --source winget --accept-source-agreements --disable-interactivity 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $output) {
      return $null
    }

    # Winget emits ANSI colour codes even when output is redirected; strip them before column parsing.
    $ansiEscapePattern = '{0}\[[0-9;]*[a-zA-Z]' -f [char]27
    $plainLines = $output | ForEach-Object { $_ -replace $ansiEscapePattern, '' }
    ConvertFrom-WingetTableRow -Lines $plainLines -PackageId $PackageId
  } catch {
    $null
  }
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
  param ()

  Write-PwshProfileHeader -Title 'Pwsh Profile Installer' -Subtitle 'Winget Package Configuration'

  $wingetPath = Get-WingetCommand
  Update-WingetClient -WingetPath $wingetPath
  $wingetPath = Get-WingetCommand
  Update-WingetSources -WingetPath $wingetPath

  $packages = @(Get-WingetPackageDefinitions)
  Show-WingetPackageInventory -Packages $packages
  Write-PwshProfileStatus -Stage 'Winget' -Message "Checking $($packages.Count) package(s)..."

  $packageStates = @(
    foreach ($package in $packages) {
      [pscustomobject]@{
        Package = $package
        InstalledInfo = Get-WingetPackageVersionInfo -PackageId $package.Id -WingetPath $wingetPath -Command list
      }
    }
  )

  $summary = [ordered]@{
    Updated = 0
    Current = 0
    Failed = 0
  }

  foreach ($state in $packageStates) {
    try {
      if ($state.InstalledInfo) {
        $installedVersion = if ($state.InstalledInfo.Version) { $state.InstalledInfo.Version } else { 'unknown version' }
        $upgradeInfo = Get-WingetPackageVersionInfo -PackageId $state.Package.Id -WingetPath $wingetPath -Command upgrade

        if ($upgradeInfo) {
          $latestVersion = if ($upgradeInfo -and $upgradeInfo.Available) { $upgradeInfo.Available } else { 'a newer version' }
          Write-PwshProfileStatus -Stage 'Winget' -Type Action -Message "$($state.Package.Id) installed $installedVersion, updating to $latestVersion [$($state.Package.Scope)]"
          Invoke-WingetPackageAction -Package $state.Package -WingetPath $wingetPath -Action upgrade
          $summary.Updated++
        } else {
          Write-PwshProfileStatus -Stage 'Winget' -Type Current -Message "$($state.Package.Id) installed $installedVersion [latest] [$($state.Package.Scope)]"
          $summary.Current++
        }
      } else {
        Invoke-WingetPackageAction -Package $state.Package -WingetPath $wingetPath -Action install
        $summary.Updated++
      }
    } catch {
      Write-PwshProfileStatus -Stage 'Winget' -Type Warning -Message "$($state.Package.Id) failed: $($_.Exception.Message)"
      $summary.Failed++
    }
  }

  Write-Host ''
  $summaryType = if ($summary.Failed -gt 0) { 'Warning' } elseif ($summary.Updated -gt 0) { 'Success' } else { 'Current' }
  Write-PwshProfileStatus -Stage 'Winget' -Type $summaryType -Message "Summary: $($summary.Updated) updated, $($summary.Current) current, $($summary.Failed) failed."
}

function Get-PowerShellModuleDefinitions {
  [CmdletBinding()]
  param ()

  @(
    [pscustomobject]@{ Name = 'Az'; Scope = 'CurrentUser' }
    [pscustomobject]@{ Name = 'Microsoft.Graph'; Scope = 'CurrentUser' }
    [pscustomobject]@{ Name = 'PackageManagement'; Scope = 'CurrentUser' }
    [pscustomobject]@{ Name = 'Pester'; Scope = 'CurrentUser' }
    [pscustomobject]@{ Name = 'PowerShellGet'; Scope = 'CurrentUser' }
    [pscustomobject]@{ Name = 'PSReadLine'; Scope = 'CurrentUser' }
    [pscustomobject]@{ Name = 'PSRule'; Scope = 'CurrentUser' }
    [pscustomobject]@{ Name = 'PSRule.Rules.Azure'; Scope = 'CurrentUser' }
    [pscustomobject]@{ Name = 'Terminal-Icons'; Scope = 'CurrentUser' }
  )
}

function Initialize-PowerShellGallery {
  [CmdletBinding()]
  param ()

  if (-not (Get-Command Install-Module -ErrorAction SilentlyContinue)) {
    throw 'Install-Module was not found. Install PowerShellGet, then rerun this script.'
  }

  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

  Write-PwshProfileStatus -Stage 'Modules' -Message 'Checking NuGet package provider...'
  $nugetProvider = Get-PackageProvider -ListAvailable -Name NuGet -ErrorAction SilentlyContinue |
    Sort-Object Version -Descending |
    Select-Object -First 1

  if (-not $nugetProvider -or $nugetProvider.Version -lt [version]'2.8.5.201') {
    Write-PwshProfileStatus -Stage 'Modules' -Type Action -Message 'Installing NuGet package provider 2.8.5.201...'
    Invoke-WithRetry -Description 'Install NuGet provider' -ScriptBlock {
      Install-PackageProvider -Name NuGet -MinimumVersion '2.8.5.201' -Force -Scope CurrentUser -WarningAction SilentlyContinue -ErrorAction Stop | Out-Null
    }
    Write-PwshProfileStatus -Stage 'Modules' -Type Success -Message 'NuGet package provider installed.'
  } else {
    Write-PwshProfileStatus -Stage 'Modules' -Type Current -Message "NuGet package provider $($nugetProvider.Version)."
  }

  Import-PackageProvider -Name NuGet -Force -ErrorAction Stop | Out-Null

  $repository = Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue
  if (-not $repository) {
    throw 'PSGallery repository was not found. Register PSGallery, then rerun this script.'
  }

  if ($repository.InstallationPolicy -ne 'Trusted') {
    Write-PwshProfileStatus -Stage 'Modules' -Type Action -Message 'Trusting PSGallery repository...'
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -WarningAction SilentlyContinue
    Write-PwshProfileStatus -Stage 'Modules' -Type Success -Message 'PSGallery trusted.'
  } else {
    Write-PwshProfileStatus -Stage 'Modules' -Type Current -Message 'PSGallery already trusted.'
  }
}

function Invoke-WithRetry {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [scriptblock] $ScriptBlock,

    [Parameter(Mandatory)]
    [string] $Description,

    [ValidateSet('Modules', 'Winget')]
    [string] $Stage = 'Modules',

    [int] $MaxAttempts = 3,

    [int] $DelaySeconds = 5
  )

  for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
    try {
      return & $ScriptBlock
    } catch {
      if ($attempt -eq $MaxAttempts) {
        throw "'$Description' failed after $MaxAttempts attempts. $($_.Exception.Message)"
      }
      Write-PwshProfileStatus -Stage $Stage -Type Warning -Message "$Description failed ($attempt/$MaxAttempts); retrying in ${DelaySeconds}s..."
      Start-Sleep -Seconds $DelaySeconds
    }
  }
}

function Get-PowerShellModuleRoot {
  [CmdletBinding()]
  param ()

  $documentsPath = [Environment]::GetFolderPath('MyDocuments')
  $subfolder = if ($PSVersionTable.PSEdition -eq 'Core') { 'PowerShell' } else { 'WindowsPowerShell' }
  Join-Path $documentsPath "$subfolder\Modules"
}

function Get-InstalledPowerShellModules {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [string] $Name
  )

  $moduleRoot = Join-Path (Get-PowerShellModuleRoot) $Name
  if (-not (Test-Path -LiteralPath $moduleRoot)) {
    return
  }

  Get-ChildItem -LiteralPath $moduleRoot -Directory -ErrorAction SilentlyContinue |
    ForEach-Object {
    $version = $null
    if ([version]::TryParse($_.Name, [ref] $version)) {
      [pscustomobject]@{
        Name = $Name
        Version = $version
        ModuleBase = $_.FullName
      }
    }
  } |
    Sort-Object Version -Descending
}

function Remove-OldPowerShellModuleVersions {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [string] $Name
  )

  $oldModules = @(Get-InstalledPowerShellModules -Name $Name | Select-Object -Skip 1)
  foreach ($oldModule in $oldModules) {
    try {
      Write-PwshProfileStatus -Stage 'Modules' -Type Action -Message "Removing $Name $($oldModule.Version)"
      Remove-Module -FullyQualifiedName @{ ModuleName = $Name; ModuleVersion = $oldModule.Version } -Force -ErrorAction SilentlyContinue
      Remove-Item -LiteralPath $oldModule.ModuleBase -Recurse -Force -ErrorAction Stop
      Write-PwshProfileStatus -Stage 'Modules' -Type Success -Message "Removed $Name $($oldModule.Version)."
    } catch {
      Write-PwshProfileStatus -Stage 'Modules' -Type Warning -Message "Could not remove $Name $($oldModule.Version); it may be in use."
    }
  }
}

function Get-PowerShellModuleInstallState {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [string] $RegistryPath,

    [Parameter(Mandatory)]
    [string] $Name
  )

  if (-not (Test-Path -LiteralPath $RegistryPath)) {
    return $null
  }

  $registryState = Get-ItemProperty -LiteralPath $RegistryPath -ErrorAction SilentlyContinue
  if (-not $registryState -or -not $registryState.PSObject.Properties[$Name]) {
    return $null
  }

  try {
    [version]$registryState.PSObject.Properties[$Name].Value
  } catch {
    $null
  }
}

function Set-PowerShellModuleInstallState {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [string] $RegistryPath,

    [Parameter(Mandatory)]
    [string] $Name,

    [Parameter(Mandatory)]
    [version] $Version
  )

  if (-not (Test-Path -LiteralPath $RegistryPath)) {
    New-Item -Path $RegistryPath -Force | Out-Null
  }

  New-ItemProperty -LiteralPath $RegistryPath -Name $Name -Value $Version.ToString() -PropertyType String -Force | Out-Null
}

function Invoke-PowerShellModuleAction {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [object] $Module,

    [Parameter(Mandatory)]
    [string] $StateRegistryPath
  )

  try {
    # PackageManagement/PowerShellGet/PSReadLine are bootstrap modules PowerShellGet handles
    # specially, and can end up saved somewhere our disk scan never finds even with an explicit
    # -Path. Track our own record of the last version we successfully saved (like the Nerd Font
    # registry state) so detection doesn't depend solely on locating the files afterward.
    $isBootstrapModule = $Module.Name -in @('PackageManagement', 'PowerShellGet', 'PSReadLine')
    $diskModule = Get-InstalledPowerShellModules -Name $Module.Name | Select-Object -First 1
    $trackedVersion = if ($isBootstrapModule) {
      Get-PowerShellModuleInstallState -RegistryPath $StateRegistryPath -Name $Module.Name
    }
    $installedVersion = @($diskModule.Version, $trackedVersion) |
      Where-Object { $_ } |
      Sort-Object -Descending |
      Select-Object -First 1

    $galleryVersion = Invoke-WithRetry -Description "Find-Module $($Module.Name)" -ScriptBlock {
      (Find-Module -Name $Module.Name -Repository PSGallery -ErrorAction Stop).Version
    }
    $latestVersion = [version]$galleryVersion

    if ($installedVersion -and $installedVersion -ge $latestVersion) {
      Write-PwshProfileStatus -Stage 'Modules' -Type Current -Message "$($Module.Name) installed $installedVersion [latest] [$($Module.Scope)]"
      return 'Current'
    }

    if ($installedVersion) {
      Write-PwshProfileStatus -Stage 'Modules' -Type Action -Message "$($Module.Name) installed $installedVersion, updating to $latestVersion [$($Module.Scope)]"
    } else {
      Write-PwshProfileStatus -Stage 'Modules' -Type Action -Message "$($Module.Name) not installed, installing $latestVersion [$($Module.Scope)]"
    }

    # Save-Module always downloads into the exact path we give it. Install-Module was unreliable
    # here because it can decide an inbox/AllUsers copy (or an MSIX-packaged PowerShell's own
    # Modules folder) already "satisfies" the request and silently skip writing anywhere we'd
    # actually detect on the next run.
    $moduleRoot = Get-PowerShellModuleRoot
    if (-not (Test-Path -LiteralPath $moduleRoot)) {
      New-Item -ItemType Directory -Path $moduleRoot -Force -ErrorAction Stop | Out-Null
    }

    $previousProgressPreference = $ProgressPreference
    try {
      $ProgressPreference = 'SilentlyContinue'
      Invoke-WithRetry -Description "Save-Module $($Module.Name)" -ScriptBlock {
        Save-Module -Name $Module.Name -RequiredVersion $latestVersion -Repository PSGallery -Path $moduleRoot -Force -ErrorAction Stop
      } | Out-Null
    } finally {
      $ProgressPreference = $previousProgressPreference
    }

    if ($isBootstrapModule) {
      Set-PowerShellModuleInstallState -RegistryPath $StateRegistryPath -Name $Module.Name -Version $latestVersion
    }
    Remove-OldPowerShellModuleVersions -Name $Module.Name
    Write-PwshProfileStatus -Stage 'Modules' -Type Success -Message "$($Module.Name) ready at $latestVersion [$($Module.Scope)]"
    return 'Updated'
  } catch {
    Write-PwshProfileStatus -Stage 'Modules' -Type Warning -Message "$($Module.Name) failed: $($_.Exception.Message)"
    return 'Failed'
  }
}

function Show-PowerShellModuleInventory {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [object[]] $Modules
  )

  Write-Host ''
  $Modules |
    Format-Table -Property `
    @{ Label = 'Module'; Expression = { $_.Name } },
  @{ Label = 'Scope'; Expression = { $_.Scope } } `
    -AutoSize |
    Out-String -Width 120 |
    ForEach-Object { $_ -split '\r?\n' } |
    ForEach-Object { $_.TrimEnd() } |
    Where-Object { $_ } |
    ForEach-Object { Write-PwshProfileStatus -Stage 'Modules' -Message $_ }
  Write-Host ''
}

function Get-GitHubRawFileContent {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [uri] $RawUri
  )

  try {
    $response = Invoke-WebRequest -Uri $RawUri -UseBasicParsing -ErrorAction Stop
  } catch {
    throw "Unable to download '$RawUri'. $($_.Exception.Message)"
  }

  $lastModified = $null
  $lastModifiedHeader = @($response.Headers['Last-Modified']) | Select-Object -First 1
  if ($lastModifiedHeader) {
    try {
      $lastModified = [datetimeoffset]::Parse($lastModifiedHeader)
    } catch {
      $lastModified = $null
    }
  }

  [pscustomobject]@{
    Content = $response.Content
    LastModified = $lastModified
  }
}

function Get-StringSHA256 {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [AllowEmptyString()]
    [string] $Value
  )

  $sha256 = [System.Security.Cryptography.SHA256]::Create()
  try {
    $hashBytes = $sha256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Value))
    -join ($hashBytes | ForEach-Object { $_.ToString('x2') })
  } finally {
    $sha256.Dispose()
  }
}

function Install-PwshProfileConfiguration {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [uri] $RawUri
  )

  Write-PwshProfileHeader -Title 'Pwsh Profile Installer' -Subtitle 'PowerShell Profile Configuration'

  try {
    $remoteFile = Get-GitHubRawFileContent -RawUri $RawUri
  } catch {
    Write-PwshProfileStatus -Stage 'Profile' -Type Warning -Message "Could not check GitHub for the latest profile: $($_.Exception.Message)"
    return
  }

  $supportPaths = Get-CrossPlatformSupportPaths
  $profilePath = Join-Path $supportPaths.SourceRoot 'Microsoft.PowerShell_profile.ps1'
  Write-PwshProfileStatus -Stage 'Profile' -Message "Target: $profilePath"

  if (Test-Path -LiteralPath $profilePath -PathType Leaf) {
    try {
      $existingContent = Get-Content -LiteralPath $profilePath -Raw -ErrorAction Stop
    } catch {
      Write-PwshProfileStatus -Stage 'Profile' -Type Warning -Message "Could not read the existing profile; leaving it as-is. $($_.Exception.Message)"
      return
    }

    if ($existingContent -eq $remoteFile.Content) {
      Write-PwshProfileStatus -Stage 'Profile' -Type Current -Message 'Already up to date.'
      return
    }

    $localLastWriteTime = (Get-Item -LiteralPath $profilePath).LastWriteTimeUtc
    if ($remoteFile.LastModified -and $remoteFile.LastModified.UtcDateTime -le $localLastWriteTime) {
      Write-PwshProfileStatus -Stage 'Profile' -Type Current -Message 'Local profile is newer than the GitHub version; leaving it as-is.'
      return
    }

    Write-PwshProfileStatus -Stage 'Profile' -Type Warning -Message 'A newer PowerShell profile is available on GitHub and would overwrite your local copy.'
    $confirmation = Read-Host -Prompt "Overwrite '$profilePath'? A backup will be created first. (y/N)"
    if ($confirmation -notmatch '(?i)^y(es)?$') {
      Write-PwshProfileStatus -Stage 'Profile' -Type Warning -Message 'Skipped: user declined to overwrite the existing profile.'
      return
    }

    $backupTimestamp = [DateTimeOffset]::UtcNow.ToString('yyyyMMddHHmmss')
    $backupPath = "$profilePath.$backupTimestamp.bak"
    Copy-Item -LiteralPath $profilePath -Destination $backupPath -Force
    Write-PwshProfileStatus -Stage 'Profile' -Type Success -Message "Backup: $backupPath"
  }
  else {
    $profileDirectory = Split-Path -Path $profilePath -Parent
    if (-not (Test-Path -LiteralPath $profileDirectory)) {
      New-Item -ItemType Directory -Path $profileDirectory -Force | Out-Null
    }
  }

  [System.IO.File]::WriteAllText(
    [System.IO.Path]::GetFullPath($profilePath),
    $remoteFile.Content,
    [System.Text.UTF8Encoding]::new($false)
  )
  if ($remoteFile.LastModified) {
    (Get-Item -LiteralPath $profilePath).LastWriteTimeUtc = $remoteFile.LastModified.UtcDateTime
  }
  Write-PwshProfileStatus -Stage 'Profile' -Type Success -Message "Installed: $profilePath"
}

function Get-PwshProfileLocalStorePaths {
  [CmdletBinding()]
  param ()

  $root = Join-Path $env:APPDATA 'PwshProfile'
  [pscustomobject]@{
    Root = $root
    Themes = Join-Path $root 'themes'
    Functions = Join-Path $root 'functions'
    Config = Join-Path $root 'config'
    VersionFile = Join-Path $root 'version.json'
  }
}

function Install-PwshProfileLocalStore {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [uri] $ThemeRawUri
  )

  Write-PwshProfileHeader -Title 'Pwsh Profile Installer' -Subtitle 'Local Profile Store (OTA Update Baseline)'

  $paths = Get-PwshProfileLocalStorePaths
  foreach ($folder in @($paths.Root, $paths.Themes, $paths.Functions, $paths.Config)) {
    if (Test-Path -LiteralPath $folder -PathType Container) {
      continue
    }
    New-Item -ItemType Directory -Path $folder -Force -ErrorAction Stop | Out-Null
    Write-PwshProfileStatus -Stage 'Store' -Type Success -Message "Created: $folder"
  }

  try {
    $remoteFile = Get-GitHubRawFileContent -RawUri $ThemeRawUri
  } catch {
    Write-PwshProfileStatus -Stage 'Store' -Type Warning -Message "Could not check GitHub for the latest theme: $($_.Exception.Message)"
    return
  }

  $themeFileName = Split-Path -Path $ThemeRawUri.AbsolutePath -Leaf
  $themeDestination = Join-Path $paths.Themes $themeFileName
  $remoteHash = Get-StringSHA256 -Value $remoteFile.Content
  $themeIsCurrent = $false

  if (Test-Path -LiteralPath $themeDestination -PathType Leaf) {
    $localHash = (Get-FileHash -LiteralPath $themeDestination -Algorithm SHA256).Hash
    if ($localHash -ieq $remoteHash) {
      Write-PwshProfileStatus -Stage 'Store' -Type Current -Message "Theme already up to date: $themeDestination"
      $themeIsCurrent = $true
    }
  }

  if (-not $themeIsCurrent) {
    [System.IO.File]::WriteAllText(
      [System.IO.Path]::GetFullPath($themeDestination),
      $remoteFile.Content,
      [System.Text.UTF8Encoding]::new($false)
    )
    if ($remoteFile.LastModified) {
      (Get-Item -LiteralPath $themeDestination).LastWriteTimeUtc = $remoteFile.LastModified.UtcDateTime
    }
    Write-PwshProfileStatus -Stage 'Store' -Type Success -Message "Theme: $themeDestination"
  }

  $version = [ordered]@{
    schemaVersion = 1
    updatedAt = [DateTimeOffset]::UtcNow.ToString('o')
    theme = [ordered]@{
      name = [System.IO.Path]::GetFileNameWithoutExtension($themeFileName)
      file = $themeFileName
      sha256 = $remoteHash
      sourceLastModified = if ($remoteFile.LastModified) { $remoteFile.LastModified.ToString('o') } else { $null }
    }
  }

  $versionJson = $version | ConvertTo-Json -Depth 5
  $manifestIsCurrent = $false
  if (Test-Path -LiteralPath $paths.VersionFile -PathType Leaf) {
    try {
      $existingVersion = Get-Content -LiteralPath $paths.VersionFile -Raw -ErrorAction Stop |
        ConvertFrom-Json -ErrorAction Stop
      $manifestIsCurrent = $existingVersion.schemaVersion -eq 1 -and
      $existingVersion.theme.file -eq $themeFileName -and
      $existingVersion.theme.sha256 -ieq $remoteHash
    } catch {
      $manifestIsCurrent = $false
    }
  }
  if (-not $themeIsCurrent -or -not $manifestIsCurrent) {
    [System.IO.File]::WriteAllText(
      [System.IO.Path]::GetFullPath($paths.VersionFile),
      "$versionJson`n",
      [System.Text.UTF8Encoding]::new($false)
    )
    Write-PwshProfileStatus -Stage 'Store' -Type Success -Message "Version manifest: $($paths.VersionFile)"
  }
}

function Invoke-GitHubConfiguration {
  [CmdletBinding()]
  param ()

  Write-PwshProfileHeader -Title 'Pwsh Profile Installer' -Subtitle 'Pwsh: GitHub Configuration'

  $git = Get-Command git -ErrorAction SilentlyContinue
  if (-not $git) {
    Write-PwshProfileStatus -Stage 'GitHub' -Type Warning -Message 'Git was not found; global commit identity could not be configured.'
  } else {
    $gitUserName = ((& $git.Source config --global --get user.name 2>$null) | Out-String).Trim()
    $gitUserEmail = ((& $git.Source config --global --get user.email 2>$null) | Out-String).Trim()

    if (-not $gitUserName) {
      Write-PwshProfileStatus -Stage 'GitHub' -Message 'Git uses your first and last name to identify commits.'
      $firstName = (Read-Host -Prompt 'Git first name').Trim()
      $lastName = (Read-Host -Prompt 'Git last name').Trim()
      $gitUserName = "$firstName $lastName".Trim()
      if ($firstName -and $lastName) {
        & $git.Source config --global user.name $gitUserName
        if ($LASTEXITCODE -eq 0) {
          Write-PwshProfileStatus -Stage 'GitHub' -Type Success -Message "Git user.name configured: $gitUserName"
        } else {
          Write-PwshProfileStatus -Stage 'GitHub' -Type Warning -Message 'Git user.name could not be configured.'
        }
      } else {
        Write-PwshProfileStatus -Stage 'GitHub' -Type Warning -Message 'Git user.name skipped; both first and last name are required.'
      }
    } else {
      Write-PwshProfileStatus -Stage 'GitHub' -Type Current -Message "Git user.name: $gitUserName"
    }

    if (-not $gitUserEmail) {
      Write-PwshProfileStatus -Stage 'GitHub' -Message 'Use an email associated with GitHub, or your GitHub no-reply email, for commit attribution.'
      $gitUserEmail = (Read-Host -Prompt 'GitHub email').Trim()
      if ($gitUserEmail -match '^[^\s@]+@[^\s@]+\.[^\s@]+$') {
        & $git.Source config --global user.email $gitUserEmail
        if ($LASTEXITCODE -eq 0) {
          Write-PwshProfileStatus -Stage 'GitHub' -Type Success -Message "Git user.email configured: $gitUserEmail"
        } else {
          Write-PwshProfileStatus -Stage 'GitHub' -Type Warning -Message 'Git user.email could not be configured.'
        }
      } else {
        Write-PwshProfileStatus -Stage 'GitHub' -Type Warning -Message 'Git user.email skipped; enter a valid email address when the installer is run again.'
      }
    } else {
      Write-PwshProfileStatus -Stage 'GitHub' -Type Current -Message "Git user.email: $gitUserEmail"
    }
  }

  Write-Host ''
  Write-PwshProfileStatus -Stage 'GitHub' -Message 'Git name/email control commit attribution; they do not sign in to GitHub.'
  Write-PwshProfileStatus -Stage 'GitHub' -Type Action -Message "GitHub CLI sign-in (if needed): gh auth login"
  Write-PwshProfileStatus -Stage 'Copilot' -Type Action -Message "Authenticate the prompt usage segment: oh-my-posh auth copilot"
  Write-PwshProfileStatus -Stage 'Copilot' -Message 'Oh My Posh opens GitHub device login and securely stores the token for future prompt usage checks.'
}

function Invoke-PowerShellModuleConfiguration {
  [CmdletBinding()]
  param ()

  Write-PwshProfileHeader -Title 'Pwsh Profile Installer' -Subtitle 'PowerShell Module Configuration'

  $moduleStateRegistryPath = 'HKCU:\Software\smoonlee\OhMyPoshProfile\Modules'
  Initialize-PowerShellGallery
  $modules = @(Get-PowerShellModuleDefinitions)
  Show-PowerShellModuleInventory -Modules $modules
  Write-PwshProfileStatus -Stage 'Modules' -Message "Checking $($modules.Count) module(s)..."

  $summary = [ordered]@{
    Updated = 0
    Current = 0
    Failed = 0
  }

  foreach ($module in $modules) {
    $result = Invoke-PowerShellModuleAction -Module $module -StateRegistryPath $moduleStateRegistryPath
    if ($summary.Contains($result)) {
      $summary[$result]++
    }
  }

  Write-Host ''
  $summaryType = if ($summary.Failed -gt 0) { 'Warning' } elseif ($summary.Updated -gt 0) { 'Success' } else { 'Current' }
  Write-PwshProfileStatus -Stage 'Modules' -Type $summaryType -Message "Summary: $($summary.Updated) updated, $($summary.Current) current, $($summary.Failed) failed."

  Install-PwshProfileConfiguration -RawUri 'https://raw.githubusercontent.com/smoonlee/oh-my-posh-profile-dev/main/src/profile/Microsoft.PowerShell_profile.ps1'
  Install-PwshProfileLocalStore -ThemeRawUri 'https://raw.githubusercontent.com/smoonlee/oh-my-posh-profile-dev/main/src/themes/quick-term-cloud.omp.json'
  Invoke-CrossPlatformProfileConfiguration
  Invoke-GitHubConfiguration
}

function Get-CrossPlatformSupportPaths {
  [CmdletBinding()]
  param ()

  $documentsPath = [Environment]::GetFolderPath('MyDocuments')
  $pwsh7Root = Join-Path $documentsPath 'PowerShell'
  $pwsh5Root = Join-Path $documentsPath 'WindowsPowerShell'
  $isPwsh7 = $PSVersionTable.PSVersion.Major -ge 6

  # The host that launched the installer is the source of truth; the other version is linked to it.
  [pscustomobject]@{
    SourceRoot = if ($isPwsh7) { $pwsh7Root } else { $pwsh5Root }
    TargetRoot = if ($isPwsh7) { $pwsh5Root } else { $pwsh7Root }
    SourceLabel = if ($isPwsh7) { 'PowerShell 7' } else { 'PowerShell 5.1' }
    TargetLabel = if ($isPwsh7) { 'PowerShell 5.1' } else { 'PowerShell 7' }
    Pwsh7Root = $pwsh7Root
  }
}

function Set-PwshSymbolicLink {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [string] $Path,

    [Parameter(Mandatory)]
    [string] $Target,

    [ValidateSet('Directory', 'File')]
    [string] $ItemType = 'Directory'
  )

  try {
    if (-not (Test-Path -LiteralPath $Target)) {
      $targetParent = Split-Path -Path $Target -Parent
      if ($targetParent -and -not (Test-Path -LiteralPath $targetParent)) {
        New-Item -ItemType Directory -Path $targetParent -Force -ErrorAction Stop | Out-Null
      }
      New-Item -ItemType $ItemType -Path $Target -Force -ErrorAction Stop | Out-Null
      Write-PwshProfileStatus -Stage 'Profile' -Type Action -Message "Created missing target '$Target'."
    }

    $existingItem = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    if ($existingItem) {
      if ($existingItem.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        $existingTarget = @($existingItem.Target) | Select-Object -First 1
        if ($existingTarget -and $existingTarget.TrimEnd('\') -ieq $Target.TrimEnd('\')) {
          Write-PwshProfileStatus -Stage 'Profile' -Type Current -Message "'$Path' already linked to '$Target'."
          return
        }
        Remove-Item -LiteralPath $Path -Force -ErrorAction Stop
      } elseif ($existingItem.PSIsContainer) {
        if (@(Get-ChildItem -LiteralPath $Path -Force -ErrorAction SilentlyContinue).Count -gt 0) {
          Write-PwshProfileStatus -Stage 'Profile' -Type Warning -Message "'$Path' has existing content; move it into '$Target' and rerun to link safely."
          return
        }
        Remove-Item -LiteralPath $Path -Force -ErrorAction Stop
      } else {
        Remove-Item -LiteralPath $Path -Force -ErrorAction Stop
      }
    }

    $pathParent = Split-Path -Path $Path -Parent
    if ($pathParent -and -not (Test-Path -LiteralPath $pathParent)) {
      New-Item -ItemType Directory -Path $pathParent -Force -ErrorAction Stop | Out-Null
    }

    New-Item -ItemType SymbolicLink -Path $Path -Target $Target -Force -ErrorAction Stop | Out-Null
    Write-PwshProfileStatus -Stage 'Profile' -Type Success -Message "Linked '$Path' -> '$Target'."
  } catch {
    Write-PwshProfileStatus -Stage 'Profile' -Type Warning -Message "Failed to link '$Path' -> '$Target': $($_.Exception.Message) (creating symbolic links requires Administrator or Developer Mode)."
  }
}

function Set-PwshExecutionPolicy {
  [CmdletBinding()]
  param ()

  try {
    $currentPolicy = Get-ExecutionPolicy -Scope CurrentUser
    if ($currentPolicy -in @('RemoteSigned', 'Unrestricted', 'Bypass')) {
      Write-PwshProfileStatus -Stage 'Profile' -Type Current -Message "Execution policy already $currentPolicy for $($PSVersionTable.PSEdition) [CurrentUser]."
    } else {
      Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force -ErrorAction Stop
      Write-PwshProfileStatus -Stage 'Profile' -Type Success -Message "Execution policy set to RemoteSigned for $($PSVersionTable.PSEdition) [CurrentUser]."
    }
  } catch {
    Write-PwshProfileStatus -Stage 'Profile' -Type Warning -Message "Could not set execution policy for $($PSVersionTable.PSEdition): $($_.Exception.Message)"
  }

  # A linked profile is useless to the *other* PowerShell version if its execution policy still blocks scripts,
  # so set RemoteSigned there too by shelling out to that version's own executable.
  $otherExecutable = if ($PSVersionTable.PSEdition -eq 'Core') {
    Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
  } else {
    (Get-Command pwsh -ErrorAction SilentlyContinue).Source
  }

  if (-not $otherExecutable -or -not (Test-Path -LiteralPath $otherExecutable)) {
    return
  }

  try {
    $otherExecutableName = Split-Path -Path $otherExecutable -Leaf
    $otherPolicyOutput = & $otherExecutable -NoProfile -Command 'Get-ExecutionPolicy -Scope CurrentUser' 2>$null
    $otherPolicyExitCode = $LASTEXITCODE
    $otherPolicy = @($otherPolicyOutput) | Select-Object -First 1
    if ($otherPolicyExitCode -ne 0 -or -not $otherPolicy) {
      Write-PwshProfileStatus -Stage 'Profile' -Type Warning -Message "Could not read execution policy via $otherExecutableName (exit $otherPolicyExitCode)."
      return
    }

    if ([string]$otherPolicy -in @('RemoteSigned', 'Unrestricted', 'Bypass')) {
      Write-PwshProfileStatus -Stage 'Profile' -Type Current -Message "Execution policy already $otherPolicy for $otherExecutableName [CurrentUser]."
      return
    }

    & $otherExecutable -NoProfile -Command 'Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force' 2>$null
    if ($LASTEXITCODE -eq 0) {
      Write-PwshProfileStatus -Stage 'Profile' -Type Success -Message "Execution policy set to RemoteSigned for $otherExecutableName [CurrentUser]."
    } else {
      Write-PwshProfileStatus -Stage 'Profile' -Type Warning -Message "Could not set execution policy via $otherExecutableName (exit $LASTEXITCODE)."
    }
  } catch {
    Write-PwshProfileStatus -Stage 'Profile' -Type Warning -Message "Could not set execution policy via '$otherExecutable': $($_.Exception.Message)"
  }
}

function Invoke-CrossPlatformProfileConfiguration {
  [CmdletBinding()]
  param ()

  Write-PwshProfileHeader -Title 'Pwsh Profile Installer' -Subtitle 'Cross-Platform Module & Profile Support'

  Set-PwshExecutionPolicy

  try {
    $paths = Get-CrossPlatformSupportPaths
    Write-Host ''
    Write-PwshProfileStatus -Stage 'Profile' -Message "Running $($paths.SourceLabel); linking $($paths.TargetLabel) to match."

    if (-not (Test-Path -LiteralPath $paths.SourceRoot)) {
      New-Item -ItemType Directory -Path $paths.SourceRoot -Force -ErrorAction Stop | Out-Null
    }

    Set-PwshSymbolicLink -ItemType Directory `
      -Path (Join-Path $paths.TargetRoot 'Modules') `
      -Target (Join-Path $paths.SourceRoot 'Modules')

    Set-PwshSymbolicLink -ItemType File `
      -Path (Join-Path $paths.TargetRoot 'Microsoft.PowerShell_profile.ps1') `
      -Target (Join-Path $paths.SourceRoot 'Microsoft.PowerShell_profile.ps1')

    Set-PwshSymbolicLink -ItemType File `
      -Path (Join-Path $paths.Pwsh7Root 'Microsoft.VSCode_profile.ps1') `
      -Target (Join-Path $paths.SourceRoot 'Microsoft.PowerShell_profile.ps1')

    Write-PwshProfileStatus -Stage 'Profile' -Type Success -Message 'Cross-platform module and profile support configured.'
  } catch {
    Write-PwshProfileStatus -Stage 'Profile' -Type Warning -Message "Cross-platform support failed: $($_.Exception.Message)"
  }
}

function Get-PwshProfileResetTargets {
  [CmdletBinding()]
  param (
    [string] $DocumentsPath = [Environment]::GetFolderPath('MyDocuments'),

    [string] $AppDataPath = $env:APPDATA,

    [string] $LocalAppDataPath = $env:LOCALAPPDATA,

    [string] $ProgramFilesPath = $env:ProgramFiles,

    [string] $ProgramFilesX86Path = ${env:ProgramFiles(x86)},

    [string] $StateRegistryPath = 'HKCU:\Software\smoonlee\OhMyPoshProfile'
  )

  $legacyThemePaths = @(
    if ($env:POSH_THEMES_PATH) {
      Join-Path $env:POSH_THEMES_PATH 'quick-term-cloud.omp.json'
    }
    if ($LocalAppDataPath) {
      Join-Path $LocalAppDataPath 'Programs\oh-my-posh\themes\quick-term-cloud.omp.json'
    }
    if ($ProgramFilesPath) {
      Join-Path $ProgramFilesPath 'oh-my-posh\themes\quick-term-cloud.omp.json'
    }
    if ($ProgramFilesX86Path) {
      Join-Path $ProgramFilesX86Path 'oh-my-posh\themes\quick-term-cloud.omp.json'
    }
  ) | Select-Object -Unique
  $stalePowerShellRoots = @(
    Get-ChildItem -LiteralPath $DocumentsPath -Directory -Force -ErrorAction SilentlyContinue |
      Where-Object {
      $_.Name -like 'PowerShell.reset-*' -or
      $_.Name -like 'WindowsPowerShell.reset-*'
    } |
      Select-Object -ExpandProperty FullName
  )

  [pscustomobject]@{
    PowerShellRoots = @(
      Join-Path $DocumentsPath 'PowerShell'
      Join-Path $DocumentsPath 'WindowsPowerShell'
    )
    StalePowerShellRoots = $stalePowerShellRoots
    LocalStore = Join-Path $AppDataPath 'PwshProfile'
    LegacyThemes = @($legacyThemePaths)
    StateRegistry = $StateRegistryPath
  }
}

function Start-PwshProfileReplacementSession {
  [CmdletBinding()]
  param (
    [AllowEmptyCollection()]
    [string[]] $DeferredPaths = @(),

    [int] $ParentProcessId = $PID,

    [bool] $StayOpen = $true
  )

  $powerShellExecutable = if ($PSVersionTable.PSEdition -eq 'Core') {
    Join-Path $PSHOME 'pwsh.exe'
  } else {
    Join-Path $PSHOME 'powershell.exe'
  }
  if (-not (Test-Path -LiteralPath $powerShellExecutable -PathType Leaf)) {
    throw "PowerShell executable was not found: $powerShellExecutable"
  }

  $pathsJson = ConvertTo-Json -InputObject @($DeferredPaths) -Compress
  $replacementScript = @"
`$paths = @(ConvertFrom-Json -InputObject '$($pathsJson.Replace("'", "''"))')
Wait-Process -Id $ParentProcessId -ErrorAction SilentlyContinue
`$failedPaths = @()
foreach (`$path in @(`$paths)) {
  try {
    Remove-Item -LiteralPath `$path -Recurse -Force -ErrorAction Stop
  } catch {
    `$failedPaths += `$path
  }
}
if (`$paths.Count -gt 0 -and `$failedPaths.Count -eq 0) {
  Write-Host '[Reset   ] In-use PowerShell files removed.' -ForegroundColor Green
} elseif (`$failedPaths.Count -gt 0) {
  Write-Host "[WARNING ] Could not remove: `$(`$failedPaths -join ', ')" -ForegroundColor Yellow
}
"@
  $encodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($replacementScript))
  $arguments = @(
    '-NoLogo'
    '-NoProfile'
    if ($StayOpen) { '-NoExit' }
    '-EncodedCommand'
    $encodedCommand
  )

  Start-Process -FilePath $powerShellExecutable -ArgumentList $arguments -NoNewWindow -PassThru -ErrorAction Stop
}

function Remove-PwshProfileResetItem {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [string] $Path,

    [Parameter(Mandatory)]
    [string] $Label,

    [AllowNull()]
    [System.Collections.Generic.List[string]] $DeferredPaths
  )

  $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
  if (-not $item) {
    Write-PwshProfileStatus -Stage 'Reset' -Type Current -Message "$Label not found: $Path"
    return 'Absent'
  }

  try {
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
      Remove-Item -LiteralPath $Path -Force -ErrorAction Stop
    } elseif ($item.PSIsContainer) {
      Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
    } else {
      Remove-Item -LiteralPath $Path -Force -ErrorAction Stop
    }
    Write-PwshProfileStatus -Stage 'Reset' -Type Success -Message "$Label removed: $Path"
    'Removed'
  } catch {
    if ($null -ne $DeferredPaths -and $item.PSProvider.Name -eq 'FileSystem' -and $item.PSIsContainer -and
      -not ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
      $DeferredPaths.Add($Path)
      Write-PwshProfileStatus -Stage 'Reset' -Type Warning -Message "$Label contains files in use; scheduled for removal during the automatic PowerShell restart: $Path"
      return 'Deferred'
    }

    Write-PwshProfileStatus -Stage 'Reset' -Type Warning -Message "Could not remove $Label '$Path': $($_.Exception.Message)"
    'Failed'
  }
}

function Invoke-PwshProfileModuleUnload {
  [CmdletBinding()]
  param (
    [AllowEmptyCollection()]
    [object[]] $Modules = @(Get-Module),

    [ValidateSet('BeforeCleanup', 'Final')]
    [string] $Phase = 'BeforeCleanup'
  )

  $preservedModuleNames = @('PSReadLine', 'PowerShellGet', 'PackageManagement')
  $modulesToUnload = @(
    $Modules |
      Where-Object { $_.Name -notin $preservedModuleNames } |
      Where-Object {
      if ($Phase -eq 'BeforeCleanup') {
        $_.Name -notlike 'Microsoft.PowerShell.*'
      } else {
        $_.Name -like 'Microsoft.PowerShell.*'
      }
    } |
      Sort-Object Name, Version -Descending
  )

  if ($Phase -eq 'BeforeCleanup') {
    foreach ($preservedModule in @($Modules | Where-Object { $_.Name -in $preservedModuleNames })) {
      Write-PwshProfileStatus -Stage 'Modules' -Type Current -Message "Preserved module: $($preservedModule.Name) $($preservedModule.Version)"
    }
  }

  if ($modulesToUnload.Count -eq 0) {
    if ($Phase -eq 'BeforeCleanup') {
      Write-PwshProfileStatus -Stage 'Modules' -Type Current -Message 'No loaded user modules require unloading.'
    }
    return
  }

  if ($Phase -eq 'BeforeCleanup') {
    foreach ($module in $modulesToUnload) {
      try {
        Remove-Module -ModuleInfo $module -Force -ErrorAction Stop
        Write-PwshProfileStatus -Stage 'Modules' -Type Success -Message "Unloaded module: $($module.Name) $($module.Version)"
      } catch {
        Write-PwshProfileStatus -Stage 'Modules' -Type Warning -Message "Could not unload module '$($module.Name)' $($module.Version): $($_.Exception.Message)"
      }
    }
    return
  }

  # Keep this as the final reset operation: unloading foundational modules can remove
  # commands such as Write-Host and Get-Module from the current session.
  Remove-Module -ModuleInfo $modulesToUnload -Force -ErrorAction SilentlyContinue
}

function Invoke-PwshProfileReset {
  [CmdletBinding()]
  param (
    [switch] $SkipConfirmation,

    [switch] $SkipSessionRestart,

    [object] $Targets = (Get-PwshProfileResetTargets),

    [AllowNull()]
    [object[]] $LoadedModules
  )

  Write-PwshProfileHeader -Title 'Pwsh Profile Installer' -Subtitle 'DESTRUCTIVE Profile Reset'
  Write-PwshProfileStatus -Stage 'WARNING' -Type Danger -Message 'RESET WILL PERMANENTLY DELETE BOTH USER POWERSHELL CONFIGURATION FOLDERS.'
  Write-PwshProfileStatus -Stage 'WARNING' -Type Danger -Message 'ALL user-installed PowerShell modules, profiles, profile backups, and symbolic links in those folders will be removed.'
  Write-PwshProfileStatus -Stage 'WARNING' -Type Danger -Message 'All loaded modules except PSReadLine, PowerShellGet, and PackageManagement will be unloaded from this session.'
  Write-PwshProfileStatus -Stage 'WARNING' -Type Danger -Message 'The local PwshProfile store, installer state, and legacy quick-term-cloud theme copies will also be removed.'
  Write-PwshProfileStatus -Stage 'Backup' -Type Warning -Message 'Take a backup of anything you need before continuing.'
  Write-PwshProfileStatus -Stage 'Retained' -Type Current -Message 'Oh My Posh, Winget applications, Windows Terminal settings, and system-wide PowerShell modules will not be uninstalled.'
  Write-PwshProfileStatus -Stage 'Session' -Type Current -Message 'PowerShell will restart automatically in this terminal window when reset is complete.'

  if (-not $SkipConfirmation) {
    Write-Host ''
    Write-PwshProfileStatus -Stage 'Confirm' -Type Action -Message 'Press any key to start the reset, or press Ctrl+C to cancel.'
    try {
      $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    } catch {
      $confirmation = Read-Host -Prompt "Raw key input is unavailable. Type RESET to continue"
      if ($confirmation -cne 'RESET') {
        Write-PwshProfileStatus -Stage 'Reset' -Type Warning -Message 'Reset cancelled.'
        return
      }
    }
  }

  Write-Host ''
  $loadedModules = if ($PSBoundParameters.ContainsKey('LoadedModules')) {
    @($LoadedModules)
  } else {
    @(Get-Module)
  }
  Write-PwshProfileStatus -Stage 'Modules' -Type Action -Message 'Unloading user modules before removing their files...'
  Invoke-PwshProfileModuleUnload -Modules $loadedModules -Phase BeforeCleanup

  Write-Host ''
  Write-PwshProfileStatus -Stage 'Reset' -Type Action -Message 'Removing PowerShell profile and module artifacts...'
  $results = [System.Collections.Generic.List[string]]::new()
  $deferredPaths = [System.Collections.Generic.List[string]]::new()

  # Remove links first so neither PowerShell directory can lead into the other while deleting.
  $powerShellRootItems = @(
    foreach ($root in @($Targets.PowerShellRoots)) {
      [pscustomobject]@{
        Path = $root
        Item = Get-Item -LiteralPath $root -Force -ErrorAction SilentlyContinue
      }
    }
  )
  foreach ($target in @($powerShellRootItems | Where-Object { $_.Item -and ($_.Item.Attributes -band [IO.FileAttributes]::ReparsePoint) })) {
    $results.Add((Remove-PwshProfileResetItem -Path $target.Path -Label 'PowerShell link' -DeferredPaths $deferredPaths))
  }
  foreach ($target in @($powerShellRootItems | Where-Object { -not $_.Item -or -not ($_.Item.Attributes -band [IO.FileAttributes]::ReparsePoint) })) {
    $results.Add((Remove-PwshProfileResetItem -Path $target.Path -Label 'PowerShell configuration' -DeferredPaths $deferredPaths))
  }
  foreach ($stalePowerShellRoot in @($Targets.StalePowerShellRoots)) {
    $results.Add((Remove-PwshProfileResetItem -Path $stalePowerShellRoot -Label 'Previous reset folder' -DeferredPaths $deferredPaths))
  }

  $results.Add((Remove-PwshProfileResetItem -Path $Targets.LocalStore -Label 'Local profile store' -DeferredPaths $deferredPaths))
  foreach ($legacyThemePath in @($Targets.LegacyThemes)) {
    $results.Add((Remove-PwshProfileResetItem -Path $legacyThemePath -Label 'Legacy Oh My Posh theme' -DeferredPaths $deferredPaths))
  }
  $results.Add((Remove-PwshProfileResetItem -Path $Targets.StateRegistry -Label 'Installer registry state' -DeferredPaths $deferredPaths))

  $removedCount = @($results | Where-Object { $_ -eq 'Removed' }).Count
  $deferredCount = @($results | Where-Object { $_ -eq 'Deferred' }).Count
  $absentCount = @($results | Where-Object { $_ -eq 'Absent' }).Count
  $failedCount = @($results | Where-Object { $_ -eq 'Failed' }).Count
  $summaryType = if ($failedCount -gt 0 -or $deferredCount -gt 0) { 'Warning' } else { 'Success' }
  Write-PwshProfileStatus -Stage 'Complete' -Type $summaryType -Message "Reset complete: $removedCount removed, $deferredCount pending session restart, $absentCount already absent, $failedCount failed."

  $replacementStarted = $false
  if ($SkipSessionRestart) {
    Write-PwshProfileStatus -Stage 'Next' -Type Action -Message 'Close PowerShell to release any in-use files, then open a new session.'
  } else {
    try {
      Write-PwshProfileStatus -Stage 'Session' -Type Action -Message 'Restarting PowerShell in this terminal window...'
      Start-PwshProfileReplacementSession -DeferredPaths $deferredPaths.ToArray() | Out-Null
      $replacementStarted = $true
    } catch {
      Write-PwshProfileStatus -Stage 'Session' -Type Warning -Message "Automatic session restart failed: $($_.Exception.Message)"
      Write-PwshProfileStatus -Stage 'Next' -Type Action -Message 'Close PowerShell to release any in-use files, then open a new session.'
    }
  }

  Invoke-PwshProfileModuleUnload -Modules $loadedModules -Phase Final
  if ($replacementStarted) {
    [Environment]::Exit(0)
  }
}

if ($Reset) {
  Invoke-PwshProfileReset
  return
}

if (-not $nerdFontName) {
  throw "NerdFontName is required unless -Reset is specified. Run 'Get-Help $PSCommandPath -Detailed' for usage."
}

if ($RunPhase -in @('All', 'NerdFont') -and $nerdFontName) {
  Write-PwshProfileHeader -Title 'Pwsh Profile Installer' -Subtitle 'Nerd Font Configuration'

  $nerdFontsCatalogUri = 'https://raw.githubusercontent.com/smoonlee/oh-my-posh-profile-dev/main/NerdFontsCatalog.json'
  $nerdFontStateRegistryPath = 'HKCU:\Software\smoonlee\OhMyPoshProfile\NerdFonts'
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

  if ($installDecision.IsNewerThanCatalog) {
    Write-PwshProfileStatus -Stage 'Version' -Type Warning -Message "Installed $installedNerdFontsVersion is newer than catalog $nerdFontsVersion; downgrade skipped."
  }

  if (-not $installDecision.RequiresInstall) {
    if ($installDecision.IsUntracked) {
      Write-PwshProfileStatus -Stage 'Found' -Type Warning -Message "$nerdFontName is installed; release unknown, so it was left unchanged."
    } else {
      Write-PwshProfileStatus -Stage 'Current' -Type Current -Message "$nerdFontName at Nerd Fonts $installedNerdFontsVersion."
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
      Start-PwshProfileElevated -ScriptPath $PSCommandPath -NerdFontName $nerdFontName
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
  Invoke-WingetConfiguration
}

if ($RunPhase -in @('All', 'Modules')) {
  Invoke-PowerShellModuleConfiguration
}
