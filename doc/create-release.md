# Create a profile release

The release workflow runs when a **GitHub Release is published**. Pushing a tag
alone does not run `.github/workflows/publish-profile-release.yml`.

## Release order

1. Update the embedded version in
   `src/profile/Microsoft.PowerShell_profile.ps1`.
2. Add the matching dated section to `CHANGELOG.md`.
3. Commit the release changes and push `main`.
4. Create an annotated tag on that exact commit and push the tag.
5. Publish a GitHub Release for the tag.
6. Verify that **Publish Pwsh Profile Release** succeeds and uploads all four
   release assets.

If changes go through a pull request, merge the PR first, update local `main`
with a fast-forward pull, and tag the resulting merge commit. Never tag the
unmerged feature branch.

## Prerelease example

For `4.0.0-pre-release-0.1`, the embedded version, changelog heading, tag, and
GitHub Release must all use the exact same value.

```powershell
git switch main
git pull --ff-only origin main

# Update and validate the versioned files before continuing.
git status --short
git diff --check

# Commit and push the release commit first.
git add --all
git commit -m "Release v4.0.0-pre-release-0.1"
git push origin main

# Tag the commit that is now on origin/main.
git tag -a v4.0.0-pre-release-0.1 -m "Release v4.0.0-pre-release-0.1"
git push origin v4.0.0-pre-release-0.1

# Publishing the prerelease triggers the asset workflow.
gh release create v4.0.0-pre-release-0.1 `
  --verify-tag `
  --prerelease `
  --title "v4.0.0-pre-release-0.1" `
  --notes-from-tag
```

For a stable release, use a stable SemVer such as `4.0.0` and omit
`--prerelease`.

## Verify the release

```powershell
gh run list --workflow "Publish Pwsh Profile Release" --limit 5
gh release view v4.0.0-pre-release-0.1 --json isPrerelease,tagName,url,assets
```

A successful release contains:

- `Microsoft.PowerShell_profile.ps1`
- `quick-term-cloud.omp.json`
- `Invoke-PwshProfileSetup.ps1`
- `PwshProfile.release.json`

The workflow rejects a release when:

- the tag is not valid SemVer 2.0;
- the tag and embedded profile version differ;
- the GitHub prerelease setting does not match the SemVer prerelease component;
- `CHANGELOG.md` has no matching version section;
- either PowerShell script fails parsing;
- the theme is invalid JSON; or
- an immutable release asset with the same name already exists.

## Important safeguards

- Do not move or reuse a published tag.
- Do not delete and recreate a release to replace assets; increment the version.
- Confirm the workflow succeeded before announcing or installing the release.
- Prerelease installation requires `Update-PwshProfile -Prerelease`.
