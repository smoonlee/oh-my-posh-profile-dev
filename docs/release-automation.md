# Independent module releases

Every module under `src/modules/PwshProfile.*` can be released independently
from the Pwsh Profile bundle. A module release changes only that module's
version and files; the profile version and unrelated modules remain unchanged.

Each independently released module must follow these conventions:

- Its directory and manifest are both named `PwshProfile.<Name>`.
- `RootModule` names a `.psm1` file in the same directory.
- `FormatsToProcess`, when present, names `.ps1xml` files in that directory.
- The directory contains a `CHANGELOG.md` section matching `ModuleVersion`.
- A release version is stable SemVer in the form `major.minor.patch`.

When a merged PR changes a module manifest's `ModuleVersion`, the **Publish Pwsh
Profile Module Updates** workflow discovers it automatically. It compares the
base and merged versions, reads the matching module changelog section, validates
the manifest, script, and declared format files, and creates a draft release
tagged `PwshProfile.<Name>-v<version>`.

The workflow uploads only the files declared by that module plus
`PwshProfile.<Name>.release.json`, which records their SHA-256 hashes. It
publishes the release after every asset uploads successfully. Multiple module
version changes in one PR produce separate releases. An unchanged version does
not produce a release, and a validation or upload failure leaves an unpublished
draft.

`Update-PwshProfile` queries releases once and discovers all module tags matching
installed `PwshProfile.*` modules. For each newer version it verifies release
metadata and every asset hash, stages the complete module, validates PowerShell
and XML, replaces only that module's files atomically, and restores backups if
installation fails. Loaded modules are re-imported after installation.

Module tags are excluded from stable and prerelease profile selection. Full
profile releases continue to use `v<version>` tags and self-contained bundles.

The EndOfLife catalog workflow uses the same generic publisher. When its product
set changes, it increments `PwshProfile.EndOfLife` to the next minor version and
updates that module's changelog. It does not change the profile version.

Run `pwsh -NoProfile -File scripts/Test-EndOfLifeRelease.ps1` to verify catalog
versioning, profile/module tag isolation, and independent module installation
without network access.
