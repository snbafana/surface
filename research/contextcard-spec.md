# `contextcard` Plugin Spec

## Why This Fits Surface

Surface opens over whatever the user is doing. A context card can make that moment useful by showing the active app/window and offering capture/copy/open actions without forcing an app switch.

The first version should not require Accessibility permission. It should ship with a useful no-permission mode and reserve AX APIs for a clearly labeled v2.

## v1 Product Boundary

No Accessibility prompt in v1.

Show:

- Frontmost app name.
- Bundle identifier.
- PID.
- Activation policy.
- Bundle/executable path if available.
- Best-effort window title from CoreGraphics if available.

Actions:

- Copy app name.
- Copy bundle identifier.
- Copy window title if present.
- Copy a compact context Markdown block.
- Reveal app bundle in Finder.

Do not read selected text in v1.
Do not control the target app in v1.
Do not install an event tap in v1.

## Source APIs

### App Identity

Use `NSWorkspace.shared.frontmostApplication`.

Apple describes this as the app receiving key events. It returns `NSRunningApplication?`.

Useful properties from `NSRunningApplication`:

- `localizedName`
- `bundleIdentifier`
- `processIdentifier`
- `bundleURL`
- `executableURL`
- `activationPolicy`

Refresh on:

- `NSWorkspace.didActivateApplicationNotification`
- `refresh()` when Surface opens

### Best-Effort Window Title

Use `CGWindowListCopyWindowInfo` with current-session/on-screen options, then match window dictionaries to the frontmost app PID.

Candidate keys:

- `kCGWindowOwnerPID`
- `kCGWindowOwnerName`
- `kCGWindowName`
- `kCGWindowLayer`
- `kCGWindowBounds`

Important constraint: `kCGWindowName` is optional and often missing. The UI should display `No window title` rather than treating it as an error.

## v2 Accessibility Path

Only add this after a visible permission row exists:

- Check trust with `AXIsProcessTrustedWithOptions`.
- Create the app AX element with `AXUIElementCreateApplication(pid)`.
- Read `kAXFocusedWindowAttribute` for exact focused window.
- Consider `kAXFocusedUIElementAttribute` for selected text/field context.

The block should have states:

- `Ready`
- `No active app`
- `Window title unavailable`
- `Accessibility not enabled`
- `Accessibility unavailable for this app`

## Runtime Shape

Target: `plugins/contextcard/source/Plugin.swift`

Runtime:

1. `start()`: install workspace activation observer and load current context.
2. `refresh()`: reload current context.
3. `stop()`: remove observer.
4. `makeView()`: render app/window context and action buttons.

Use dependency injection for tests:

```swift
struct ContextSnapshotReader {
    var read: @MainActor () -> ContextSnapshot
}
```

Keep `ContextSnapshotReader` plugin-local until another block needs it.

## Data Model Sketch

```swift
struct ContextSnapshot: Equatable, Sendable {
    var appName: String?
    var bundleIdentifier: String?
    var processIdentifier: Int32?
    var activationPolicy: String?
    var bundlePath: String?
    var executablePath: String?
    var windowTitle: String?
    var capturedAt: Date
    var permissionState: ContextPermissionState
}

enum ContextPermissionState: String, Sendable {
    case notNeeded
    case accessibilityMissing
    case accessibilityGranted
}
```

## Preview Fixtures

Fixtures:

- `empty`: no active app.
- `browser`: app name, bundle id, URL-like window title.
- `editor`: app name, file-like window title, bundle path.
- `no-window-title`: app info with missing window title.

Preview data can be a simple JSON file:

```json
{
  "appName": "Obsidian",
  "bundleIdentifier": "md.obsidian",
  "processIdentifier": 12345,
  "activationPolicy": "regular",
  "bundlePath": "/Applications/Obsidian.app",
  "windowTitle": "Surface Plugin Research.md",
  "capturedAt": 1764077400000,
  "permissionState": "notNeeded"
}
```

## UI Shape

Header:

- `Context`
- status pill: app name or `No app`

Body:

- Main row: app icon placeholder, app name, bundle id.
- Window row: title or `No window title`.
- Metadata: PID, activation policy, short path.
- Action buttons: copy context, copy title, copy bundle id, reveal app.

Keep action buttons icon-first and fixed-size.

## Test Plan

- Fixture JSON decodes into a snapshot.
- Missing window title renders non-error state.
- Markdown context formatter includes only present fields.
- Workspace activation observer is removed on stop.
- Preview fixtures render nonblank.

## Recommendation

Implement `contextcard` after `githubqueue` and `fileinbox`, unless the priority is making Surface feel context-aware. It is low-risk if v1 avoids AX and treats window title as best-effort.
