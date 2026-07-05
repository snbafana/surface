# `appquicklaunch` Plugin Spec

## Why This Matters

Launchers are useful when they collapse a repeated app/file/URL jump into one explicit action. Raycast Quicklinks and Hammerspoon app launch helpers validate the pattern, but a broad launcher quickly becomes root search, Spotlight indexing, keyboard automation, app scripting, and workspace restoration.

The useful Surface version is smaller: show a curated board of user-declared launch targets and open/focus exactly one target from an explicit row action. It should feel like a command shelf for the user's current work, not a replacement for Raycast, Spotlight, Dock, Finder, Hammerspoon, or Keyboard Maestro.

## Existing Owner / Dedup Decision

- `contextcard` owns frontmost app/window identity and active-context snapshots.
- `fileinbox` owns recent file/screenshot/download triage.
- `linkinbox` owns durable URL capture, dedupe, archive, and metadata.
- `bookmarkcards` owns curated read-later/bookmark shelves.
- `windowlayouts` owns focused-window movement and saved frame presets.
- `hammerspoonbridge` and `keyboardmaestrobridge` own external automation manifests and predeclared trigger handoffs.
- `scriptoutput` owns arbitrary executables and command output.
- `appquicklaunch` owns only curated launch cards, target resolution, and explicit open/focus/reveal/copy actions.

Do not add a root search index, Spotlight query layer, app-scanning registry, global hotkeys, selected-text capture, browser autofill, shell commands, AppleScript, Shortcuts, macro execution, menu-item selection, multi-app workspace restore, window movement, recent-file triage, URL inbox behavior, bookmark import, or second plugin registry.

## Product Boundary

It should:

- Read launch cards from `appquicklaunch-items.json`.
- Show pinned/recent/grouped launch rows.
- Resolve app targets by bundle identifier or app URL.
- Resolve file/folder targets by explicit URL/path.
- Resolve URL/deeplink targets by explicit URL string.
- Open/focus exactly one row when the user presses a row action.
- Copy target URL/path/bundle identifier.
- Reveal file, folder, or app bundle in Finder.
- Show missing/blocked states inline.

It should not:

- Enumerate every installed app.
- Search the file system or Spotlight.
- Track most-used apps passively.
- Read browser tabs, selected text, clipboard text, or front-document URLs.
- Create dynamic query placeholders.
- Run terminal commands, scripts, workflows, macros, or AppleScript.
- Apply window layouts after launch.
- Launch groups of apps as a workspace in v1.
- Mutate Dock, Finder sidebar, Login Items, or system shortcuts.

## First Version

### Data Modes

Fixture mode:

1. Read `Block.Context.storageDirectory/appquicklaunch-items.json`.
2. Render all target types from fixture data.
3. Treat open/focus/reveal actions as preview no-ops.
4. Do not call `NSWorkspace` during previews/tests except through injected fakes.

Live mode:

1. Read `~/Library/Application Support/Surface/AppQuickLaunch/appquicklaunch-items.json`.
2. Use AppKit only from explicit user actions.
3. Resolve app bundle identifiers lazily when displaying or launching a row.
4. Respect `Block.Context.allowsExternalWrites` for open/focus/reveal actions.
5. Persist only row-local `lastOpenedAt`/`openCount` if writes are enabled.

### State File

```json
{
  "version": 1,
  "updatedAt": "2026-06-22T02:27:23Z",
  "items": [
    {
      "id": "obsidian-daily",
      "title": "Obsidian Daily",
      "subtitle": "Open today's notes workspace",
      "kind": "app",
      "bundleIdentifier": "md.obsidian",
      "appPath": "/Applications/Obsidian.app",
      "section": "Writing",
      "tags": ["notes", "daily"],
      "pinned": true,
      "lastOpenedAt": "2026-06-22T01:50:00Z",
      "openCount": 12
    },
    {
      "id": "surface-project",
      "title": "Surface Project",
      "kind": "folder",
      "url": "file:///Users/snbafana/Documents/personal/Scratch/projects/surface/",
      "openWithBundleIdentifier": "com.microsoft.VSCode",
      "section": "Projects",
      "tags": ["swift", "surface"],
      "pinned": true
    },
    {
      "id": "codex-log",
      "title": "Codex Log",
      "kind": "url",
      "url": "surface://codex-log",
      "section": "Surface",
      "pinned": false
    }
  ]
}
```

### Target Kinds

- `app`: launch/focus an app by bundle identifier first, then app path fallback.
- `file`: open a file using default app or configured `openWithBundleIdentifier`.
- `folder`: open/reveal a folder using default app or configured `openWithBundleIdentifier`.
- `url`: open an HTTP(S), file, or app/deeplink URL.
- `settings`: later, only for explicit `x-apple.systempreferences:` URLs already present in the JSON.

Do not infer target kinds from arbitrary strings at runtime. Decode and validate the fixture/live JSON into typed target values.

### Local Data Model

```swift
struct AppQuickLaunchState: Codable, Equatable {
    var version: Int
    var updatedAt: Date
    var items: [AppQuickLaunchItem]
}

struct AppQuickLaunchItem: Identifiable, Codable, Equatable {
    var id: String
    var title: String
    var subtitle: String?
    var target: AppQuickLaunchTarget
    var section: String?
    var tags: [String]
    var pinned: Bool
    var lastOpenedAt: Date?
    var openCount: Int
}

enum AppQuickLaunchTarget: Codable, Equatable {
    case app(bundleIdentifier: String?, appPath: String?)
    case file(url: URL, openWithBundleIdentifier: String?)
    case folder(url: URL, openWithBundleIdentifier: String?)
    case url(URL)
}

struct AppQuickLaunchResolution: Equatable {
    var displayTarget: String
    var status: AppQuickLaunchStatus
    var resolvedAppURL: URL?
}

enum AppQuickLaunchStatus: String, Equatable {
    case ready
    case missingApp
    case missingFile
    case invalidURL
    case blockedExternalAction
}
```

Use custom decoding if it keeps the JSON flat and easy to edit by hand.

## Implementation Notes

Use AppKit directly:

- `NSWorkspace.urlForApplication(withBundleIdentifier:)` to resolve configured app bundle identifiers.
- `NSWorkspace.openApplication(at:configuration:completionHandler:)` to launch app bundles by URL.
- `NSRunningApplication.runningApplications(withBundleIdentifier:)` and `activate(options:)` to focus an already-running app.
- `NSWorkspace.open(_:withApplicationAt:configuration:completionHandler:)` for files/folders opened with a configured app.
- `NSWorkspace.open(_:)` for URL/deeplink/default-open behavior.
- `NSWorkspace.activateFileViewerSelecting(_:)` for reveal actions.

Keep the launcher adapter plugin-local until `contextcard`, `fileinbox`, or `bookmarkcards` prove they need the same open/focus/reveal adapter. The likely shared extraction is a tiny `WorkspaceOpening` protocol, not a new launcher service or registry.

## Display Rules

Header:

- `Quick Launch`
- total visible rows
- optional `Pinned` count
- blocked/missing count if any target is invalid

Rows:

- target icon or kind swatch
- title
- subtitle or short target path/host/bundle id
- section/tag chips only when compact
- stale/missing warning if resolution fails
- fixed-size icon buttons: open/focus, reveal, copy target

Sort:

1. pinned rows
2. rows matching the current `contextcard` app if a future explicit context snapshot is supplied
3. most recently opened rows
4. section/title stable fallback

Do not add a text search field in v1. If filtering becomes necessary, filter only the loaded JSON rows inside the block; do not query Spotlight or installed apps.

## Actions

- Open/focus app.
- Open file/folder/URL.
- Open file/folder with configured app.
- Reveal app/file/folder in Finder.
- Copy path/URL/bundle identifier.
- Copy a Markdown link for file/URL rows.
- Mark pin/unpin only if writes are enabled.

No action should run scripts, execute macros, call `open` through a shell, select menu items, move windows, scrape active app state, or mutate external app settings.

## UI Shape

Top region:

- section picker or compact pinned/recent segmented control
- row count and warning pill

Main region:

- pinned group
- project/app group
- utility/deeplink group

Empty state:

- `No launch cards`
- show expected JSON filename and no action prompts that create global search/indexing.

Blocked states:

- `App missing`
- `File missing`
- `External actions disabled`
- `Invalid URL`

## Runtime Shape

Target: `plugins/appquicklaunch/source/Plugin.swift`

Runtime:

1. `start()`: load state and resolve visible rows with injected workspace adapter.
2. `refresh()`: reload JSON and re-resolve targets.
3. `open(itemID:)`: run one explicit open/focus action.
4. `copyTarget(itemID:)`: write target text to pasteboard.
5. `reveal(itemID:)`: reveal app/file/folder if supported.
6. `stop()`: no-op.
7. `makeView()`: render grouped launch cards.

The app/file/URL opener should be a small injected adapter so tests can assert requested actions without launching apps.

## Fixture Plan

Fixtures:

- `empty`: no configured items.
- `apps-ready`: several apps with bundle identifiers and paths.
- `project-files`: folders/files with `openWithBundleIdentifier`.
- `urls-and-deeplinks`: HTTP URL plus local app URL schemes.
- `missing-targets`: missing app and missing file warnings.
- `external-actions-blocked`: rows ready but action buttons blocked/no-op.

## Test Plan

- JSON decodes into typed target values.
- Missing/invalid URLs produce row errors without crashing.
- App resolution uses bundle identifier before path fallback.
- File/folder rows preserve explicit `openWithBundleIdentifier`.
- Fixture mode does not launch, focus, reveal, or call real `NSWorkspace`.
- `allowsExternalWrites == false` blocks open/focus/reveal but still allows read-only display.
- Copy actions format path, URL, bundle id, and Markdown link deterministically.
- Duplicate item ids are rejected or de-duplicated with a visible warning.
- Sorting is stable for pinned/recent/section/title.
- Preview fixtures render nonblank PNGs through `Blocks.registry`.

## Recommendation

Implement `appquicklaunch` only as a curated local launch shelf. It should complement `contextcard`, `fileinbox`, `linkinbox`, and `bookmarkcards` by opening explicit targets the user already chose. Anything searchable, programmable, selected-text-driven, browser-aware, macro-backed, or workspace-restoring belongs to an existing owner or a later spec.
