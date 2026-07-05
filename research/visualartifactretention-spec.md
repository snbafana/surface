# `visualartifactretention` Spec

## Decision

Do not build `visualartifactretention` as a Surface plugin, cleanup daemon, or artifact manager. Implement it as repository policy for the `visualbaselines` harness and any future CI workflow.

Generated current/diff images are disposable `.build` outputs. Checked-in baseline images are test fixtures. CI artifacts are short-lived failure evidence. `previewgallery` and `diagnosticbundle` may read or export existing files, but no `BlockRuntime` should clean, upload, retain, expire, approve, or move visual artifacts.

## Existing Owner / Dedup Decision

- `.gitignore` already excludes `.build/`, so generated preview/current/diff/report artifacts are local and disposable by default.
- `visualbaselines` owns baseline check/record commands, current images, diff images, and `visualbaselines.json`.
- `BlockPreviewTests` owns visual baseline enforcement when added.
- `previewgallery` owns read-only display of existing preview/current/baseline/diff artifacts.
- `diagnosticbundle` owns explicit support export of selected artifacts.
- CI workflow files own any `actions/upload-artifact` usage and retention days.
- Git/GitHub own repository storage constraints.
- Git LFS owns large binary versioning only if checked-in baselines grow beyond plain Git comfort.

If implementation needs cleanup, make it overwrite the known `.build` output directories during `baseline-check`. Do not add a background cleaner, artifact index, block, registry entry, or scheduled retention service.

## Product Boundary

It should:

- Keep generated current images, diff images, and reports under ignored `.build` paths.
- Make `baseline-check` overwrite or recreate `.build/block-preview-current`, `.build/block-preview-diffs`, and `.build/surface-status/visualbaselines.json`.
- Keep checked-in baselines under `tests/BlockPreviewTests/Baselines`.
- Treat baseline images as code-reviewed test fixtures.
- Upload current/diff/report artifacts in CI only on visual-baseline failure.
- Use short CI artifact retention, initially 7 days.
- Revisit Git LFS only after measured baseline size crosses a repository-policy threshold.
- Let `diagnosticbundle` export selected current/diff/baseline/report files manually when needed.

It should not:

- Add a `visualartifactretention` block, runtime, registry entry, daemon, cron job, watcher, or cleaner.
- Delete user files, Desktop screenshots, Downloads, Photos, or arbitrary image directories.
- Upload from the Surface app or a plugin.
- Upload successful-run artifacts by default.
- Store generated current/diff artifacts in the repo.
- Add Git LFS before it is needed.
- Auto-prune checked-in baselines.
- Rewrite Git history to remove baselines as part of the harness.
- Compress artifacts in the baseline harness.
- Duplicate `diagnosticbundle` export or `previewgallery` display.

## First Version

### Paths

Disposable generated files:

```text
.build/block-preview-current/
.build/block-preview-diffs/
.build/surface-status/visualbaselines.json
```

Checked-in baselines:

```text
tests/BlockPreviewTests/Baselines/
```

No generated `.build` visual artifact should be referenced by source-controlled paths except in docs and reports.

### Local Retention

`baseline-check` should:

1. Remove or overwrite `.build/block-preview-current`.
2. Remove or overwrite `.build/block-preview-diffs`.
3. Recreate `.build/surface-status/visualbaselines.json`.
4. Keep only the latest local check output.

This is enough for the first version. Developers can copy artifacts manually or use `diagnosticbundle` before rerunning if they need to keep a failure.

### CI Retention

If CI is added:

- Run `swift run block-preview baseline-check`.
- Upload `.build/block-preview-current`, `.build/block-preview-diffs`, and `.build/surface-status/visualbaselines.json` only when the check fails.
- Set `retention-days: 7`.
- Do not upload successful-run images by default.
- Do not include hidden files.
- Give the artifact a stable name such as `surface-visual-baseline-failure`.

Example:

```yaml
- name: Upload visual baseline failure artifacts
  if: failure()
  uses: actions/upload-artifact@v7
  with:
    name: surface-visual-baseline-failure
    path: |
      .build/block-preview-current
      .build/block-preview-diffs
      .build/surface-status/visualbaselines.json
    retention-days: 7
```

### Baseline Size Policy

Start without Git LFS.

Add a size check to the harness or a future verification script:

- warn when any baseline PNG is larger than 10 MB
- warn when the total baseline directory is larger than 25 MB
- block recording when any single baseline would exceed 50 MB unless the policy is updated

Revisit Git LFS when:

- any baseline approaches GitHub's 50 MB warning threshold
- total baseline size materially slows clone/test work
- baseline churn becomes noisy in regular Git diffs
- the repo approaches a size where GitHub's small-repository guidance is no longer true

Do not add Git LFS just because the files are PNGs. For the current expected fixture set, plain Git is simpler and easier to review.

### Report Fields

Extend `visualbaselines.json` with optional artifact policy metadata:

```json
{
  "artifactPolicy": {
    "localRetention": "latest-only",
    "ciUpload": "failure-only",
    "ciRetentionDays": 7,
    "baselineStorage": "git",
    "lfsRequired": false,
    "baselineBytes": 214832,
    "largestBaselineBytes": 48231,
    "warnings": []
  }
}
```

`previewgallery` may display these fields later, read-only.

## Source Evidence

- `.gitignore` already excludes `.build/`, making generated visual artifacts local by default.
- `visualbaselines-spec.md` already defines current images, diff images, and `visualbaselines.json` under `.build`, with checked-in baselines under `tests/BlockPreviewTests/Baselines`.
- `diagnosticbundle-spec.md` owns explicit export of selected artifacts, so retention policy should not grow a second exporter.
- GitHub's `actions/upload-artifact` supports `retention-days`, with a 1-to-90 day range and a 90-day default.
- GitHub Actions workflow artifact docs show per-artifact custom retention via `retention-days`.
- GitHub recommends repositories stay small, ideally below 1 GB, and strongly recommends keeping them below 5 GB.
- GitHub documents Git LFS as the path for large files and documents plan-specific maximum LFS object sizes.
- Git LFS stores large file contents outside normal Git history while replacing them with pointer files.

## Tests

- `baseline-check` writes generated artifacts only under `.build`.
- `baseline-check` overwrites stale current/diff directories.
- `baseline-record` writes only checked-in baseline paths.
- `visualbaselines.json` includes artifact policy metadata.
- Size policy warns for large individual baselines.
- Size policy warns for large total baseline directory.
- CI example uploads only current/diff/report paths and uses `retention-days: 7`.
- No plugin runtime action deletes, uploads, compresses, or exports visual artifacts.
- `previewgallery` can read artifact policy fields without mutating files.

## Implementation Notes

- Keep this as docs plus small harness checks.
- Do not add a cleanup command until repeated local artifact buildup is measured.
- If Git LFS is adopted later, do it deliberately with `.gitattributes`, setup docs, and migration guidance.
- If CI artifact storage becomes noisy, lower retention or upload only diff/report files before adding new infrastructure.
