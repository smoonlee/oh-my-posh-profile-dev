[CmdletBinding()]
param (
  # This region is refreshed by scripts/Update-NerdFontsCatalog.ps1.
  # BEGIN GENERATED NERD FONT VALIDATESET
  [ValidateSet(
    '0xProto',
  )]
  [string] $nerdFontName = ''
  # END GENERATED NERD FONT VALIDATESET
)

$nerdFontsCatalogPath = Join-Path $PSScriptRoot 'NerdFontsCatalog.json'
$nerdFontsVersion = $null
$nerdFontVersion = $null
$nerdFontArchiveName = $null

if ($nerdFontName) {
  if (-not (Test-Path $nerdFontsCatalogPath)) {
    throw "Nerd Fonts catalog not found: $nerdFontsCatalogPath"
  }

  $nerdFontsCatalog = Get-Content -Path $nerdFontsCatalogPath -Raw | ConvertFrom-Json
  $selectedNerdFont = $nerdFontsCatalog.Fonts |
    Where-Object FriendlyName -EQ $nerdFontName |
    Select-Object -First 1

  if (-not $selectedNerdFont) {
    throw "Nerd Font '$nerdFontName' was not found in the generated catalog."
  }

  # Download archives use ArchiveName.zip; keep the validated friendly name intact.
  $nerdFontArchiveName = $selectedNerdFont.ArchiveName
  $nerdFontVersion = $selectedNerdFont.FontVersion
  $nerdFontsVersion = $nerdFontsCatalog.NerdFontsVersion
}
