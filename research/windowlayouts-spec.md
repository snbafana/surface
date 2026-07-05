# `windowlayouts` Plugin Spec

## Why This Matters

Window placement is a proven daily macOS workflow. Raycast Window Management, Hammerspoon `hs.window`, Hammerspoon `hs.layout`, and the WindowHalfsAndThirds Spoon all validate quick actions such as left half, right half, thirds, center, maximize, and saved layouts.

For Surface, the value is not replacing a dedicated window manager. It is putting a small set of explicit layout actions in the overlay beside the user's context and queues.

## Existing Owner / Dedup Decision

- `permissionsdashboard` owns Accessibility permission status and the explicit request/open-settings flow.
- `contextcard` owns no-AX app/window identity snapshots.
- `SurfaceLayout` owns Surface's own overlay block grid, not user app windows.
- Hammerspoon/Rectangle/Raycast-style global hotkey command sets are separate products; Surface should not clone them in v1.
- `windowlayouts` owns only explicit, user-triggered focused-window move/resize actions and fixture-backed layout previews.

Do not add a second plugin registry, background tiling daemon, Lua bridge, global hotkey map, or automatic window organizer. Implement as one `BlockRuntime` using `Block.Context.storageDirectory` for previews/tests.

## Product Boundary

It should:

- Show a small focused-window action pad: left half, right half, top half, bottom half, thirds, center, maximize, restore.
- Show blocked state when Accessibility is missing.
- Let the user save the current focused-window frame as a named preset.
- Let the user apply named presets to the current focused window.
- Persist presets locally and read fixtures in preview mode.
- Keep every move/resize behind an explicit click or button action.

It should not:

- Move windows automatically on app launch, app activation, or display changes.
- Install global hotkeys in v1.
- Launch apps, open documents, or move windows between Spaces.
- Toggle native fullscreen or manage Stage Manager groups in v1.
- Enumerate and rearrange every app/window on the desktop in v1.
- Use AppleScript or Hammerspoon as a hidden backend.

## First Version

### Data Modes

Fixture mode:

1. Read `Block.Context.storageDirectory/windowlayouts-layouts.json`.
2. Read `Block.Context.storageDirectory/windowlayouts-snapshot.json`.
3. Render presets, focused-window metadata, and result states.
4. Do not call Accessibility APIs.
5. All apply/save actions become preview no-ops with visible `Preview` status.

Live mode:

1. Check Accessibility through the same pattern as `permissionsdashboard`.
2. If missing, render blocked state and route the user to `permissionsdashboard`.
3. Read the frontmost app through `NSWorkspace.shared.frontmostApplication`.
4. Create the app AX element with `AXUIElementCreateApplication(pid)`.
5. Read the focused window with `kAXFocusedWindowAttribute`.
6. Read window position and size with `AXUIElementCopyAttributeValue`.
7. Set position and size with `AXUIElementSetAttributeValue`.

Keep the AX adapter plugin-local until `contextcard` v2 or another plugin needs the same mutation path.

### Layout Math

Use `NSScreen.visibleFrame` for target screen bounds so presets avoid the menu bar and Dock.

For the focused window:

1. Read current `CGPoint` and `CGSize`.
2. Pick the screen whose visible frame contains the window center; fallback to main screen.
3. Apply gap from config, default `8`.
4. Convert unit rects into target `CGPoint` and `CGSize`.
5. Clamp target frame to the screen visible frame.

Core presets:

| ID | Unit Rect |
| --- | --- |
| `left-half` | `{x: 0, y: 0, width: 0.5, height: 1}` |
| `right-half` | `{x: 0.5, y: 0, width: 0.5, height: 1}` |
| `top-half` | `{x: 0, y: 0, width: 1, height: 0.5}` |
| `bottom-half` | `{x: 0, y: 0.5, width: 1, height: 0.5}` |
| `center` | current size centered in visible frame |
| `maximize` | visible frame minus gap |
| `left-third` | `{x: 0, y: 0, width: 0.3333, height: 1}` |
| `middle-third` | `{x: 0.3333, y: 0, width: 0.3333, height: 1}` |
| `right-third` | `{x: 0.6667, y: 0, width: 0.3333, height: 1}` |

Do not implement cycles, multi-display movement, Spaces movement, or fullscreen toggles in v1. They are useful, but they add state and troubleshooting surface before the basic AX path is proven.

### Data Model

```swift
struct WindowLayoutsFile: Codable {
    var version: Int
    var gap: Double
    var presets: [WindowPreset]
    var savedFrames: [SavedWindowFrame]
}

struct WindowPreset: Codable, Identifiable, Equatable {
    var id: String
    var title: String
    var kind: PresetKind
    var unitRect: UnitRect?
}

enum PresetKind: String, Codable {
    case unitRect
    case center
    case maximize
    case restore
}

struct SavedWindowFrame: Codable, Identifiable, Equatable {
    var id: String
    var title: String
    var bundleIdentifier: String?
    var windowTitle: String?
    var frame: StoredFrame
    var savedAt: Date
}

struct WindowSnapshot: Codable, Equatable {
    var appName: String?
    var bundleIdentifier: String?
    var windowTitle: String?
    var frame: StoredFrame?
    var screenVisibleFrame: StoredFrame?
    var accessibility: AccessibilityState
    var lastResult: LayoutResult?
}
```

Saved frames apply to the focused window only in v1. Matching bundle/title can be shown as a warning, not used to hunt for background windows.

### Actions

- Apply preset to focused window.
- Save current focused-window frame.
- Restore previous frame from runtime memory or last saved state.
- Copy window/frame summary.
- Open permissions dashboard when blocked.

Each action should surface an immediate result:

- `Applied`
- `Preview only`
- `Needs Accessibility`
- `No focused window`
- `Unsupported window`
- `Move failed`

## UI Shape

Header:

- `Windows`
- status pill: focused app, `Needs access`, or `No window`

Body:

- Focused app/window summary from snapshot.
- Fixed grid of icon buttons for halves/thirds/center/maximize/restore.
- Saved preset rows with apply/copy actions; delete can be deferred until preset persistence is fully tested.
- Compact warning row for unsupported/fullscreen/no-AX states.

Keep action buttons fixed-size. Do not resize the block when result text changes.

## Runtime Shape

Target: `plugins/windowlayouts/source/Plugin.swift`

Runtime:

1. `start()`: load presets and current snapshot.
2. `refresh()`: reload focused window and permission state.
3. `stop()`: no-op.
4. `makeView()`: render snapshot, presets, blocked states, and action buttons.

Use:

- `NSWorkspace.shared.frontmostApplication` for front app.
- `AXIsProcessTrustedWithOptions(nil)` for status.
- `AXUIElementCreateApplication(pid)` for app element.
- `AXUIElementCopyAttributeValue` for focused window, position, and size.
- `AXUIElementSetAttributeValue` for position and size.
- `NSScreen.visibleFrame` for screen bounds.

## Fixture Plan

Fixtures:

- `blocked-accessibility`: preset grid plus `Needs Accessibility`.
- `focused-window`: app/window frame with layout actions available as preview no-ops.
- `saved-presets`: several named saved frames.
- `unsupported-window`: AX present but no focused window/frame.

Example files:

- `windowlayouts-layouts.json`
- `windowlayouts-snapshot.json`

Preview fixtures should model results without moving real windows.

## Test Plan

- Fixture decode and state rendering.
- Unit-rect layout math for halves/thirds/maximize with gap and visible frame.
- Center preset preserves current size and clamps to visible frame.
- Missing Accessibility renders blocked state and no move action.
- AX errors map to visible result states.
- Preview apply/save actions are no-ops.
- Preview fixtures render nonblank PNGs through `Blocks.registry`.

## Recommendation

Implement after `permissionsdashboard` and ideally after `contextcard` v1. If implemented earlier, ship fixture-only or blocked-state-first. Live move/resize should not ship until Accessibility status is visible and failure states are clear.
