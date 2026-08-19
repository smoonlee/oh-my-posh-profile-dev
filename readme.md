# Windows Terminal - Profile Development

## Dynamic Nerd Fonts catalog

`Invoke-PwshProfileSetup.ps1` accepts the friendly patched font names shown on the
[Nerd Fonts downloads page](https://www.nerdfonts.com/font-downloads). For example:

```powershell
.\Invoke-PwshProfileSetup.ps1 -nerdFontName CaskaydiaCove
```

The selected friendly name is resolved to `$nerdFontArchiveName` for downloading
`$nerdFontArchiveName.zip`. The generated `NerdFontsCatalog.json` also provides the
current Nerd Fonts release and upstream font version.

The **Update Nerd Fonts catalog** GitHub Actions workflow runs on `ubuntu-latest`
every Sunday at 06:00 UTC and can also be run manually. It:

1. Scrapes friendly names, archive names, download URLs, and the release version.
2. Cross-checks each archive against Nerd Fonts' `fonts.json` for its font version.
3. Regenerates the `nerdFontName` parameter's `ValidateSet` and the JSON catalog.
4. Creates or updates a pull request only when the upstream catalog changed and
	assigns it to `@smoonlee` for review.
5. Includes the Nerd Fonts release change and lists added, updated, and removed
	fonts with their relevant versions in the pull request body.

The repository's **Allow GitHub Actions to create and approve pull requests**
setting must be enabled for the built-in `GITHUB_TOKEN` to create the PR.

GitHub Actions are pinned to immutable commit SHAs rather than mutable version
tags. Dependabot checks for newer action releases every Sunday at 05:00 UTC,
opens dependency update pull requests, and assigns them to `@smoonlee`.

To regenerate locally, run `scripts/Update-NerdFontsCatalog.ps1` from the repository
root.
