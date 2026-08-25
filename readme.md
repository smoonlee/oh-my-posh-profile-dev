# Windows Terminal - Profile Development

## Dynamic Nerd Fonts catalog

`Invoke-PwshProfileSetup.ps1` accepts the friendly patched font names shown on the
[Nerd Fonts downloads page](https://www.nerdfonts.com/font-downloads). For example:

```powershell
.\Invoke-PwshProfileSetup.ps1 -NerdFont CaskaydiaCove
```

`-NerdFont` is an alias for `-nerdFontName`. Supplying either parameter checks
both `C:\Windows\Fonts` and the current user's
`%LOCALAPPDATA%\Microsoft\Windows\Fonts` directory for matching `.ttf`, `.otf`, or
`.ttc` Nerd Font files. If the font is already installed, its matching files are
reported and no elevation is requested. Otherwise, the script displays the
Windows UAC prompt and relaunches itself in an Administrator PowerShell 7 session
for installation. Running the script without a Nerd Font does not request
Administrator access.

On Windows 11 24H2 or later, enabling Windows sudo in **Inline** or **Input
closed** mode keeps elevated installation output in the current terminal. If
Windows sudo is unavailable, disabled, or configured for a new window, the script
falls back to native UAC, which must start a separate elevated PowerShell process.
Use `-Verbose` to show the catalog source and elevation fallback guidance.

The standalone script always loads the public catalog directly into the
`$nerdFontsCatalog` variable for that run. It does not read or create a local
`NerdFontsCatalog.json`, and no GitHub authentication is required.

The selected friendly name is resolved to `$nerdFontArchiveName` for downloading
`$nerdFontArchiveName.zip`. The generated `NerdFontsCatalog.json` also provides the
current Nerd Fonts release and upstream font version.

### Font installation and updates

The script installs the selected font system-wide from its catalog `DownloadUrl`
and records its Nerd Fonts release per font under
`HKCU:\Software\smoonlee\OhMyPoshProfile\NerdFonts`. On later runs it:

- leaves a tracked font unchanged when its release and upstream font version match;
- updates a tracked font when either version is newer in the catalog;
- leaves an existing untracked font unchanged and reports that its release is
	unknown;
- installs a missing font; and
- never downgrades a font tracked at a newer Nerd Fonts release.

The registry marker is written only after all selected font files install
successfully.

When the selected font is installed or already present, the script updates Windows
Terminal stable and preview settings when present. It sets
`profiles.defaults.font.face` and `profiles.defaults.font.size` (`10`), updates
any profile-specific `font.face` and `font.size` overrides, and writes a `.bak`
backup beside each settings file before saving. Backups are timestamped, for
example `settings.json.20260819140530.bak`.

The script also prints the exact Windows font family name, which is the value to
use in VS Code settings such as `editor.fontFamily` and
`terminal.integrated.fontFamily`.

## Winget package configuration

After the Nerd Font phase, the script checks and silently installs/upgrades the
developer CLI toolchain with Winget. Machine-scope packages are installed/upgraded
from an Administrator PowerShell session; Oh My Posh is installed in user scope.

| Package ID | Scope |
| --- | --- |
| `Amazon.AWSCLI` | Machine |
| `Git.Git` | Machine |
| `GitHub.cli` | Machine |
| `Hashicorp.Terraform` | Machine |
| `Helm.Helm` | Machine |
| `JanDeDobbeleer.OhMyPosh` | User |
| `Kubernetes.kubectl` | Machine |
| `Microsoft.Azure.Kubelogin` | Machine |
| `Microsoft.AzureCLI` | Machine |
| `Ookla.Speedtest.CLI` | Machine |

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

## PowerShell profile configuration

After the Winget phase, the script deploys `src/profile/Microsoft.PowerShell_profile.ps1`
to the current user's PowerShell profile (`$PROFILE.CurrentUserCurrentHost`), which
loads the repository's `quick-term-cloud.omp.json` theme via `oh-my-posh init`.

- If no profile file exists yet, it's created (creating the parent directory if
	needed).
- If a profile file already exists and differs from the repository version, the
	script warns and prompts for confirmation before overwriting. A timestamped
	backup (for example `Microsoft.PowerShell_profile.ps1.20260825140530.bak`) is
	created first.
- If the existing profile already matches, nothing is changed.

Run just this phase with:

```powershell
.\Invoke-PwshProfileSetup.ps1 -RunPhase Profile
```

> The theme is currently referenced from the `main` branch's raw URL. This will
> move to a versioned GitHub release asset once a release is published.
