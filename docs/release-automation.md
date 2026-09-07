# Catalog update releases

The weekly/manual EndOfLife workflow opens or refreshes one automation PR.
When products are added or removed, it also prepares:

- A patch increment of `PwshProfile.EndOfLife`'s `ModuleVersion`.
- A profile patch increment for stable versions, or an increment of the final
  numeric prerelease identifier (for example, `4.0.0-pre-release-0.9.4` becomes
  `4.0.0-pre-release-0.9.5`). A nonnumeric prerelease suffix gains `.1`.
- A dated root `CHANGELOG.md` release section, grouped under the module name
  and version, listing added and removed products.

An unchanged product set does not bump versions or add release notes. Each
workflow run starts from the default branch, so refreshing an unmerged PR
recalculates its bump from that branch rather than incrementing the PR again.
The release preparation script expects the catalog captured before refreshing;
it fails if that baseline is missing.

Review and merge the automation PR. Its merge publishes a GitHub Release tagged
with the prepared profile version (`v` prefix), copies the corresponding
changelog section into the release notes, detects prerelease versions, and
dispatches the existing workflow to validate and upload the immutable module and
profile assets. Users then receive them through `Update-PwshProfile` on their
chosen release channel. Closing the PR without merging publishes nothing.

The asset workflow also retains its `release: published` trigger for releases
created manually. Automated releases explicitly dispatch it because GitHub does
not start another workflow from a release created with `GITHUB_TOKEN`. Uploads
use `--clobber`, so rerunning the release job repairs or replaces its assets.

Catalog refreshes use patch releases; use minor releases for new functionality.
Review upstream removals before merging because removed names stop being accepted.
Lifecycle dates for supported products are fetched live and need no release.
Keep other modules' changes under their own headings in the root changelog;
modules currently ship together in the profile bundle.

Run `pwsh -NoProfile -File scripts/Test-EndOfLifeRelease.ps1` to check release
preparation using temporary fixtures without network access.
