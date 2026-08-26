<#
.SYNOPSIS
    PowerShell profile configuration.
#>

$script:PwshProfileVersion = '4.0.0-pre-release-0.7.1'
$script:PwshProfileRepository = 'smoonlee/oh-my-posh-profile-dev'
$script:PwshProfileStorePath = Join-Path $env:APPDATA 'PwshProfile'
$global:PwshProfileVersion = $script:PwshProfileVersion

function global:Compare-PwshProfileSemanticVersion {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [string] $Left,

    [Parameter(Mandatory)]
    [string] $Right
  )

  $parseVersion = {
    param([string] $Value)

    $pattern = '^(?<core>(?<major>0|[1-9]\d*)\.(?<minor>0|[1-9]\d*)\.(?<patch>0|[1-9]\d*))(?:-(?<prerelease>(?:0|[1-9]\d*|[0-9A-Za-z-]*[A-Za-z-][0-9A-Za-z-]*)(?:\.(?:0|[1-9]\d*|[0-9A-Za-z-]*[A-Za-z-][0-9A-Za-z-]*))*))?(?:\+(?<build>[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?$'
    if ($Value -notmatch $pattern) {
      throw "'$Value' is not a valid SemVer 2.0 version."
    }

    [pscustomobject]@{
      Core = [version]$Matches.core
      Prerelease = if ($Matches.prerelease) { @($Matches.prerelease -split '\.') } else { @() }
    }
  }

  $leftVersion = & $parseVersion $Left
  $rightVersion = & $parseVersion $Right
  $coreComparison = $leftVersion.Core.CompareTo($rightVersion.Core)
  if ($coreComparison -ne 0) {
    return [Math]::Sign($coreComparison)
  }

  if ($leftVersion.Prerelease.Count -eq 0 -and $rightVersion.Prerelease.Count -eq 0) { return 0 }
  if ($leftVersion.Prerelease.Count -eq 0) { return 1 }
  if ($rightVersion.Prerelease.Count -eq 0) { return -1 }

  $identifierCount = [Math]::Max($leftVersion.Prerelease.Count, $rightVersion.Prerelease.Count)
  for ($index = 0; $index -lt $identifierCount; $index++) {
    if ($index -ge $leftVersion.Prerelease.Count) { return -1 }
    if ($index -ge $rightVersion.Prerelease.Count) { return 1 }

    $leftIdentifier = $leftVersion.Prerelease[$index]
    $rightIdentifier = $rightVersion.Prerelease[$index]
    $leftIsNumeric = $leftIdentifier -match '^\d+$'
    $rightIsNumeric = $rightIdentifier -match '^\d+$'
    if ($leftIsNumeric -and $rightIsNumeric) {
      $identifierComparison = [System.Numerics.BigInteger]::Parse($leftIdentifier).CompareTo(
        [System.Numerics.BigInteger]::Parse($rightIdentifier)
      )
    }
    elseif ($leftIsNumeric) {
      $identifierComparison = -1
    }
    elseif ($rightIsNumeric) {
      $identifierComparison = 1
    }
    else {
      $identifierComparison = [string]::CompareOrdinal($leftIdentifier, $rightIdentifier)
    }
    if ($identifierComparison -ne 0) {
      return [Math]::Sign($identifierComparison)
    }
  }

  0
}

function global:Get-PwshProfile {
  [CmdletBinding()]
  param (
    [switch] $SettingsOnly
  )

  $storePath = Join-Path $env:APPDATA 'PwshProfile'
  $configPath = Join-Path $storePath 'config\settings.json'
  $enablePreReleaseUpdate = $false
  $enablePublicIP = $false
  $enableNetworkCidr = $false
  $enableEndOfLife = $false
  $enableAzureKubernetes = $false
  if (Test-Path -LiteralPath $configPath -PathType Leaf) {
    try {
      $settings = Get-Content -LiteralPath $configPath -Raw -ErrorAction Stop |
        ConvertFrom-Json -ErrorAction Stop
      $enablePreReleaseUpdate = [bool]$settings.enablePreReleaseUpdate
      $enablePublicIP = [bool]$settings.enablePublicIP
      $enableNetworkCidr = [bool]$settings.enableNetworkCidr
      $enableEndOfLife = [bool]$settings.enableEndOfLife
      $enableAzureKubernetes = [bool]$settings.enableAzureKubernetes
    }
    catch {
      Write-Warning "Ignoring invalid Pwsh Profile settings at '$configPath'."
    }
  }

  $stableVersion = $null
  $previewVersion = $null
  $remoteQuerySucceeded = $false
  if (-not $SettingsOnly) {
    try {
      $releases = Invoke-RestMethod `
        -Uri 'https://api.github.com/repos/smoonlee/oh-my-posh-profile-dev/releases?per_page=20' `
        -Headers @{ 'User-Agent' = 'pwsh-profile-status' } `
        -TimeoutSec 15 `
        -ErrorAction Stop
      $remoteQuerySucceeded = $true
      foreach ($release in @($releases | Where-Object { -not $_.draft })) {
        if ([string]$release.tag_name -notmatch '^v(?<version>(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)(?:-(?<prerelease>(?:0|[1-9]\d*|[0-9A-Za-z-]*[A-Za-z-][0-9A-Za-z-]*)(?:\.(?:0|[1-9]\d*|[0-9A-Za-z-]*[A-Za-z-][0-9A-Za-z-]*))*))?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?)$') {
          continue
        }

        $candidateVersion = $Matches.version
        $isPreview = [bool]$Matches.prerelease
        if ([bool]$release.prerelease -ne $isPreview) {
          continue
        }

        if ($isPreview) {
          if (-not $previewVersion -or
            (Compare-PwshProfileSemanticVersion -Left $candidateVersion -Right $previewVersion) -gt 0) {
            $previewVersion = $candidateVersion
          }
        }
        elseif (-not $stableVersion -or
          (Compare-PwshProfileSemanticVersion -Left $candidateVersion -Right $stableVersion) -gt 0) {
          $stableVersion = $candidateVersion
        }
      }
    }
    catch {
      Write-Warning "Could not query published Pwsh Profile versions. $($_.Exception.Message)"
    }
  }

  $optionalModules = @(
    [pscustomobject]@{
      Name = 'PwshProfile.PublicIP'
      Enabled = $enablePublicIP
    }
    [pscustomobject]@{
      Name = 'PwshProfile.NetworkCidr'
      Enabled = $enableNetworkCidr
    }
    [pscustomobject]@{
      Name = 'PwshProfile.EndOfLife'
      Enabled = $enableEndOfLife
    }
    [pscustomobject]@{
      Name = 'PwshProfile.AzureKubernetes'
      Enabled = $enableAzureKubernetes
    }
  )
  $selectedRemoteVersion = if ($enablePreReleaseUpdate) {
    $previewVersion
  }
  else {
    $stableVersion
  }
  $moduleUpdateAvailable = $false
  if ($selectedRemoteVersion) {
    try {
      $moduleUpdateAvailable = (Compare-PwshProfileSemanticVersion `
        -Left $selectedRemoteVersion `
        -Right $global:PwshProfileVersion) -gt 0
    }
    catch {
      $moduleUpdateAvailable = $false
    }
  }

  $moduleStatuses = @(
    foreach ($module in $optionalModules) {
      $modulePath = Join-Path $storePath "modules\$($module.Name)\$($module.Name).psd1"
      $moduleVersion = $null
      $moduleInstalled = Test-Path -LiteralPath $modulePath -PathType Leaf
      if ($moduleInstalled) {
        try {
          $moduleManifest = Import-PowerShellDataFile -LiteralPath $modulePath -ErrorAction Stop
          if ($moduleManifest.ModuleVersion) {
            $moduleVersion = [string]$moduleManifest.ModuleVersion
          }
        }
        catch {
          $moduleVersion = 'Invalid manifest'
        }
      }

      [pscustomobject]@{
        Name = $module.Name
        Enabled = [bool]$module.Enabled
        Installed = $moduleInstalled
        ModuleVersion = $moduleVersion
        BundleVersion = $global:PwshProfileVersion
        LatestBundleVersion = $selectedRemoteVersion
        UpdateAvailable = $moduleUpdateAvailable
        Path = $modulePath
      }
    }
  )

  [pscustomobject]@{
    LocalVersion = $global:PwshProfileVersion
    StableVersion = if ($stableVersion) {
      $stableVersion
    } elseif ($SettingsOnly) {
      $null
    } elseif ($remoteQuerySucceeded) {
      'Not published'
    } else {
      'Unavailable'
    }
    PreviewVersion = if ($previewVersion) {
      $previewVersion
    } elseif ($SettingsOnly) {
      $null
    } elseif ($remoteQuerySucceeded) {
      'Not published'
    } else {
      'Unavailable'
    }
    EnablePreReleaseUpdate = $enablePreReleaseUpdate
    EnablePublicIP = $enablePublicIP
    EnableNetworkCidr = $enableNetworkCidr
    EnableEndOfLife = $enableEndOfLife
    EnableAzureKubernetes = $enableAzureKubernetes
    UpdateChannel = if ($enablePreReleaseUpdate) { 'prerelease' } else { 'stable' }
    OptionalModules = $moduleStatuses
    EnabledModules = @($moduleStatuses | Where-Object Enabled | Select-Object -ExpandProperty Name)
    DisabledModules = @($moduleStatuses | Where-Object { -not $_.Enabled } | Select-Object -ExpandProperty Name)
    ModulesAvailableForUpdate = if ($moduleUpdateAvailable) {
      @($moduleStatuses | Select-Object -ExpandProperty Name)
    }
    else {
      @()
    }
    ConfigPath = $configPath
  }
}

function global:Set-PwshProfile {
  [CmdletBinding(DefaultParameterSetName = 'Status')]
  param (
    [Parameter(ParameterSetName = 'Stable')]
    [switch] $EnableReleaseUpdate,

    [Parameter(ParameterSetName = 'Preview')]
    [switch] $EnablePreReleaseUpdate,

    [Parameter(ParameterSetName = 'PublicIP')]
    [switch] $EnablePublicIP,

    [Parameter(ParameterSetName = 'NetworkCidr')]
    [switch] $EnableNetworkCidr,

    [Parameter(ParameterSetName = 'EndOfLife')]
    [switch] $EnableEndOfLife,

    [Parameter(ParameterSetName = 'AzureKubernetes')]
    [switch] $EnableAzureKubernetes
  )

  if (-not $PSBoundParameters.ContainsKey('EnableReleaseUpdate') -and
    -not $PSBoundParameters.ContainsKey('EnablePreReleaseUpdate') -and
    -not $PSBoundParameters.ContainsKey('EnablePublicIP') -and
    -not $PSBoundParameters.ContainsKey('EnableNetworkCidr') -and
    -not $PSBoundParameters.ContainsKey('EnableEndOfLife') -and
    -not $PSBoundParameters.ContainsKey('EnableAzureKubernetes')) {
    return Get-PwshProfile
  }

  $current = Get-PwshProfile -SettingsOnly
  $usePrerelease = [bool]$current.EnablePreReleaseUpdate
  $usePublicIP = [bool]$current.EnablePublicIP
  $useNetworkCidr = [bool]$current.EnableNetworkCidr
  $useEndOfLife = [bool]$current.EnableEndOfLife
  $useAzureKubernetes = [bool]$current.EnableAzureKubernetes
  if ($PSBoundParameters.ContainsKey('EnableReleaseUpdate')) {
    $usePrerelease = $false
  }
  elseif ($PSBoundParameters.ContainsKey('EnablePreReleaseUpdate')) {
    $usePrerelease = [bool]$EnablePreReleaseUpdate
  }
  elseif ($PSBoundParameters.ContainsKey('EnablePublicIP')) {
    $usePublicIP = [bool]$EnablePublicIP
  }
  elseif ($PSBoundParameters.ContainsKey('EnableNetworkCidr')) {
    $useNetworkCidr = [bool]$EnableNetworkCidr
  }
  elseif ($PSBoundParameters.ContainsKey('EnableEndOfLife')) {
    $useEndOfLife = [bool]$EnableEndOfLife
  }
  else {
    $useAzureKubernetes = [bool]$EnableAzureKubernetes
  }
  $configPath = $current.ConfigPath
  $configDirectory = Split-Path -Path $configPath -Parent
  if (-not (Test-Path -LiteralPath $configDirectory -PathType Container)) {
    New-Item -ItemType Directory -Path $configDirectory -Force -ErrorAction Stop | Out-Null
  }

  $settings = [ordered]@{
    schemaVersion = 4
    enablePreReleaseUpdate = $usePrerelease
    enablePublicIP = $usePublicIP
    enableNetworkCidr = $useNetworkCidr
    enableEndOfLife = $useEndOfLife
    enableAzureKubernetes = $useAzureKubernetes
    updatedAt = [DateTimeOffset]::UtcNow.ToString('o')
  }
  $temporaryPath = "$configPath.$PID.tmp"
  $backupPath = "$configPath.$PID.bak"
  $json = $settings | ConvertTo-Json -Depth 3
  try {
    [System.IO.File]::WriteAllText(
      [System.IO.Path]::GetFullPath($temporaryPath),
      "$json`n",
      [System.Text.UTF8Encoding]::new($false)
    )
    if (Test-Path -LiteralPath $configPath -PathType Leaf) {
      [System.IO.File]::Replace(
        [System.IO.Path]::GetFullPath($temporaryPath),
        [System.IO.Path]::GetFullPath($configPath),
        [System.IO.Path]::GetFullPath($backupPath),
        $true
      )
    }
    else {
      [System.IO.File]::Move(
        [System.IO.Path]::GetFullPath($temporaryPath),
        [System.IO.Path]::GetFullPath($configPath)
      )
    }
  }
  finally {
    Remove-Item -LiteralPath $temporaryPath, $backupPath -Force -ErrorAction Ignore
  }

  if ($PSBoundParameters.ContainsKey('EnableReleaseUpdate') -or
    $PSBoundParameters.ContainsKey('EnablePreReleaseUpdate')) {
    # Force the newly selected channel to be checked on the next profile load.
    Remove-Item -LiteralPath (Join-Path $env:APPDATA 'PwshProfile\update-state.json') `
      -Force -ErrorAction Ignore
    $channel = if ($usePrerelease) { 'prerelease' } else { 'stable' }
    Write-Host "Pwsh Profile OTA channel set to $channel. Reload the profile to start a fresh update check."
  }
  elseif ($PSBoundParameters.ContainsKey('EnablePublicIP')) {
    $moduleState = if ($usePublicIP) { 'enabled' } else { 'disabled' }
    Write-Host "Pwsh Profile PublicIP module $moduleState. Reload the profile to apply the change."
  }
  elseif ($PSBoundParameters.ContainsKey('EnableNetworkCidr')) {
    $moduleState = if ($useNetworkCidr) { 'enabled' } else { 'disabled' }
    Write-Host "Pwsh Profile NetworkCidr module $moduleState. Reload the profile to apply the change."
  }
  elseif ($PSBoundParameters.ContainsKey('EnableEndOfLife')) {
    $moduleState = if ($useEndOfLife) { 'enabled' } else { 'disabled' }
    Write-Host "Pwsh Profile EndOfLife module $moduleState. Reload the profile to apply the change."
  }
  else {
    $moduleState = if ($useAzureKubernetes) { 'enabled' } else { 'disabled' }
    Write-Host "Pwsh Profile AzureKubernetes module $moduleState. Reload the profile to apply the change."
  }
  Get-PwshProfile
}

function global:Get-PwshProfileVersion {
  [CmdletBinding()]
  param ()

  $statePath = Join-Path $env:APPDATA 'PwshProfile\update-state.json'
  $state = if (Test-Path -LiteralPath $statePath -PathType Leaf) {
    try {
      Get-Content -LiteralPath $statePath -Raw -ErrorAction Stop |
        ConvertFrom-Json -ErrorAction Stop
    }
    catch {
      $null
    }
  }

  $latestVersion = if ($state -and $state.latestVersion) { [string]$state.latestVersion } else { $null }
  $updateAvailable = $false
  if ($latestVersion) {
    try {
      $updateAvailable = (Compare-PwshProfileSemanticVersion `
        -Left $latestVersion `
        -Right $global:PwshProfileVersion) -gt 0
    }
    catch {
      $updateAvailable = $false
    }
  }

  [pscustomobject]@{
    CurrentVersion = $global:PwshProfileVersion
    LatestVersion = $latestVersion
    LatestTag = if ($state) { $state.latestTag } else { $null }
    UpdateAvailable = $updateAvailable
    CheckedChannel = if ($state) { $state.channel } else { $null }
    ConfiguredChannel = (Get-PwshProfile -SettingsOnly).UpdateChannel
    LastChecked = if ($state) { $state.checkedAt } else { $null }
    ReleaseUrl = if ($state) { $state.releaseUrl } else { $null }
  }
}

function global:Update-PwshProfile {
  [CmdletBinding()]
  param (
    [switch] $Prerelease
  )

  $setupPath = Join-Path $env:APPDATA 'PwshProfile\functions\Invoke-PwshProfileSetup.ps1'
  if (-not (Test-Path -LiteralPath $setupPath -PathType Leaf)) {
    Write-Warning "The local profile updater was not found. Run Invoke-PwshProfileSetup.ps1 -RunPhase Profile once to install it."
    return
  }

  $usePrerelease = if ($PSBoundParameters.ContainsKey('Prerelease')) {
    [bool]$Prerelease
  }
  else {
    [bool](Get-PwshProfile -SettingsOnly).EnablePreReleaseUpdate
  }
  & $setupPath -RunPhase ProfileUpdate -Prerelease:$usePrerelease
}

function Import-PwshProfileModules {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [object] $Settings
  )

  foreach ($moduleName in @('PSReadLine', 'Terminal-Icons')) {
    Import-Module -Name $moduleName -Global -ErrorAction Ignore
  }

  $optionalModules = @(
    [pscustomobject]@{
      Name = 'PwshProfile.PublicIP'
      Enabled = [bool]$Settings.EnablePublicIP
    }
    [pscustomobject]@{
      Name = 'PwshProfile.NetworkCidr'
      Enabled = [bool]$Settings.EnableNetworkCidr
    }
    [pscustomobject]@{
      Name = 'PwshProfile.EndOfLife'
      Enabled = [bool]$Settings.EnableEndOfLife
    }
    [pscustomobject]@{
      Name = 'PwshProfile.AzureKubernetes'
      Enabled = [bool]$Settings.EnableAzureKubernetes
    }
  )
  foreach ($module in $optionalModules) {
    if (-not $module.Enabled) {
      Remove-Module -Name $module.Name -Force -ErrorAction Ignore
      continue
    }

    $modulePath = Join-Path $script:PwshProfileStorePath "modules\$($module.Name)\$($module.Name).psd1"
    if (-not (Test-Path -LiteralPath $modulePath -PathType Leaf)) {
      Write-Warning "The enabled $($module.Name) module was not found: $modulePath. Run Update-PwshProfile to restore tracked assets."
      continue
    }

    try {
      Import-Module -Name $modulePath -Global -Force -ErrorAction Stop
    }
    catch {
      Write-Warning "Could not import the enabled $($module.Name) module. $($_.Exception.Message)"
    }
  }
}

function Set-PwshProfileReadLine {
  [CmdletBinding()]
  param ()

  $setOptionCommand = Get-Command -Name Set-PSReadLineOption -ErrorAction Ignore
  if (-not $setOptionCommand) {
    return
  }

  $desiredOptions = [ordered]@{
    EditMode = 'Windows'
    PredictionSource = 'History'
    PredictionViewStyle = 'ListView'
    HistoryNoDuplicates = $true
    HistorySearchCursorMovesToEnd = $true
    HistorySaveStyle = 'SaveIncrementally'
    MaximumHistoryCount = 10000
    BellStyle = 'None'
    ShowToolTips = $true
  }

  $options = @{}
  foreach ($name in $desiredOptions.Keys) {
    if ($setOptionCommand.Parameters.ContainsKey($name)) {
      $options[$name] = $desiredOptions[$name]
    }
  }
  Set-PSReadLineOption @options -ErrorAction Ignore

  $setKeyHandlerCommand = Get-Command -Name Set-PSReadLineKeyHandler -ErrorAction Ignore
  if (-not $setKeyHandlerCommand) {
    return
  }

  $keyHandlers = [ordered]@{
    'Tab'            = 'MenuComplete'
    'Shift+Tab'      = 'TabCompletePrevious'
    'UpArrow'        = 'HistorySearchBackward'
    'DownArrow'      = 'HistorySearchForward'
    'Ctrl+r'         = 'ReverseSearchHistory'
    'Ctrl+l'         = 'ClearScreen'
    'Ctrl+f'         = 'AcceptSuggestion'
    'Alt+RightArrow' = 'AcceptNextSuggestionWord'
    'F2'             = 'SwitchPredictionView'
  }
  $supportedFunctions = @(
    $setKeyHandlerCommand.Parameters['Function'].Attributes |
      Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] } |
      Select-Object -ExpandProperty ValidValues
  )

  foreach ($key in $keyHandlers.Keys) {
    if ($supportedFunctions.Count -eq 0 -or $supportedFunctions -contains $keyHandlers[$key]) {
      Set-PSReadLineKeyHandler -Key $key -Function $keyHandlers[$key] -ErrorAction Ignore
    }
  }
}

function Register-PwshProfileAzureCompletion {
  [CmdletBinding()]
  param ()

  $argumentCompleterCommand = Get-Command -Name Register-ArgumentCompleter -ErrorAction Ignore
  if (-not $argumentCompleterCommand -or
    -not (Get-Command -Name az -ErrorAction Ignore) -or
    -not $argumentCompleterCommand.Parameters.ContainsKey('Native')) {
    return
  }

  Register-ArgumentCompleter -Native -CommandName az -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)

    $completionFile = New-TemporaryFile
    $variables = @{
      ARGCOMPLETE_USE_TEMPFILES = '1'
      _ARGCOMPLETE_STDOUT_FILENAME = $completionFile.FullName
      COMP_LINE = $commandAst.ToString()
      COMP_POINT = [string]$cursorPosition
      _ARGCOMPLETE = '1'
      _ARGCOMPLETE_SUPPRESS_SPACE = '0'
      _ARGCOMPLETE_IFS = "`n"
      _ARGCOMPLETE_SHELL = 'powershell'
    }
    $previousValues = @{}

    try {
      foreach ($name in $variables.Keys) {
        $previousValues[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
        [Environment]::SetEnvironmentVariable($name, $variables[$name], 'Process')
      }

      az 2>$null | Out-Null
      Get-Content -LiteralPath $completionFile.FullName -ErrorAction Ignore |
        Sort-Object -Unique |
        ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
      }
    }
    finally {
      foreach ($name in $previousValues.Keys) {
        [Environment]::SetEnvironmentVariable($name, $previousValues[$name], 'Process')
      }
      Remove-Item -LiteralPath $completionFile.FullName -Force -ErrorAction Ignore
    }
  }
}

function Initialize-PwshProfilePrompt {
  [CmdletBinding()]
  param ()

  if (-not (Get-Command -Name oh-my-posh -ErrorAction Ignore)) {
    return
  }

  $themePath = Join-Path $env:APPDATA 'PwshProfile\themes\quick-term-cloud.omp.json'
  if (-not (Test-Path -LiteralPath $themePath -PathType Leaf)) {
    Write-Warning "The tracked Oh My Posh theme was not found: $themePath. Run the Profile setup phase to restore it."
    return
  }

  function global:Set-PwshProfilePoshContext {
    param([bool]$originalStatus)

    # Oh My Posh calls Set-PoshContext before every prompt render, so a resize
    # is reflected the next time PowerShell draws a prompt.
    try {
      $env:POSH_TERMINAL_WIDTH = [string]$Host.UI.RawUI.WindowSize.Width
    }
    catch {
      $env:POSH_TERMINAL_WIDTH = '0'
    }
  }

  # Seed the value for the first render and replace any hook left by a profile reload.
  Set-PwshProfilePoshContext $true
  Remove-Item -LiteralPath Alias:Set-PoshContext -Force -ErrorAction Ignore
  oh-my-posh init pwsh --config $themePath | Invoke-Expression
  Set-Alias -Name Set-PoshContext -Value Set-PwshProfilePoshContext -Scope Global -Force
}

function Start-PwshProfileUpdateCheck {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [string] $StorePath,

    [Parameter(Mandatory)]
    [string] $Repository,

    [Parameter(Mandatory)]
    [string] $CurrentVersion,

    [switch] $Prerelease
  )

  $channel = if ($Prerelease) { 'prerelease' } else { 'stable' }
  $statePath = Join-Path $StorePath 'update-state.json'
  $state = if (Test-Path -LiteralPath $statePath -PathType Leaf) {
    try {
      Get-Content -LiteralPath $statePath -Raw -ErrorAction Stop |
        ConvertFrom-Json -ErrorAction Stop
    }
    catch {
      $null
    }
  }

  if ($state -and $state.channel -eq $channel -and $state.latestVersion) {
    try {
      if ((Compare-PwshProfileSemanticVersion `
        -Left ([string]$state.latestVersion) `
        -Right $CurrentVersion) -gt 0) {
        $latestTag = if ($state.latestTag) { [string]$state.latestTag } else { "v$($state.latestVersion)" }
        if ($Prerelease) {
          Write-Warning "Pwsh Profile [Pre Release] Update Available: $latestTag. Run Update-PwshProfile -Prerelease to install it."
        }
        else {
          Write-Warning "Pwsh Profile Update Available: $latestTag. Run Update-PwshProfile to install it."
        }
      }
    }
    catch {
      # Ignore invalid cached version data; the next check replaces it.
    }
  }

  $checkedAt = [DateTimeOffset]::MinValue
  if ($state -and $state.checkedAt) {
    [void][DateTimeOffset]::TryParse([string]$state.checkedAt, [ref]$checkedAt)
  }
  if ($state -and $state.channel -eq $channel -and
    [DateTimeOffset]::UtcNow - $checkedAt -lt [TimeSpan]::FromDays(1)) {
    return
  }

  if (-not [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform(
      [System.Runtime.InteropServices.OSPlatform]::Windows
    )) {
    return
  }

  if (-not (Test-Path -LiteralPath $StorePath -PathType Container)) {
    New-Item -ItemType Directory -Path $StorePath -Force -ErrorAction Ignore | Out-Null
  }

  $pendingState = [ordered]@{
    schemaVersion = 2
    channel = $channel
    checkedAt = [DateTimeOffset]::UtcNow.ToString('o')
    latestVersion = if ($state -and $state.channel -eq $channel) { $state.latestVersion } else { $null }
    latestTag = if ($state -and $state.channel -eq $channel) { $state.latestTag } else { $null }
    releaseUrl = if ($state -and $state.channel -eq $channel) { $state.releaseUrl } else { $null }
    error = $null
  }
  $pendingJson = $pendingState | ConvertTo-Json -Depth 3
  [System.IO.File]::WriteAllText($statePath, "$pendingJson`n", [System.Text.UTF8Encoding]::new($false))

  $escapedStatePath = $statePath.Replace("'", "''")
  $escapedRepository = $Repository.Replace("'", "''")
  $compareFunctionBody = ${function:global:Compare-PwshProfileSemanticVersion}.ToString()
  $checkTemplate = @'
function Compare-PwshProfileSemanticVersion {
__COMPARE_FUNCTION_BODY__
}

$statePath = '__STATE_PATH__'
$repository = '__REPOSITORY__'
$prerelease = [bool]::Parse('__PRERELEASE__')
$channel = if ($prerelease) { 'prerelease' } else { 'stable' }
$state = [ordered]@{
  schemaVersion = 2
  channel = $channel
  checkedAt = [DateTimeOffset]::UtcNow.ToString('o')
  latestVersion = $null
  latestTag = $null
  releaseUrl = $null
  error = $null
}
try {
  if ($prerelease) {
    $releases = Invoke-RestMethod -Uri "https://api.github.com/repos/$repository/releases?per_page=20" -Headers @{ 'User-Agent' = 'pwsh-profile-update-check' } -TimeoutSec 5 -ErrorAction Stop
    $release = $null
    $selectedVersion = $null
    foreach ($candidate in @($releases | Where-Object { -not $_.draft -and $_.prerelease })) {
      if ([string]$candidate.tag_name -notmatch '^v(?<version>(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)-(?:0|[1-9]\d*|[0-9A-Za-z-]*[A-Za-z-][0-9A-Za-z-]*)(?:\.(?:0|[1-9]\d*|[0-9A-Za-z-]*[A-Za-z-][0-9A-Za-z-]*))*(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?)$') {
        continue
      }
      $candidateVersion = $Matches.version
      if (-not $release -or
        (Compare-PwshProfileSemanticVersion -Left $candidateVersion -Right $selectedVersion) -gt 0) {
        $release = $candidate
        $selectedVersion = $candidateVersion
      }
    }
  }
  else {
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$repository/releases/latest" -Headers @{ 'User-Agent' = 'pwsh-profile-update-check' } -TimeoutSec 5 -ErrorAction Stop
    if ($release.draft -or $release.prerelease -or
      [string]$release.tag_name -notmatch '^v(?<version>(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?)$') {
      throw 'The latest stable release tag is not valid SemVer.'
    }
    $selectedVersion = $Matches.version
  }

  if (-not $release) {
    throw "No published $channel release is available."
  }
  $state.latestVersion = $selectedVersion
  $state.latestTag = [string]$release.tag_name
  $state.releaseUrl = [string]$release.html_url
}
catch {
  $state.error = $_.Exception.Message
}
$json = $state | ConvertTo-Json -Depth 3
$temporaryPath = "$statePath.$PID.tmp"
[System.IO.File]::WriteAllText($temporaryPath, "$json`n", [System.Text.UTF8Encoding]::new($false))
Move-Item -LiteralPath $temporaryPath -Destination $statePath -Force
'@
  $checkScript = $checkTemplate.
  Replace('__COMPARE_FUNCTION_BODY__', $compareFunctionBody).
  Replace('__STATE_PATH__', $escapedStatePath).
  Replace('__REPOSITORY__', $escapedRepository).
  Replace('__PRERELEASE__', ([bool]$Prerelease).ToString())

  $encodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($checkScript))
  $executable = if ($PSVersionTable.PSEdition -eq 'Core') {
    Join-Path $PSHOME 'pwsh.exe'
  }
  else {
    Join-Path $PSHOME 'powershell.exe'
  }

  try {
    Start-Process -FilePath $executable -ArgumentList @(
      '-NoLogo', '-NoProfile', '-NonInteractive', '-EncodedCommand', $encodedCommand
    ) -WindowStyle Hidden -ErrorAction Stop | Out-Null
  }
  catch {
    # Update checks must never delay or break profile startup.
  }
}

$profileSettings = Get-PwshProfile -SettingsOnly
Import-PwshProfileModules -Settings $profileSettings
Set-PwshProfileReadLine
Register-PwshProfileAzureCompletion
Initialize-PwshProfilePrompt
Start-PwshProfileUpdateCheck `
  -StorePath $script:PwshProfileStorePath `
  -Repository $script:PwshProfileRepository `
  -CurrentVersion $script:PwshProfileVersion `
  -Prerelease:$profileSettings.EnablePreReleaseUpdate

Remove-Item Function:Import-PwshProfileModules -ErrorAction Ignore
Remove-Item Function:Set-PwshProfileReadLine -ErrorAction Ignore
Remove-Item Function:Register-PwshProfileAzureCompletion -ErrorAction Ignore
Remove-Item Function:Initialize-PwshProfilePrompt -ErrorAction Ignore
Remove-Item Function:Start-PwshProfileUpdateCheck -ErrorAction Ignore
Remove-Variable -Name PwshProfileRepository, PwshProfileStorePath, profileSettings -Scope Script -ErrorAction Ignore
