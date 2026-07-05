# `rendererscalecontrol` Spec

## Decision

Do not build `rendererscalecontrol` as a Surface plugin, platform-lane registry, preview renderer, or baseline manager. Implement it as a small render configuration owned by the existing `BlockImageRenderer` and passed through `BlockPreview.render`, `BlockPreview.renderAll`, `BlockPreview.renderSurface`, and future `visualbaselines` commands.

Yes: `BlockImageRenderer` should accept explicit scale, appearance, and locale configuration before any second visual-baseline platform lane is allowed. A second baseline lane is justified only after fixed renderer inputs still produce stable, legitimate differences across supported platforms.

## Existing Owner / Dedup Decision

- `BlockImageRenderer` owns SwiftUI/AppKit view-to-PNG rendering.
- `BlockPreview` owns fixture rendering through `Blocks.registry`, `Block.Context`, and `BlockRuntime.makeView()`.
- `visualbaselines` owns check/record commands, image comparison, and `visualbaselines.json`.
- `baselineplatforms` owns platform metadata and the rule for when multiple baseline lanes are allowed.
- `BlockPreviewTests` owns preview smoke tests and later visual-baseline enforcement.
- `rendererscalecontrol` owns only render-input configuration and report metadata for scale, appearance, locale, and color scheme.

Do not put renderer settings into `Block.Context`: plugins should remain deterministic through their storage, clock, and permission gates. Scale, appearance, and locale are preview harness inputs, not plugin runtime state.

## Product Boundary

It should:

- Add a render configuration type in `BlockPreviewSupport`.
- Pass the configuration from `BlockPreview` functions to `BlockImageRenderer`.
- Support a fixed renderer scale for deterministic baseline PNG dimensions.
- Support explicit `light`, `dark`, and `system` appearance choices.
- Apply matching SwiftUI color scheme for light/dark preview renders.
- Support explicit locale identifiers such as `en_US_POSIX`.
- Record renderer configuration and output pixel dimensions in future `visualbaselines.json`.
- Add CLI options for ad hoc previews: `--scale`, `--appearance`, and `--locale`.
- Make future `baseline-check` and `baseline-record` use a stable baseline default, not the current system appearance or locale.

It should not:

- Add a `rendererscalecontrol` `BlockRuntime`, registry entry, overlay panel, daemon, service, fixture registry, or baseline lane registry.
- Change live overlay rendering.
- Set global `NSApp.appearance`, mutate system appearance, change user locale, write user defaults, or inspect system settings beyond metadata.
- Resample a rendered PNG after the fact to fake a fixed scale.
- Hide scale differences behind broad pixel tolerances.
- Add per-scale, per-display, per-font, per-user, or per-machine baselines before measured need.
- Use shell commands, ImageMagick, browser automation, hosted visual-test services, or screenshot APIs.
- Let `previewgallery` record, approve, switch, or mutate renderer settings.

## First Version

### Render Configuration

Add one small configuration type beside `BlockImageRenderer`:

```swift
public struct BlockRenderConfiguration: Hashable, Sendable {
    public var scale: BlockRenderScale
    public var appearance: BlockRenderAppearance
    public var localeIdentifier: String
}

public enum BlockRenderScale: Hashable, Sendable {
    case actual
    case fixed(Double)
}

public enum BlockRenderAppearance: String, Hashable, Sendable {
    case system
    case light
    case dark
}
```

Recommended defaults:

```swift
extension BlockRenderConfiguration {
    public static let previewDefault = BlockRenderConfiguration(
        scale: .actual,
        appearance: .system,
        localeIdentifier: Locale.current.identifier
    )

    public static let baselineDefault = BlockRenderConfiguration(
        scale: .fixed(2.0),
        appearance: .light,
        localeIdentifier: "en_US_POSIX"
    )
}
```

`previewDefault` preserves the current ad hoc preview behavior. `baselineDefault` is the deterministic default for future visual-baseline commands.

### Renderer API

Extend the renderer API without removing the current call style:

```swift
public enum BlockImageRenderer {
    @MainActor
    public static func pngData(
        for view: AnyView,
        size: CGSize,
        configuration: BlockRenderConfiguration = .previewDefault
    ) throws -> Data
}
```

Use the current `NSHostingView` and `cacheDisplay` path. Apply configuration before layout:

- Wrap the SwiftUI view with `.environment(\.locale, Locale(identifier: configuration.localeIdentifier))`.
- For `light`, apply SwiftUI `.environment(\.colorScheme, .light)` and `NSAppearance(named: .aqua)` to the host.
- For `dark`, apply SwiftUI `.environment(\.colorScheme, .dark)` and `NSAppearance(named: .darkAqua)` to the host.
- For `system`, do not override appearance or color scheme.
- For `.actual`, preserve the existing `bitmapImageRepForCachingDisplay` behavior and record the resulting pixel size.
- For `.fixed(scale)`, render directly into a bitmap whose `pixelsWide` and `pixelsHigh` equal `round(pointSize * scale)`, set `bitmap.size` to the point size, and fail if the resulting PNG dimensions differ.

Do not render at one scale and resize the PNG afterward. Pixel dimensions are renderer output, not a post-processing artifact.

### CLI Options

Extend `block-preview` options:

```bash
swift run block-preview quicksave --fixture notes-and-captures --scale 2 --appearance light --locale en_US_POSIX
swift run block-preview all --scale 2 --appearance light --locale en_US_POSIX
swift run block-preview surface --size 1440x900 --scale 2 --appearance light --locale en_US_POSIX
```

Accepted values:

- `--scale actual`
- `--scale 1`
- `--scale 2`
- `--appearance system`
- `--appearance light`
- `--appearance dark`
- `--locale <identifier>`

Invalid values should fail fast with a CLI error rather than silently falling back.

### Visual-Baseline Metadata

Future `visualbaselines.json` should record renderer input and output:

```json
{
  "renderer": {
    "name": "AppKit.NSHostingView.cacheDisplay",
    "scalePolicy": "fixed",
    "scale": 2,
    "appearance": "light",
    "localeIdentifier": "en_US_POSIX",
    "pointWidth": 420,
    "pointHeight": 520,
    "pixelsWide": 840,
    "pixelsHigh": 1040
  }
}
```

When `scalePolicy` is `fixed`, display scale is observed platform metadata, not a baseline-lane discriminator. Compare renderer scale and pixel dimensions first.

## Interaction With `baselineplatforms`

`rendererscalecontrol` is a prerequisite for any second platform lane:

1. Add fixed renderer inputs.
2. Record renderer config in visual-baseline reports.
3. Pin the CI runner and compare platform metadata.
4. Re-run baseline checks.
5. Add a second platform lane only if fixed scale, fixed light/dark appearance, fixed locale, and fixed fixture data still produce repeated stable platform-specific differences.

This keeps platform lanes from becoming a workaround for uncontrolled renderer inputs.

## Source Evidence

- Current `BlockImageRenderer` uses `NSHostingView`, `bitmapImageRepForCachingDisplay`, and `cacheDisplay` with no explicit renderer configuration.
- `baselineplatforms-spec.md` already requires scale, appearance, and locale metadata, and says to prefer renderer determinism before adding platform lanes.
- Apple high-resolution drawing guidance separates point-based layout from pixel backing stores and scale factors.
- Apple documents `NSScreen.backingScaleFactor` as the screen-to-backing-store scale factor, which explains why actual screen scale should be measured but not treated as a UI change.
- Apple `NSBitmapImageRep` initialization accepts explicit pixel width and pixel height, giving the renderer an owner-local way to make output dimensions exact.
- Apple `NSView.cacheDisplay(in:to:)` draws a view subtree into an `NSBitmapImageRep`, which is the current rendering family Surface already uses.
- Apple `NSAppearance.Name` defines standard light and dark system appearances.
- SwiftUI environment values include `locale` and `colorScheme`, so previews can set them without changing global system state.

## Tests

- Rendering with default configuration preserves current preview behavior.
- Rendering with `.fixed(1.0)` produces exact point-sized pixel dimensions.
- Rendering with `.fixed(2.0)` produces exact doubled pixel dimensions.
- Invalid fixed scales such as zero, negative, NaN, or infinite fail before rendering.
- `light` and `dark` appearances apply both AppKit appearance and SwiftUI color scheme.
- Locale identifiers are passed into the SwiftUI environment without changing global locale.
- CLI parsing accepts `--scale`, `--appearance`, and `--locale`.
- Future `baseline-check` records renderer configuration and exact output dimensions.
- `platformMismatch` uses renderer scale when fixed scale is present, not current display scale.
- No plugin runtime or preview gallery mutates renderer settings, records baselines, creates lanes, or changes system preferences.

## Implementation Notes

- Keep the configuration type in `BlockPreviewSupport` until another owner proves it needs to share it.
- Keep the first fixed-scale implementation small and testable; exact pixel dimensions matter more than broad rendering cleverness.
- If fixed bitmap allocation proves incompatible with `NSHostingView.cacheDisplay`, report a renderer failure and keep `.actual` behavior available for ad hoc previews.
- Do not add a second baseline lane to compensate for missing scale, appearance, or locale control.
