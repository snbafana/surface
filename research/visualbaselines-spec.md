# `visualbaselines` Spec

## Decision

Do not build `visualbaselines` as a Surface plugin. Implement it as a `block-preview` and `BlockPreviewTests` feature that compares deterministic preview PNGs against explicit baselines and writes review artifacts.

Use the existing `BlockPreview.render`, `BlockPreview.renderSurface`, `Block.Context`, and `BlockRuntime.makeView()` path. A future block such as `previewgallery` may read the resulting report and images, but no `BlockRuntime` should record, approve, update, compare, or delete visual baselines.

## Existing Owner / Dedup Decision

- `tools/block-preview/support/BlockPreviewSupport.swift` owns deterministic rendering through `Blocks.registry`, `Block.Context`, and the real runtime view path.
- `tools/block-preview/source/main.swift` owns developer preview commands.
- `tests/BlockPreviewTests/BlockPreviewTests.swift` owns fixture coverage and nonblank assertions.
- `previewgallery` owns read-only display of existing preview PNGs and metadata.
- `localbuildstatus` owns last-run status reports under `.build/surface-status`.
- `diagnosticbundle` owns exporting selected preview/baseline/diff artifacts.
- `visualbaselines` owns only baseline image storage policy, comparison logic, diff artifact writing, explicit record/check commands, and a machine-readable comparison report.

If implementation needs a UI, feed the report into `previewgallery`. Do not make a second preview renderer, second fixture registry, approval queue, screenshot manager, or plugin registry.

## Product Boundary

It should:

- Render current images with the existing `BlockPreview.renderAll` and `BlockPreview.renderSurface` functions.
- Store reference images in a checked-in test-owned directory, for example `tests/BlockPreviewTests/Baselines`.
- Compare decoded PNG pixels, not file bytes or PNG metadata.
- Enforce exact dimensions for every baseline.
- Support explicit per-case tolerances only in a small checked-in config file.
- Write current images, diff images, and a JSON report under `.build`, never beside source baselines unless recording was explicitly requested.
- Attach current/baseline/diff artifacts to test failures when running under XCTest-compatible tooling.
- Expose explicit CLI commands for check and record.
- Make CI check-only by default.

It should not:

- Add a `visualbaselines` block, runtime, registry entry, overlay panel, or approval queue.
- Run from `previewgallery` or any other plugin.
- Record or update baselines during normal tests, CI, preview gallery refresh, app launch, or overlay actions.
- Take screenshots of the desktop, Finder, browsers, or other apps.
- Compare arbitrary screenshot folders, Desktop files, Downloads files, Photos libraries, or user image collections.
- Upload images, open PRs, post comments, compress archives, or export artifacts directly.
- Depend on a hosted service such as Chromatic, Percy, or Applitools in v1.
- Use ImageMagick, shell scripts, browser automation, external CLIs, AI vision, or network services for comparison.
- Hide differences behind automatic approval or baseline update behavior.
- Duplicate `BlockPreviewTests` fixture coverage, `previewgallery` display, `localbuildstatus` run history, or `diagnosticbundle` export.

## First Version

### Paths

Checked-in baselines:

```text
tests/BlockPreviewTests/Baselines/
  quicksave-empty.png
  quicksave-notes-and-captures.png
  copyhistory-empty.png
  copyhistory-mixed-clipboard.png
  codexlog-empty.png
  codexlog-active-thread.png
  surface-active.png
```

Generated artifacts:

```text
.build/block-preview-current/
.build/block-preview-diffs/
.build/surface-status/visualbaselines.json
```

Optional checked-in config:

```text
tests/BlockPreviewTests/visual-baselines.json
```

### Commands

Add commands to the existing `block-preview` executable:

```bash
swift run block-preview baseline-check
swift run block-preview baseline-record
```

`baseline-check`:

1. Renders all `BlockPreview.cases` plus `surface-active.png`.
2. Reads matching baseline PNGs.
3. Compares decoded dimensions and pixels.
4. Writes current images and diff images under `.build`.
5. Writes `.build/surface-status/visualbaselines.json`.
6. Exits nonzero on missing, extra, dimension-mismatched, or over-threshold baselines.

`baseline-record`:

1. Renders all cases through the same path.
2. Writes baseline PNGs under `tests/BlockPreviewTests/Baselines`.
3. Requires an explicit command invocation.
4. Should be documented as local-only and never used by CI.

### Tolerance Config

Default policy:

- dimensions must match exactly
- decoded pixels must match exactly
- PNG byte differences are ignored

Config may loosen only explicit cases:

```json
{
  "version": 1,
  "cases": {
    "surface-active": {
      "maxDifferentPixelRatio": 0.001,
      "maxMeanChannelDelta": 1.5
    }
  }
}
```

Do not add global broad tolerances until there is measured platform noise. Per-case tolerance requires a comment in the JSON.

### Report

```json
{
  "version": 1,
  "generatedAt": "2026-06-24T06:45:40Z",
  "mode": "check",
  "baselineDirectory": "tests/BlockPreviewTests/Baselines",
  "currentDirectory": ".build/block-preview-current",
  "diffDirectory": ".build/block-preview-diffs",
  "summary": {
    "passed": 6,
    "failed": 1,
    "missing": 0,
    "extra": 0
  },
  "results": [
    {
      "id": "quicksave-notes-and-captures",
      "kind": "block",
      "blockID": "quicksave",
      "fixture": "notes-and-captures",
      "status": "passed",
      "baselinePath": "tests/BlockPreviewTests/Baselines/quicksave-notes-and-captures.png",
      "currentPath": ".build/block-preview-current/quicksave-notes-and-captures.png",
      "diffPath": null,
      "width": 600,
      "height": 281,
      "differentPixels": 0,
      "differentPixelRatio": 0,
      "meanChannelDelta": 0
    }
  ]
}
```

Allowed statuses:

- `passed`
- `missingBaseline`
- `extraBaseline`
- `dimensionMismatch`
- `pixelMismatch`
- `renderFailed`
- `unreadable`

## Display Handoff

`previewgallery` may later read `visualbaselines.json` and show:

- current thumbnail
- baseline thumbnail
- diff thumbnail
- status
- copyable check/record commands

It must not call `baseline-check`, call `baseline-record`, update files, approve diffs, or delete artifacts.

## Source Evidence

- Surface already renders deterministic preview PNGs through `BlockPreview.renderAll` and `BlockPreview.renderSurface`.
- `BlockPreviewTests` already enforce fixture coverage and nonblank PNG output, so baseline enforcement belongs in the same test harness.
- `previewgallery-spec.md` explicitly excludes visual baselines, pixel diffs, approval workflows, and snapshot updates from the gallery block.
- Playwright visual comparisons produce screenshots, compare them to reference screenshots, and support explicit snapshot updates from the test workflow.
- Storybook visual tests use snapshot comparison against known-good baselines, reinforcing that baselines are a testing concern.
- Point-Free's Swift SnapshotTesting stores snapshots alongside tests and reports image differences as test artifacts, showing the right layer for Swift baseline checks.
- Apple `XCTAttachment` supports attaching images, screenshots, files, folders, and strings to tests for later analysis.
- GitHub artifact upload can preserve generated current/diff images in CI, but upload belongs to CI or `diagnosticbundle`, not the comparison logic.

## Tests

- Compare identical decoded PNGs as passed.
- Compare byte-different but pixel-identical PNGs as passed.
- Fail missing baseline.
- Fail extra baseline.
- Fail dimension mismatch.
- Fail pixel mismatch beyond threshold.
- Generate a diff PNG for pixel mismatches.
- Write `visualbaselines.json` with stable relative paths.
- Keep baseline recording unavailable from normal `BlockPreviewTests`.
- Verify `baseline-check` never mutates checked-in baseline paths.
- Verify `baseline-record` requires the explicit CLI command.
- Verify `previewgallery` is not required for baseline checking.

## Implementation Notes

- Put comparison helpers in `BlockPreviewSupport` only if both CLI and tests share them.
- Keep the image comparison small and CoreGraphics/AppKit-based.
- Do not add a dependency unless the local comparison logic becomes brittle after measurement.
- If baseline size becomes a problem, decide retention and Git LFS policy separately.
- If visual review UI becomes important, extend `previewgallery` as read-only report display rather than adding approval actions.
