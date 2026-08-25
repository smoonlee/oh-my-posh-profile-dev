<#
.SYNOPSIS
    PowerShell profile configuration.
#>

$script:PwshProfileVersion = '4.0.0-pre-release-0.3'
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
    UpdateAvailable = $updateAvailable
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

  & $setupPath -RunPhase ProfileUpdate -Prerelease:$Prerelease
}

function Import-PwshProfileModules {
  [CmdletBinding()]
  param ()

  foreach ($moduleName in @('PSReadLine', 'Terminal-Icons')) {
    Import-Module -Name $moduleName -Global -ErrorAction Ignore
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
    [string] $CurrentVersion
  )

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

  if ($state -and $state.latestVersion) {
    try {
      if ((Compare-PwshProfileSemanticVersion `
        -Left ([string]$state.latestVersion) `
        -Right $CurrentVersion) -gt 0) {
        Write-Warning "Pwsh Profile v$($state.latestVersion) is available. Run Update-PwshProfile to install it."
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
  if ([DateTimeOffset]::UtcNow - $checkedAt -lt [TimeSpan]::FromDays(1)) {
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
    schemaVersion = 1
    checkedAt = [DateTimeOffset]::UtcNow.ToString('o')
    latestVersion = if ($state) { $state.latestVersion } else { $null }
    releaseUrl = if ($state) { $state.releaseUrl } else { $null }
    error = $null
  }
  $pendingJson = $pendingState | ConvertTo-Json -Depth 3
  [System.IO.File]::WriteAllText($statePath, "$pendingJson`n", [System.Text.UTF8Encoding]::new($false))

  $escapedStatePath = $statePath.Replace("'", "''")
  $escapedRepository = $Repository.Replace("'", "''")
  $checkScript = @"
`$statePath = '$escapedStatePath'
`$state = [ordered]@{
  schemaVersion = 1
  checkedAt = [DateTimeOffset]::UtcNow.ToString('o')
  latestVersion = `$null
  releaseUrl = `$null
  error = `$null
}
try {
  `$release = Invoke-RestMethod -Uri 'https://api.github.com/repos/$escapedRepository/releases/latest' -Headers @{ 'User-Agent' = 'pwsh-profile-update-check' } -TimeoutSec 5 -ErrorAction Stop
  if (-not `$release.prerelease -and [string]`$release.tag_name -match '^v(?<version>(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?)$') {
    `$state.latestVersion = `$Matches.version
    `$state.releaseUrl = [string]`$release.html_url
  }
  else {
    `$state.error = 'The latest stable release tag is not valid SemVer.'
  }
}
catch {
  `$state.error = `$_.Exception.Message
}
`$json = `$state | ConvertTo-Json -Depth 3
`$temporaryPath = "`$statePath.`$PID.tmp"
[System.IO.File]::WriteAllText(`$temporaryPath, "`$json``n", [System.Text.UTF8Encoding]::new(`$false))
Move-Item -LiteralPath `$temporaryPath -Destination `$statePath -Force
"@

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

Import-PwshProfileModules
Set-PwshProfileReadLine
Register-PwshProfileAzureCompletion
Initialize-PwshProfilePrompt
Start-PwshProfileUpdateCheck `
  -StorePath $script:PwshProfileStorePath `
  -Repository $script:PwshProfileRepository `
  -CurrentVersion $script:PwshProfileVersion

Remove-Item Function:Import-PwshProfileModules -ErrorAction Ignore
Remove-Item Function:Set-PwshProfileReadLine -ErrorAction Ignore
Remove-Item Function:Register-PwshProfileAzureCompletion -ErrorAction Ignore
Remove-Item Function:Initialize-PwshProfilePrompt -ErrorAction Ignore
Remove-Item Function:Start-PwshProfileUpdateCheck -ErrorAction Ignore
Remove-Variable -Name PwshProfileRepository, PwshProfileStorePath -Scope Script -ErrorAction Ignore
