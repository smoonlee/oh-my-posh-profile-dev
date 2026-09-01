# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [4.0.0-pre-release-0.9] - 2026-09-01

### Profile status display

- `Get-PwshProfile` now prints a concise `Module | Version | Description | Status`
  table (sorted A-Z) for all optional modules, followed by a short version and
  update-channel summary, instead of a raw object dump.
- Add a `PwshProfile.Status` and `PwshProfile.OptionalModule` display format so
  the summary and per-module detail render cleanly whether accessed together
  or piped separately.

### Theme fixes

- Increase the Copilot usage segment's `http_timeout` from 1500ms to 3000ms to
  reduce dropped segments on a cold per-session cache miss.
- Show the `azureCli` and `azurePwsh` segments together even when they report
  the same subscription, for full verbose context.
- Add `overflow: break` to the right-aligned status/execution-time/Copilot/time
  block, and raise `azurePwsh`'s `min_width` to 160, to stop the prompt from
  hard-wrapping mid-word on narrower terminals.

### LocalSource install fix

- Allow `-LocalSource` with `-RunPhase All` so a first-time machine can install
  Nerd Font, Winget packages, and PowerShell Gallery modules from their normal
  sources while installing the profile and optional modules from the local
  working tree instead of a GitHub Release.
- Remove the hidden profile install previously embedded at the end of the
  `Modules` phase, which always installed from a GitHub Release and silently
  ignored `-LocalSource`; the top-level dispatcher now installs the profile
  explicitly for both `All` and `Profile`.
- Fix the Nerd Font phase to also honor `-LocalSource`: it previously always
  queried a published GitHub Release for `NerdFontsCatalog.json` regardless of
  `-LocalSource`, which failed outright when no stable release existed yet.
  `-LocalSource` now loads the catalog from the local repository instead, and
  is forwarded through Administrator elevation relaunches for font installation.

### Dns module

- Add a disabled-by-default `PwshProfile.Dns` module with `Get-DnsResult` for
  querying DNS records, using `Resolve-DnsName` on Windows and falling back to
  `dig` where it is unavailable.
- Support `-RecordType` (A, AAAA, CNAME, MX, NS, PTR, SOA, SRV, TXT, CAA) and
  `-Server` to target a specific resolver.
- Add `Set-PwshProfile -EnableDns` and track the module through local and
  release profile installation.
- Accept a full URL (such as `https://example.com`) for `-Domain`, parsing out
  the host automatically.
- Add `-All` to query every common record type and print a grouped breakdown,
  one table per type that has results.
- Fix `Resolve-DnsName` returning a negative-response `SOA` record (Authority
  section) as if it were the requested type when no records of that type
  exist; it is now filtered out of the results.

### TlsCertificate module

- Add a disabled-by-default `PwshProfile.TlsCertificate` module with
  `Get-TlsCertificate` for remote (native `SslStream`) and local file
  certificate inspection, reporting subject, issuer, validity dates, days
  remaining, and thumbprint.
- Add OpenSSL-backed (`FireDaemon.OpenSSL`) helpers: `Split-PfxCertificate` to
  extract the private key, certificate, and intermediate chain from a PFX;
  `New-PfxCertificate` to package them back into a PFX; `Test-CertificateKeyMatch`
  to verify a certificate and private key belong together; and
  `New-SelfSignedTlsCertificate` to generate a self-signed certificate and key
  for local development.
- Pass PFX and private key passwords to OpenSSL over stdin rather than as
  command-line arguments to avoid exposing them in the process list.
- Add `Set-PwshProfile -EnableTlsCertificate` and track the module through
  local and release profile installation.
- Accept a full URL (such as `https://example.com`) for `-HostName`, parsing
  out the host and, if present, the port automatically.
- Add `-ShowChain` to walk and print the full certificate chain of trust
  (leaf, intermediates, and root) captured during the TLS handshake.

### NetworkCidr module

- Add a `PwshProfile.NetworkCidr.Format.ps1xml` default table view
  (`Cidr`, `Provider`, `NetworkAddress`, `FirstUsableIP`, `LastUsableIP`,
  `BroadcastAddress`, `UsableAddressCount`) instead of a raw ~20-property list
  dump, and track the new format file through local and release installation.
- Replace `-Provider`'s combined canonical/legacy `ValidateSet` with
  tab-completion limited to the four canonical names (`Standard`, `Azure`,
  `AWS`, `GCP`); the legacy aliases (`Normal`, `Amazon`, `Google`) are still
  accepted, and an invalid value now throws a clear, specific error.

### Installer

- Prefix the install status message for a replaced/updated file with
  `[Updated]` so it's clear at a glance which files changed versus which were
  already verified.

## [4.0.0-pre-release-0.8] - 2026-08-26

### Optional module configuration

- Load newly enabled optional modules and unload disabled modules immediately in
  the current session without requiring a profile reload.
- Keep `Set-PwshProfile` output concise by default and add `-PassThru` for the
  complete updated profile state.

## [4.0.0-pre-release-0.7.1] - 2026-08-26

### Update output

- Add a blank line after the `Already up to date.` update result.
- Repair newly introduced release assets when an older updater records the new
  bundle version before it knows about every asset in that bundle.

## [4.0.0-pre-release-0.7] - 2026-08-26

### Optional module status

- Show enabled, disabled, and updateable optional modules in `Get-PwshProfile`.
- Add `OptionalModules` details with each module's enabled state, installed
  manifest version, bundle version, latest bundle version, and update flag.
- Provide comment-based `Get-Help` documentation for every exported optional
  module command, including parameter descriptions and examples.

### Azure Kubernetes module

- Add a disabled-by-default `PwshProfile.AzureKubernetes` module with
  `Get-AksVersion` for structured, region-specific AKS Kubernetes version queries.
- Exclude preview versions by default, support explicit Azure CLI subscription
  selection, and provide an opt-in AKS release tracker shortcut.
- Add `Set-PwshProfile -EnableAzureKubernetes` and track the module through
  local and immutable release installation.

### Network CIDR module

- Add a disabled-by-default `PwshProfile.NetworkCidr` module with
  `Get-NetworkCidr` for Standard, Azure, AWS, and GCP IPv4 subnet calculations.
- Normalize host addresses to their network, model provider-reserved addresses,
  handle `/31` and `/32`, report provider prefix constraints, and split networks
  safely with `-SplitPrefix` and `-MaxSubnets`.
- Add count-based equal subnetting with `-SubnetCount` and efficient zero-based
  child selection with `-SubnetIndex`.

### EndOfLife module

- Add a disabled-by-default `PwshProfile.EndOfLife` module with `Get-EolInfo`
  for querying endoflife.date lifecycle data, including active-support and LTS
  filters.
- Generate the EndOfLife product `ValidateSet` from `EndOfLifeProducts.json`
  and add a scheduled GitHub Action that refreshes it from endoflife.date.
- Include the EndOfLife module in tracked local and release profile assets.
- Add `Set-PwshProfile -EnableEndOfLife` while preserving OTA and other module
  settings, and track both module files through local and release installation.

## [4.0.0-pre-release-0.6] - 2026-08-26

### Update guidance

- Show `Update-PwshProfile -Prerelease` in prerelease update notifications while
  stable notifications continue to show `Update-PwshProfile`.
- Add a blank line after completed profile installation and update sections.

### Optional profile modules

- Add a disabled-by-default `PwshProfile.PublicIP` sample module that exports
  `Get-PublicIP`, returns IP, hostname, ISP, and location details from ipinfo.io,
  and can be enabled through `Set-PwshProfile`.
- Persist the PublicIP toggle without changing the selected Stable or Preview
  OTA channel when either setting is updated.
- Install and verify custom module files as part of the local and immutable
  release asset bundles.
- Extend OTA drift checks, atomic installation, rollback, and the local version
  baseline from three runtime assets to five while allowing a newer release to
  introduce newly tracked assets safely.

## [4.0.0-pre-release-0.5] - 2026-08-26

### Profile status

- Show the local version and latest published Stable and Preview versions in
  `Get-PwshProfile` without adding network work to profile startup.
- Add `Set-PwshProfile -EnableReleaseUpdate` as the explicit Stable counterpart
  to `Set-PwshProfile -EnablePreReleaseUpdate`.
- Separate the selected release summary from asset verification output for
  easier scanning during installation and updates.

### Local development

- Add development-only `-LocalSource` profile installation from the current
  working tree with validation, hashes, atomic replacement, and a local OTA
  baseline—without requiring a release commit or tag.

## [4.0.0-pre-release-0.4] - 2026-08-25

### OTA channel preference

- Add `Get-PwshProfile` and
  `Set-PwshProfile -EnablePreReleaseUpdate` for persisted stable/prerelease OTA
  channel selection.
- Check the configured channel during profile startup and display an explicit
  `[Pre Release] Update Available` warning from cached background results.
- Make `Update-PwshProfile` inherit the configured channel while preserving
  explicit per-invocation overrides.

## [4.0.0-pre-release-0.3] - 2026-08-25

### Terminal profile reconciliation

- Remove duplicate PowerShell and Azure Cloud Shell profiles instead of
  appending them after the canonical entries.
- Enforce the managed profile order while preserving unrelated profiles and
  remapping settings references to retained standard GUIDs.

### Release lookup errors

- Catch and rewrap GitHub Release lookup failures (including a 404 for "no
  releases published") instead of leaking the raw HTTP exception.
- Fail the Nerd Font catalog phase with a single clean warning and exit code
  instead of surfacing an unhandled exception when no stable release exists.

## [4.0.0-pre-release-0.2] - 2026-08-25

### Immutable release sourcing

- Install initial profile configurations only from verified stable or explicitly
  selected prerelease assets; treat `main` as development-only.
- Publish and verify `NerdFontsCatalog.json` as part of the immutable release
  bundle instead of loading it from the mutable repository branch.

### Release integrity

- Reuse release metadata, manifest validation, SHA-256 checks, syntax checks,
  atomic replacement, backups, and rollback for first-time profile installs.
- Removed all project-owned raw-`main` runtime download paths.

## [4.0.0-pre-release-0.1] - 2026-08-25

### Added

- Embedded SemVer version tracking for the PowerShell profile.
- `Get-PwshProfileVersion` for installed and cached release status.
- Daily, non-blocking checks for stable GitHub Releases.
- Manual stable updates with `Update-PwshProfile` and explicit prerelease opt-in
  with `Update-PwshProfile -Prerelease`.
- Release manifests that track the profile, theme, and updater as one versioned
  unit with SHA-256 hashes.
- Atomic release installation with timestamped backups and rollback.
- Local drift detection that refuses to overwrite modified or missing tracked
  files.
- GitHub Actions publishing for versioned profile, theme, updater, and manifest
  release assets.

### Changed

- Restructured the single-file profile into named initialization functions while
  preserving the existing shell behavior.
- Migrated the local OTA baseline from the theme-only schema v1 format to schema
  v2 tracking all release artifacts.
- Made the local `%APPDATA%\PwshProfile` theme the only runtime prompt source.
- Added SemVer 2.0 prerelease precedence support to update decisions.

### Fixed

- Preserved responsive compact and detailed Copilot usage rendering without the
  previous glyph overlap.
- Kept profile update checks offline-safe and outside the startup-critical path.

### Security

- Verify every downloaded release artifact against its release-manifest SHA-256
  hash before installation.
- Validate PowerShell syntax, theme JSON, release metadata, channel, and embedded
  profile version before replacing installed files.
- Removed the mutable `main` branch theme fallback from profile startup.

[Unreleased]: https://github.com/smoonlee/oh-my-posh-profile-dev/compare/v4.0.0-pre-release-0.8...HEAD
[4.0.0-pre-release-0.8]: https://github.com/smoonlee/oh-my-posh-profile-dev/compare/v4.0.0-pre-release-0.7.1...v4.0.0-pre-release-0.8
[4.0.0-pre-release-0.7.1]: https://github.com/smoonlee/oh-my-posh-profile-dev/compare/v4.0.0-pre-release-0.7...v4.0.0-pre-release-0.7.1
[4.0.0-pre-release-0.7]: https://github.com/smoonlee/oh-my-posh-profile-dev/compare/v4.0.0-pre-release-0.6...v4.0.0-pre-release-0.7
[4.0.0-pre-release-0.6]: https://github.com/smoonlee/oh-my-posh-profile-dev/compare/v4.0.0-pre-release-0.5...v4.0.0-pre-release-0.6
[4.0.0-pre-release-0.5]: https://github.com/smoonlee/oh-my-posh-profile-dev/compare/v4.0.0-pre-release-0.4...v4.0.0-pre-release-0.5
[4.0.0-pre-release-0.4]: https://github.com/smoonlee/oh-my-posh-profile-dev/compare/v4.0.0-pre-release-0.3...v4.0.0-pre-release-0.4
[4.0.0-pre-release-0.3]: https://github.com/smoonlee/oh-my-posh-profile-dev/compare/v4.0.0-pre-release-0.2...v4.0.0-pre-release-0.3
[4.0.0-pre-release-0.2]: https://github.com/smoonlee/oh-my-posh-profile-dev/releases/tag/v4.0.0-pre-release-0.2
[4.0.0-pre-release-0.1]: https://github.com/smoonlee/oh-my-posh-profile-dev/releases/tag/v4.0.0-pre-release-0.1
