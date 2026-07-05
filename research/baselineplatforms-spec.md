# `baselineplatforms` Spec

## Decision

Do not build `baselineplatforms` as a Surface plugin, matrix manager, or second baseline registry. Implement it as platform policy inside the `visualbaselines` harness.

Start with one checked-in baseline lane. Pin CI to a concrete macOS runner label instead of `macos-latest`, record platform metadata in `visualbaselines.json`, and treat platform drift as a visible warning or failure until measured evidence shows that multiple baseline lanes are necessary.

Use the existing `BlockPreview.renderAll`, `BlockPreview.renderSurface`, `Block.Context`, and `BlockRuntime.makeView()` path. No `BlockRuntime` should choose, record, approve, normalize, or switch visual baseline platforms.

## Existing Owner / Dedup Decision

- `visualbaselines` owns baseline check/record commands, comparison logic, and `visualbaselines.json`.
- `visualartifactretention` owns generated artifact retention and CI upload policy.
- `BlockPreviewTests` owns baseline enforcement when added.
- `BlockImageRenderer` owns AppKit/SwiftUI-to-PNG rendering behavior.
- CI workflow files own runner labels and matrix shape.
- `previewgallery` owns read-only display of baseline reports and artifacts.
- `diagnosticbundle` owns explicit export of selected reports/images.
- `baselineplatforms` owns only platform-lane policy, platform metadata fields, mismatch classification, and the rule for when to add more lanes.

If implementation needs runner matrix expansion, do it in CI workflow configuration and `visualbaselines` report metadata. Do not create a platform registry, plugin, UI approval queue, or runtime platform switcher.

## Product Boundary

It should:

- Keep one default baseline lane in v1.
- Record platform metadata for every check and record run.
- Pin CI visual-baseline checks to a concrete macOS runner label.
- Avoid `macos-latest` for baseline enforcement.
- Compare current metadata against baseline metadata before interpreting pixel diffs.
- Emit `platformMismatch` when OS, architecture, renderer scale, or expected pixel dimensions do not match the baseline lane.
- Allow local developer checks to produce current/diff artifacts even when platform metadata differs.
- Add a second lane only after repeated measured mismatches prove that platform variance is legitimate and stable.

It should not:

- Add a `baselineplatforms` block, runtime, registry entry, daemon, service, or platform database.
- Maintain per-user or per-machine baselines.
- Automatically create new baseline lanes on mismatch.
- Let `previewgallery` record, approve, switch, or delete platform lanes.
- Use `macos-latest` as the authoritative visual-baseline runner.
- Add per-architecture, per-display, per-scale, or per-font baselines before measured need.
- Hide platform differences behind broad pixel tolerances.
- Use shell commands or external tools only to learn platform metadata.
- Duplicate `visualbaselines`, `visualartifactretention`, CI, `previewgallery`, or `diagnosticbundle` responsibilities.

## First Version

### Baseline Lane

Store checked-in baselines in the existing path:

```text
tests/BlockPreviewTests/Baselines/
```

Add an optional metadata file:

```text
tests/BlockPreviewTests/Baselines/platform.json
```

Example:

```json
{
  "version": 1,
  "lane": "default",
  "platform": {
    "minimumTarget": "macOS 14",
    "runnerLabel": "macos-15",
    "osName": "macOS",
    "osVersion": "15.5",
    "architecture": "arm64",
    "renderer": "AppKit.NSHostingView.bitmapImageRepForCachingDisplay",
    "scalePolicy": "actual-renderer-output",
    "displayScale": 2,
    "appearance": "light",
    "locale": "en_US_POSIX"
  }
}
```

The exact runner label should be the concrete label configured in CI. If that label changes, update this file and record baselines deliberately.

### Report Metadata

Extend `visualbaselines.json`:

```json
{
  "platform": {
    "lane": "default",
    "runnerLabel": "macos-15",
    "osVersion": "15.5",
    "architecture": "arm64",
    "displayScale": 2,
    "scalePolicy": "actual-renderer-output",
    "appearance": "light",
    "locale": "en_US_POSIX",
    "matchesBaselinePlatform": true,
    "warnings": []
  }
}
```

Collect metadata with Swift/Foundation/AppKit APIs where possible:

- `ProcessInfo.processInfo.operatingSystemVersion`
- compile-time architecture checks
- `NSScreen.main?.backingScaleFactor` when a screen is available
- rendered PNG width/height from `BlockPreviewMetricsReader`

Do not shell out for platform metadata in the core harness.

### Status Rules

Add `platformMismatch` to `visualbaselines` result statuses.

`platformMismatch` should happen before pixel interpretation when:

- OS major version differs from `platform.json`
- architecture differs
- expected rendered pixel dimensions differ
- display/renderer scale differs and the renderer still depends on screen scale

Warn, but do not fail by default, when:

- patch OS version differs
- runner label differs but OS/architecture/scale match
- locale cannot be detected deterministically
- display scale is unavailable in headless/local contexts

CI can choose to fail on warnings later, but v1 should distinguish "wrong lane" from "UI changed."

### Multiple Lane Rule

Do not add multiple lanes until all of these are true:

1. The same UI state produces stable but different pixels across two platform classes.
2. Differences are not fixed by renderer scale control, fixed appearance, fixed locale, or tighter fixture data.
3. The second platform is a real supported CI/developer lane, not a one-off local machine.
4. The maintenance cost is accepted in docs and tests.

If a second lane is added, use explicit directories:

```text
tests/BlockPreviewTests/Baselines/macos15-arm64-scale2/
tests/BlockPreviewTests/Baselines/macos16-arm64-scale2/
```

Do not use auto-generated lane names or per-machine names.

## Source Evidence

- Surface currently targets macOS 14+ in `Package.swift`.
- `BlockPreview.renderSurface` uses `NSScreen.main?.visibleFrame` for live canvas size, so screen/display context can affect preview dimensions.
- `BlockImageRenderer` renders through `NSHostingView` and `bitmapImageRepForCachingDisplay`, which is AppKit-backed rather than a platform-neutral rasterizer.
- Apple high-resolution drawing guidance distinguishes point coordinates from pixel backing stores and scale factors.
- Apple documents `NSScreen.backingScaleFactor` as the scale factor converting screen coordinates to backing store coordinates.
- GitHub Actions runner docs define standard hosted runners and labels, including macOS runners, and warn that labels identify runner environments.
- GitHub-hosted runner image docs show macOS images change over time, which is why visual baseline CI should pin a concrete label instead of relying on `macos-latest`.
- Playwright and Storybook visual-testing docs treat browser/OS/rendering environment as part of the visual snapshot discipline, supporting metadata and pinned lanes before broad tolerance.

## Tests

- Decode `platform.json`.
- Generate platform metadata in `visualbaselines.json`.
- Classify exact platform match.
- Classify OS major mismatch as `platformMismatch`.
- Classify architecture mismatch as `platformMismatch`.
- Classify rendered pixel dimension mismatch as `platformMismatch`.
- Warn on OS patch mismatch.
- Verify `baseline-check` reports platform mismatch before pixel mismatch.
- Verify `baseline-record` updates platform metadata only from explicit recording.
- Verify `previewgallery` can read platform metadata without mutating baselines.
- Verify no plugin runtime creates lanes, switches lanes, records baselines, or changes CI labels.

## Implementation Notes

- Start single-lane and boring.
- Prefer making `BlockImageRenderer` deterministic over adding platform lanes.
- If scale variance appears, first consider an explicit renderer scale option in `visualbaselines`, not a new plugin.
- Keep platform metadata in the report even before enforcing it; measurement comes first.
- Do not add CI matrix lanes until repeated failures make the maintenance cost unavoidable.
