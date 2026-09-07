$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('eol-release-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path (Join-Path $testRoot 'src/modules/PwshProfile.EndOfLife') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $testRoot 'src/profile') -Force | Out-Null
$manifest = Join-Path $testRoot 'src/modules/PwshProfile.EndOfLife/PwshProfile.EndOfLife.psd1'
$profile = Join-Path $testRoot 'src/profile/Microsoft.PowerShell_profile.ps1'
$log = Join-Path $testRoot 'CHANGELOG.md'
$previous = Join-Path $testRoot 'previous.json'
$current = Join-Path $testRoot 'EndOfLifeProducts.json'
foreach ($case in @(
  @{ Old = '4.0.0'; New = '4.0.1' },
  @{ Old = '4.0.0-pre-release-0.9.4'; New = '4.0.0-pre-release-0.9.5' },
  @{ Old = '4.0.0-beta'; New = '4.0.0-beta.1' }
)) {
  Set-Content $manifest "@{`n  ModuleVersion = '1.0.0'`n}"
  Set-Content $profile ("`$script:PwshProfileVersion = '" + $case.Old + "'")
  Set-Content $log "# Changelog`n`n## [$($case.Old)]`n`nExisting notes."
  Set-Content $previous '{"Products":["alpha","removed"]}'
  Set-Content $current '{"Products":["alpha","added"]}'
  & "$PSScriptRoot/Update-EndOfLifeRelease.ps1" -PreviousCatalogPath $previous -RepositoryRoot $testRoot
  if ((Import-PowerShellDataFile $manifest).ModuleVersion -ne '1.0.1') { throw 'Module patch bump failed.' }
  if ((Get-Content $profile -Raw) -notmatch [regex]::Escape($case.New)) { throw 'Profile bump failed.' }
  $notes = Get-Content $log -Raw
  foreach ($expected in @("## [$($case.New)]", '### PwshProfile.EndOfLife 1.0.1', 'Added products: `added`', 'Removed products: `removed`', 'Existing notes.')) {
    if (-not $notes.Contains($expected)) { throw "Missing changelog text: $expected" }
  }
  Copy-Item $current $previous -Force
  $before = @($manifest, $profile, $log | ForEach-Object { (Get-FileHash $_).Hash }) -join ','
  & "$PSScriptRoot/Update-EndOfLifeRelease.ps1" -PreviousCatalogPath $previous -RepositoryRoot $testRoot
  $after = @($manifest, $profile, $log | ForEach-Object { (Get-FileHash $_).Hash }) -join ','
  if ($before -ne $after) { throw 'Unchanged catalog modified release files.' }
}
foreach ($path in @('scripts/Update-EndOfLifeRelease.ps1', 'scripts/Update-EndOfLifeProducts.ps1', 'src/modules/PwshProfile.EndOfLife/PwshProfile.EndOfLife.psm1')) {
  $tokens = $null
  $errors = $null
  [void][Management.Automation.Language.Parser]::ParseFile((Join-Path $root $path), [ref]$tokens, [ref]$errors)
  if ($errors.Count) { throw ($errors.Message -join '; ') }
}
Import-Module (Join-Path $root 'src/modules/PwshProfile.EndOfLife/PwshProfile.EndOfLife.psd1') -Force
$expectedProducts = @((Get-Command Get-EolInfo).Parameters['ProductName'].Attributes |
  Where-Object { $_ -is [Management.Automation.ValidateSetAttribute] } |
  ForEach-Object { $_.ValidValues } | Sort-Object)
$listedProducts = @(Get-EolInfo -ListProducts)
if (($listedProducts -join ',') -cne ($expectedProducts -join ',')) { throw 'Product listing differs from generated validation.' }
if ((@(Get-EolInfo -ListProducts -Like 'powershell') -join ',') -ne 'powershell') { throw 'Product filtering failed.' }
Write-Host 'PASS: stable/prerelease bumps, module version, changelog, unchanged catalog, PowerShell syntax, and product listing.'
