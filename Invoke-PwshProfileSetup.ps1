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
