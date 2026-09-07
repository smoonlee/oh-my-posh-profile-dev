[CmdletBinding()]
param (
  [Parameter(Mandatory)]
  [string] $PreviousCatalogPath,
  [string] $RepositoryRoot = (Split-Path -Path $PSScriptRoot -Parent)
)

$ErrorActionPreference = 'Stop'
$current = Get-Content -LiteralPath (Join-Path $RepositoryRoot 'EndOfLifeProducts.json') -Raw | ConvertFrom-Json
$previous = Get-Content -LiteralPath $PreviousCatalogPath -Raw | ConvertFrom-Json
$added = @($current.Products | Where-Object { $_ -cnotin $previous.Products } | Sort-Object -Unique)
$removed = @($previous.Products | Where-Object { $_ -cnotin $current.Products } | Sort-Object -Unique)
if ($added.Count -eq 0 -and $removed.Count -eq 0) {
  Write-Host 'Product catalog unchanged; no release bump needed.'
  return
}

$manifestPath = Join-Path $RepositoryRoot 'src/modules/PwshProfile.EndOfLife/PwshProfile.EndOfLife.psd1'
$profilePath = Join-Path $RepositoryRoot 'src/profile/Microsoft.PowerShell_profile.ps1'
$changelogPath = Join-Path $RepositoryRoot 'CHANGELOG.md'
$manifest = [IO.File]::ReadAllText($manifestPath)
$profile = [IO.File]::ReadAllText($profilePath)
$changelog = [IO.File]::ReadAllText($changelogPath)
$modulePattern = "(?m)^(\s*ModuleVersion\s*=\s*)'(?<version>\d+\.\d+\.\d+)'"
$profilePattern = "(?m)^(\s*\`$script:PwshProfileVersion\s*=\s*)'(?<version>[^']+)'"
if ([regex]::Matches($manifest, $modulePattern).Count -ne 1 -or
    [regex]::Matches($profile, $profilePattern).Count -ne 1) {
  throw 'Expected one module version and one profile version assignment.'
}
$oldModuleVersion = [version][regex]::Match($manifest, $modulePattern).Groups['version'].Value
$moduleVersion = '{0}.{1}.{2}' -f $oldModuleVersion.Major, $oldModuleVersion.Minor, ($oldModuleVersion.Build + 1)
$oldProfileVersion = [regex]::Match($profile, $profilePattern).Groups['version'].Value
if ($oldProfileVersion -match '^(?<major>\d+)\.(?<minor>\d+)\.(?<patch>\d+)(?:-(?<pre>[0-9A-Za-z.-]+))?(?:\+[0-9A-Za-z.-]+)?$') {
  $core = '{0}.{1}.{2}' -f $Matches.major, $Matches.minor, $Matches.patch
  if ($Matches.pre) {
    $parts = $Matches.pre.Split('.')
    if ($parts[-1] -match '^\d+$') {
      $parts[-1] = ([long]$parts[-1] + 1).ToString()
    } else {
      $parts += '1'
    }
    $profileVersion = "$core-$($parts -join '.')"
  } else {
    $profileVersion = '{0}.{1}.{2}' -f $Matches.major, $Matches.minor, ([long]$Matches.patch + 1)
  }
} else {
  throw "Unsupported profile version '$oldProfileVersion'."
}
if ($changelog -match "(?m)^## \[$([regex]::Escape($profileVersion))\]") {
  throw "Changelog already contains $profileVersion; reconcile the release version before retrying."
}
$heading = [regex]::Match($changelog, '(?m)^## \[')
if (-not $heading.Success) { throw 'No release heading found in CHANGELOG.md.' }
$notes = @(
  "## [$profileVersion] - $([DateTime]::UtcNow.ToString('yyyy-MM-dd'))"
  ''
  "### PwshProfile.EndOfLife $moduleVersion"
  ''
  '- Refresh the supported product catalog and tab completion from endoflife.date.'
)
if ($added.Count) { $notes += "- Added products: $(($added | ForEach-Object { '`{0}`' -f $_ }) -join ', ')." }
if ($removed.Count) { $notes += "- Removed products: $(($removed | ForEach-Object { '`{0}`' -f $_ }) -join ', ')." }
$notes += '- Lifecycle dates continue to be fetched live when queried.'
$newline = if ($changelog.Contains("`r`n")) { "`r`n" } else { "`n" }
$changelog = $changelog.Insert($heading.Index, (($notes -join $newline) + $newline + $newline))
$manifest = [regex]::Replace($manifest, $modulePattern, [Text.RegularExpressions.MatchEvaluator]{ param($m) $m.Groups[1].Value + "'$moduleVersion'" })
$profile = [regex]::Replace($profile, $profilePattern, [Text.RegularExpressions.MatchEvaluator]{ param($m) $m.Groups[1].Value + "'$profileVersion'" })
$utf8 = [Text.UTF8Encoding]::new($false)
[IO.File]::WriteAllText($manifestPath, $manifest, $utf8)
[IO.File]::WriteAllText($profilePath, $profile, $utf8)
[IO.File]::WriteAllText($changelogPath, $changelog, $utf8)
Write-Host "Prepared EndOfLife $moduleVersion in profile $profileVersion. Publish v$profileVersion after merging to distribute the update."
