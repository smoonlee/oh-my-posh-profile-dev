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

The standalone script loads `NerdFontsCatalog.json` from the selected published
GitHub Release into `$nerdFontsCatalog` for that run and verifies its SHA-256
hash against `PwshProfile.release.json`. It does not read or create a local
catalog, and no GitHub authentication is required. The repository's `main`
branch is development-only and is never used as a runtime installation source.

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
`profiles.defaults.font.face`, `profiles.defaults.font.size` (`9`), and
`profiles.defaults.colorScheme` (`Solarized Dark (modified)`). It creates or
refreshes that custom scheme without changing unrelated schemes, updates any
profile-specific `font.face` and `font.size` overrides, and reconciles managed
profiles into this order: `Pwsh 7`, `Pwsh 5`, `Command Prompt`, then
`Azure Cloud Shell`. Duplicate managed profiles are removed, references to their
GUIDs are redirected to the retained standard profile, and unrelated profiles
remain afterward in their existing order. A `.bak` backup is written beside each
settings file before saving, for example `settings.json.20260819140530.bak`.

The script also prints the exact Windows font family name, which is the value to
use in VS Code settings such as `editor.fontFamily` and
`terminal.integrated.fontFamily`.

## Winget package configuration

After the Nerd Font phase, the script checks and silently installs/upgrades the
developer CLI toolchain with Winget. Machine-scope packages are installed/upgraded
from an Administrator PowerShell session; Bicep and Oh My Posh are installed in
user scope.

| Package ID | Scope |
| --- | --- |
| `Amazon.AWSCLI` | Machine |
| `FireDaemon.OpenSSL` | Machine |
| `Git.Git` | Machine |
| `GitHub.Copilot` | Machine |
| `GitHub.cli` | Machine |
| `Hashicorp.Terraform` | Machine |
| `Helm.Helm` | Machine |
| `JanDeDobbeleer.OhMyPosh` | User |
| `jqlang.jq` | Machine |
| `Kubernetes.kubectl` | Machine |
| `Microsoft.Azure.Kubelogin` | Machine |
| `Microsoft.AzureCLI` | Machine |
| `Microsoft.Bicep` | User |
| `Microsoft.PowerShell` | Machine |
| `MikeFarah.yq` | Machine |
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

After the Winget phase, the script installs the profile, theme, and local updater
from an immutable published GitHub Release. The profile is installed for the
current user and loads the verified local `quick-term-cloud.omp.json` via
`oh-my-posh init`.

- Stable releases are selected by default. Use `-Prerelease` to explicitly
  select the highest published prerelease.
- Every asset is verified against `PwshProfile.release.json` before any file is
  changed; there is no fallback to `main`.
- If existing local files differ, the script warns and prompts before replacing
  them. Timestamped backups are retained.
- If existing files already match the release, they are left unchanged.
- If installation or the final baseline write fails, replaced files are rolled
  back and newly created files are removed.
- After configuration finishes, the profile is loaded into the current
  PowerShell session.

Run just this phase with:

```powershell
.\Invoke-PwshProfileSetup.ps1 -RunPhase Profile
```

To install a published prerelease for testing:

```powershell
.\Invoke-PwshProfileSetup.ps1 -RunPhase Profile -Prerelease
```

For development, install the current working-tree profile, theme, and setup
script without creating a commit, tag, or GitHub Release:

```powershell
.\src\Invoke-PwshProfileSetup.ps1 -LocalSource
```

Use `ProfileUpdate` when only the local runtime files and baseline need to be
refreshed, without rerunning cross-platform profile configuration:

```powershell
.\src\Invoke-PwshProfileSetup.ps1 -RunPhase ProfileUpdate -LocalSource
```

When `RunPhase` is omitted, `-LocalSource` selects the `Profile` phase. Local
source mode is intentionally limited to `Profile` and `ProfileUpdate` and cannot
be combined with `-Prerelease`. It infers the source from the checked-out
script's `src` directory, validates both PowerShell files, the theme JSON, and
the embedded SemVer version, verifies staged SHA-256 hashes, then uses the same
atomic replacement, backup, rollback, and schema v2 baseline model as release
installation. The baseline channel is recorded as `local`, so a later published
OTA update can still verify the locally installed files before replacing them.

Local mode explicitly trusts the working tree and therefore bypasses GitHub
Release metadata and remote asset verification. Use it only for development.

Download `Invoke-PwshProfileSetup.ps1` itself from the desired GitHub Release,
not from the repository branch. A stable install fails closed when no stable
release exists; it does not silently select a prerelease.

This phase also creates `%APPDATA%\PwshProfile\version.json` using manifest
schema v2. The manifest records the installed version and SHA-256 hashes of the
profile, theme, and local updater. Existing schema v1 theme-only manifests are
migrated the next time this phase runs.

### Profile versions and OTA updates

The profile embeds a SemVer 2.0 version and provides these commands:

```powershell
Get-PwshProfile
Set-PwshProfile -EnableReleaseUpdate
Set-PwshProfile -EnablePreReleaseUpdate
Get-PwshProfileVersion
Update-PwshProfile
```

`Get-PwshProfileVersion` reports the installed version and the latest cached
release check, including its channel and tag. `Get-PwshProfile` reports the local
version, latest published Stable and Preview versions, and the persisted OTA
channel preference. The remote versions are queried only when the command is run;
profile startup does not wait for that request. At most once per day, startup
launches a hidden child PowerShell process to query the configured GitHub Release
channel. A later profile start or reload displays a notification when the cached
release is newer; installation remains manual.

Stable OTA checks are the default. Enable prerelease checks with:

```powershell
Set-PwshProfile -EnablePreReleaseUpdate
```

Changing the setting clears the old channel cache, so the next profile start or
reload launches a fresh hidden check. If a newer prerelease exists, a subsequent
start or reload displays:

```text
WARNING: Pwsh Profile [Pre Release] Update Available: <tag>. Run Update-PwshProfile to install it.
```

Return to stable-only checks explicitly with:

```powershell
Set-PwshProfile -EnableReleaseUpdate
```

`Set-PwshProfile -EnablePreReleaseUpdate:$false` remains supported for scripts
that used the original disable form.

#### Future settings candidates

These ideas are not implemented yet, but fit naturally under
`Set-PwshProfile` as the settings surface evolves:

- `-UpdateChannel Stable|Preview` as a concise alternative to channel switches.
- `-UpdateCheckInterval Daily|Weekly|Manual` for notification frequency.
- `-NotificationMode Warning|Quiet` to control startup messages.
- `-Reset` to restore default profile settings and clear update-check state.
- An explicitly opt-in automatic update policy, only if it preserves the
  existing integrity, drift-refusal, backup, and rollback guarantees.

`Update-PwshProfile` performs a release update as one tracked unit:

1. Reads the latest stable SemVer 2.0 GitHub Release and its
  `PwshProfile.release.json` manifest.
2. Compares all installed files with their schema v2 baseline and refuses the
  update if the profile, theme, or updater was locally modified or removed.
3. Downloads the three installed assets beside their destinations, verifies every SHA-256
  hash, parses both PowerShell files, validates the theme JSON, and confirms the
  profile's embedded version.
4. Replaces the files atomically while retaining timestamped backups. If any
  replacement or final manifest write fails, the previous files are restored.
5. Writes `version.json` last and asks you to open a new PowerShell session.

`Update-PwshProfile` uses the persisted channel preference. Either channel can
still be selected explicitly for one invocation:

```powershell
Update-PwshProfile -Prerelease
Update-PwshProfile -Prerelease:$false
```

To intentionally accept local files as a new baseline, review them first and run
the `Profile` setup phase again. The updater never silently overwrites drift.

### Publishing a profile release

The **Publish Pwsh Profile Release** workflow runs when a GitHub Release is
published. Before creating a release:

1. Set `$script:PwshProfileVersion` in
  `src/profile/Microsoft.PowerShell_profile.ps1` to a SemVer 2.0 value such as
  `4.0.0` or `4.0.0-pre-release-0.1`.
2. Commit and tag that exact revision with the matching `v`-prefixed tag, such
  as `v4.0.0` or `v4.0.0-pre-release-0.1`.
3. Publish the GitHub Release for that tag. GitHub's **Set as a pre-release**
  setting must match whether the SemVer value contains a prerelease component.

The workflow validates the tag and embedded version, parses the profile, theme,
and Nerd Fonts catalog, computes SHA-256 hashes from the tagged files, generates
`PwshProfile.release.json`, and uploads the profile, theme, setup script, Nerd
Fonts catalog, and manifest as release assets. It does not overwrite an existing
release asset.
Release notes are maintained in [`CHANGELOG.md`](CHANGELOG.md).

### Dynamic prompt updates

The profile exports the current terminal width before every Oh My Posh render.
The Copilot segment uses a compact icon-and-percentage layout below 140 columns
and adds its usage gauge from 140 columns upward. Resize changes are reflected
the next time PowerShell draws a prompt (press Enter); terminals cannot rewrite
prompt text that has already been drawn.

Execution time and the clock update on every prompt render. Copilot usage is
cached for one minute per shell session to keep the prompt responsive while
still providing near-real-time quota updates.
