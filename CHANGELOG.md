# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [4.0.0-pre-release-0.3] - 2026-08-25

### Terminal profile reconciliation

- Remove duplicate PowerShell and Azure Cloud Shell profiles instead of
  appending them after the canonical entries.
- Enforce the managed profile order while preserving unrelated profiles and
  remapping settings references to retained standard GUIDs.

### Release sourcing

- Catch and rewrap GitHub Release lookup failures (including a 404 for "no
  releases published") instead of leaking the raw HTTP exception.
- Fail the Nerd Font catalog phase with a single clean warning and exit code
  instead of surfacing an unhandled exception when no stable release exists.

## [4.0.0-pre-release-0.2] - 2026-08-25

### Release sourcing

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

[Unreleased]: https://github.com/smoonlee/oh-my-posh-profile-dev/compare/v4.0.0-pre-release-0.2...HEAD
[4.0.0-pre-release-0.2]: https://github.com/smoonlee/oh-my-posh-profile-dev/releases/tag/v4.0.0-pre-release-0.2
[4.0.0-pre-release-0.1]: https://github.com/smoonlee/oh-my-posh-profile-dev/releases/tag/v4.0.0-pre-release-0.1
