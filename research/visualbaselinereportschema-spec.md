# `visualbaselinereportschema` Spec

## Decision

Do not build `visualbaselinereportschema` as a Surface plugin, report registry, schema service, or second baseline manager. Implement it as the exact `visualbaselines.json` report contract owned by the existing `visualbaselines` harness.

The report must consolidate the prior visual specs:

- `visualbaselines`: check/record mode, case results, comparison metrics, current/baseline/diff paths.
- `visualartifactretention`: generated artifact paths, CI upload policy, baseline storage/size policy.
- `baselineplatforms`: platform lane metadata and mismatch classification.
- `rendererscalecontrol`: renderer scale, appearance, locale, and output pixel dimensions.

Use the existing `BlockPreview.renderAll`, `BlockPreview.renderSurface`, `Block.Context`, `BlockRuntime.makeView()`, and `BlockImageRenderer` path. No `BlockRuntime` should write, approve, switch, or interpret visual baselines.

## Existing Owner / Dedup Decision

- `visualbaselines` owns `.build/surface-status/visualbaselines.json`.
- `visualartifactretention` owns artifact retention policy fields inside that report.
- `baselineplatforms` owns platform/lane policy fields inside that report.
- `rendererscalecontrol` owns renderer configuration fields inside that report.
- `previewgallery` may read the report later, but only read-only.
- `diagnosticbundle` may export the report and selected images, but must not become the report producer.
- `localbuildstatus` may summarize the last report, but must not recompute it.

Do not create separate `platform.json` report copies, artifact indexes, renderer metadata files, or plugin-readable schema registries. If checked-in `tests/BlockPreviewTests/Baselines/platform.json` exists, it is baseline-lane metadata; the generated run report still goes to `.build/surface-status/visualbaselines.json`.

## Product Boundary

It should:

- Write one generated report at `.build/surface-status/visualbaselines.json`.
- Use schema id `surface.visualbaselines.report.v1`.
- Use stable relative paths from the repo root when possible.
- Include all top-level sections even when empty.
- Preserve deterministic ordering: summary fields, then results in `BlockPreview.cases` order, then `surface-active`.
- Distinguish platform/renderer mismatch from UI pixel changes.
- Include artifact retention policy in the report so CI, `previewgallery`, and `diagnosticbundle` do not invent their own rules.
- Allow future consumers to ignore unknown additive fields while requiring producers to keep v1 fields stable.

It should not:

- Add a `visualbaselinereportschema` `BlockRuntime`, registry entry, daemon, watcher, approval queue, schema server, or second fixture registry.
- Store generated current/diff files outside ignored `.build` paths.
- Store checked-in baselines under `.build`.
- Let `previewgallery` mutate reports or baselines.
- Let `diagnosticbundle` regenerate, compare, or approve visual baselines.
- Upload report artifacts from the app or a plugin.
- Add broad tolerances, auto-approval, auto-recording, or platform-lane auto-creation.
- Encode absolute user paths unless no repo-relative path exists and the path is already a manual local artifact path.

## Report Path

Generated report:

```text
.build/surface-status/visualbaselines.json
```

Generated artifacts referenced by the report:

```text
.build/block-preview-current/
.build/block-preview-diffs/
```

Checked-in inputs referenced by the report:

```text
tests/BlockPreviewTests/Baselines/
tests/BlockPreviewTests/Baselines/platform.json
tests/BlockPreviewTests/visual-baselines.json
```

## Top-Level Schema

```json
{
  "version": 1,
  "schema": "surface.visualbaselines.report.v1",
  "generatedAt": "2026-06-28T18:53:16Z",
  "mode": "check",
  "command": "swift run block-preview baseline-check",
  "paths": {},
  "platform": {},
  "renderer": {},
  "artifactPolicy": {},
  "tolerancePolicy": {},
  "summary": {},
  "results": [],
  "warnings": []
}
```

Required top-level keys:

- `version`
- `schema`
- `generatedAt`
- `mode`
- `command`
- `paths`
- `platform`
- `renderer`
- `artifactPolicy`
- `tolerancePolicy`
- `summary`
- `results`
- `warnings`

Allowed `mode` values:

- `check`
- `record`

## Paths

```json
{
  "paths": {
    "repoRoot": "${repoRoot}",
    "baselineDirectory": "tests/BlockPreviewTests/Baselines",
    "currentDirectory": ".build/block-preview-current",
    "diffDirectory": ".build/block-preview-diffs",
    "reportPath": ".build/surface-status/visualbaselines.json",
    "platformPath": "tests/BlockPreviewTests/Baselines/platform.json",
    "toleranceConfigPath": "tests/BlockPreviewTests/visual-baselines.json"
  }
}
```

Rules:

- Prefer repo-relative paths.
- Use `${repoRoot}` instead of an absolute repo root.
- Use `null` for missing optional checked-in files.
- Do not include absolute home-directory paths in normal reports.

## Platform

```json
{
  "platform": {
    "lane": "default",
    "minimumTarget": "macOS 14",
    "runnerLabel": "macos-15",
    "osName": "macOS",
    "osVersion": "15.5",
    "architecture": "arm64",
    "displayScale": 2,
    "baselinePlatformPath": "tests/BlockPreviewTests/Baselines/platform.json",
    "matchesBaselinePlatform": true,
    "mismatches": [],
    "warnings": []
  }
}
```

Allowed `mismatches` values:

- `osMajor`
- `architecture`
- `rendererScale`
- `pixelDimensions`
- `lane`

Warnings can include:

- `osPatch`
- `runnerLabel`
- `displayScaleUnavailable`
- `localeUnavailable`

## Renderer

```json
{
  "renderer": {
    "name": "AppKit.NSHostingView.cacheDisplay",
    "configuration": "baselineDefault",
    "scalePolicy": "fixed",
    "scale": 2,
    "appearance": "light",
    "colorScheme": "light",
    "localeIdentifier": "en_US_POSIX"
  }
}
```

Allowed `scalePolicy` values:

- `actual`
- `fixed`

Allowed `appearance` values:

- `system`
- `light`
- `dark`

When `scalePolicy` is `fixed`, platform display scale is metadata only. Result-level pixel dimensions come from renderer output.

## Artifact Policy

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

Allowed values:

- `localRetention`: `latest-only`
- `ciUpload`: `failure-only`, `none`
- `baselineStorage`: `git`, `git-lfs`

Size fields are byte counts for checked-in baseline PNGs only. They do not count generated `.build` artifacts.

## Tolerance Policy

```json
{
  "tolerancePolicy": {
    "default": {
      "dimensions": "exact",
      "pixels": "exact",
      "pngBytes": "ignored"
    },
    "configPath": "tests/BlockPreviewTests/visual-baselines.json",
    "cases": {
      "surface-active": {
        "maxDifferentPixelRatio": 0.001,
        "maxMeanChannelDelta": 1.5,
        "reason": "Full-surface preview may include minor AppKit shadow antialiasing."
      }
    }
  }
}
```

Rules:

- Default dimensions are exact.
- Default decoded pixels are exact.
- PNG byte differences are ignored.
- Per-case tolerance requires `reason`.
- No global broad tolerance in v1.

## Summary

```json
{
  "summary": {
    "total": 7,
    "passed": 6,
    "failed": 1,
    "missingBaseline": 0,
    "extraBaseline": 0,
    "platformMismatch": 0,
    "dimensionMismatch": 0,
    "pixelMismatch": 1,
    "renderFailed": 0,
    "unreadable": 0,
    "warnings": 0
  }
}
```

`failed` equals all non-`passed` result statuses except warnings. Warnings are counted separately.

## Results

```json
{
  "id": "quicksave-notes-and-captures",
  "kind": "block",
  "blockID": "quicksave",
  "fixture": "notes-and-captures",
  "status": "passed",
  "baselinePath": "tests/BlockPreviewTests/Baselines/quicksave-notes-and-captures.png",
  "currentPath": ".build/block-preview-current/quicksave-notes-and-captures.png",
  "diffPath": null,
  "pointSize": {
    "width": 420,
    "height": 520
  },
  "baselinePixels": {
    "width": 840,
    "height": 1040
  },
  "currentPixels": {
    "width": 840,
    "height": 1040
  },
  "comparison": {
    "differentPixels": 0,
    "differentPixelRatio": 0,
    "meanChannelDelta": 0,
    "maxChannelDelta": 0
  },
  "platformMismatches": [],
  "warnings": []
}
```

Allowed `kind` values:

- `block`
- `surface`
- `extraBaseline`

Allowed `status` values:

- `passed`
- `missingBaseline`
- `extraBaseline`
- `platformMismatch`
- `dimensionMismatch`
- `pixelMismatch`
- `renderFailed`
- `unreadable`

Use `null` for unavailable paths or metrics. Do not omit required result keys.

### Status Precedence

Classify each result in this order:

1. `renderFailed`
2. `unreadable`
3. `missingBaseline`
4. `extraBaseline`
5. `platformMismatch`
6. `dimensionMismatch`
7. `pixelMismatch`
8. `passed`

`platformMismatch` happens before dimension or pixel comparison when the platform or renderer metadata proves the current run is on the wrong lane. `dimensionMismatch` is for same-lane renderer output size changes.

## Full Minimal Example

```json
{
  "version": 1,
  "schema": "surface.visualbaselines.report.v1",
  "generatedAt": "2026-06-28T18:53:16Z",
  "mode": "check",
  "command": "swift run block-preview baseline-check",
  "paths": {
    "repoRoot": "${repoRoot}",
    "baselineDirectory": "tests/BlockPreviewTests/Baselines",
    "currentDirectory": ".build/block-preview-current",
    "diffDirectory": ".build/block-preview-diffs",
    "reportPath": ".build/surface-status/visualbaselines.json",
    "platformPath": "tests/BlockPreviewTests/Baselines/platform.json",
    "toleranceConfigPath": "tests/BlockPreviewTests/visual-baselines.json"
  },
  "platform": {
    "lane": "default",
    "minimumTarget": "macOS 14",
    "runnerLabel": "macos-15",
    "osName": "macOS",
    "osVersion": "15.5",
    "architecture": "arm64",
    "displayScale": 2,
    "baselinePlatformPath": "tests/BlockPreviewTests/Baselines/platform.json",
    "matchesBaselinePlatform": true,
    "mismatches": [],
    "warnings": []
  },
  "renderer": {
    "name": "AppKit.NSHostingView.cacheDisplay",
    "configuration": "baselineDefault",
    "scalePolicy": "fixed",
    "scale": 2,
    "appearance": "light",
    "colorScheme": "light",
    "localeIdentifier": "en_US_POSIX"
  },
  "artifactPolicy": {
    "localRetention": "latest-only",
    "ciUpload": "failure-only",
    "ciRetentionDays": 7,
    "baselineStorage": "git",
    "lfsRequired": false,
    "baselineBytes": 214832,
    "largestBaselineBytes": 48231,
    "warnings": []
  },
  "tolerancePolicy": {
    "default": {
      "dimensions": "exact",
      "pixels": "exact",
      "pngBytes": "ignored"
    },
    "configPath": "tests/BlockPreviewTests/visual-baselines.json",
    "cases": {}
  },
  "summary": {
    "total": 1,
    "passed": 1,
    "failed": 0,
    "missingBaseline": 0,
    "extraBaseline": 0,
    "platformMismatch": 0,
    "dimensionMismatch": 0,
    "pixelMismatch": 0,
    "renderFailed": 0,
    "unreadable": 0,
    "warnings": 0
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
      "pointSize": {
        "width": 420,
        "height": 520
      },
      "baselinePixels": {
        "width": 840,
        "height": 1040
      },
      "currentPixels": {
        "width": 840,
        "height": 1040
      },
      "comparison": {
        "differentPixels": 0,
        "differentPixelRatio": 0,
        "meanChannelDelta": 0,
        "maxChannelDelta": 0
      },
      "platformMismatches": [],
      "warnings": []
    }
  ],
  "warnings": []
}
```

## Source Evidence

- `visualbaselines-spec.md` already owns check/record commands and `.build/surface-status/visualbaselines.json`.
- `visualartifactretention-spec.md` already adds local/CI retention and baseline storage fields to the report.
- `baselineplatforms-spec.md` already adds platform lane metadata and `platformMismatch`.
- `rendererscalecontrol-spec.md` already adds renderer scale, appearance, locale, and pixel-output fields.
- JSON Schema documents a standard way to describe JSON document shape, supporting an exact v1 contract even if Surface starts with docs and Codable tests rather than a standalone schema file.
- Playwright visual comparison docs warn that host OS, settings, hardware, headless mode, and other factors affect visual output, supporting explicit platform/renderer metadata.
- Storybook visual tests and Point-Free SnapshotTesting validate test-owned snapshots/baselines as the right layer for UI image comparisons.
- GitHub artifact upload and XCTest attachments validate that current/diff/report artifacts belong to CI/tests, not a runtime plugin.

## Fixtures

Use JSON fixture files for report decoding tests:

- `passed-report`: one passing block result and no warnings.
- `pixel-mismatch`: one result with current, baseline, and diff paths.
- `platform-mismatch`: platform mismatch before dimension/pixel comparison.
- `missing-and-extra`: one missing baseline and one extra baseline.
- `render-failed`: failed render with null image paths and a warning.
- `retention-warning`: large baseline warning in `artifactPolicy`.
- `tolerance-config`: per-case tolerance with required reason.

## Tests

- Decode and encode the full report shape.
- Require all top-level keys.
- Reject unknown `mode`, `status`, `kind`, `scalePolicy`, `appearance`, and artifact-policy enum values.
- Preserve result ordering from `BlockPreview.cases` plus `surface-active`.
- Classify status precedence in the documented order.
- Count summary values from result statuses.
- Write paths relative to the repo root.
- Use `null`, not omitted keys, for unavailable paths or metrics.
- Include renderer, platform, artifact policy, and tolerance policy in every report.
- Verify `previewgallery` can read the report without mutating files.
- Verify no plugin runtime writes reports, creates lanes, uploads artifacts, or approves baselines.

## Implementation Notes

- Put report models in `BlockPreviewSupport` when implementing `visualbaselines`.
- Keep the model Codable and boring.
- If a formal JSON Schema file becomes useful, generate it from this contract or keep it under `tests/BlockPreviewTests/visualbaselines.schema.json`; do not create a separate schema registry.
- Prefer additive optional fields in future `version: 1` reports. Use `version: 2` for breaking field changes.
