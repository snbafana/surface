# `workspacepins` Plugin Spec

## Why This Matters

Many Surface workflows are project-shaped: a root folder, a few launch targets, a current app/window, useful bookmarks, recent files, notes, and a next action. A workspace card can make those project anchors visible without forcing the user to remember where each thing lives.

The danger is that "workspace" often means session restore: launch several apps, move windows, switch Spaces, open tabs, run terminals, start builds, and rebuild a desktop. That is the wrong first version for Surface. `workspacepins` should be a read-mostly project dashboard over curated local records, not a window/session manager.

## Existing Owner / Dedup Decision

- `appquicklaunch` owns single app/file/folder/URL/deeplink launch targets and open/focus/reveal/copy actions.
- `fileinbox` owns recent-file scanning and triage.
- `contextcard` owns frontmost app/window identity and any future selected-text snapshot.
- `bookmarkcards` owns curated bookmark/read-later shelves.
- `linkinbox` owns URL capture, dedupe, and pending/archive triage.
- `windowlayouts` owns focused-window movement and saved frame presets.
- `scriptoutput` owns build/test/terminal/script execution.
- `localbuildstatus` owns repo/build status display from external result files.
- `hammerspoonbridge` and `keyboardmaestrobridge` own external automation manifests and trigger handoffs.
- `workspacepins` owns only curated workspace/project cards, lightweight local summaries, and explicit one-at-a-time open/copy/reveal handoffs.

Do not add multi-app session restore, Space/Desktop switching, Stage Manager control, window movement, tab restore, terminal command execution, build/test execution, git operations, app indexing, Spotlight search, recent-file scanning, URL capture, bookmark import, browser session capture, macro/script triggers, background agents, or a second plugin registry.

## Product Boundary

It should:

- Read `workspacepins-workspaces.json`.
- Show one card per curated workspace/project.
- Show configured root path, primary app/launch label, relevant links/bookmarks, local note path, and optional recent-file snapshot.
- Highlight when the current `contextcard` snapshot matches a workspace bundle id/path.
- Open or reveal one configured target per explicit user action.
- Copy a Markdown workspace summary.
- Show stale/missing references inline.

It should not:

- Launch multiple apps/URLs/files from one button in v1.
- Restore windows, tabs, Spaces, Stage Manager groups, or desktops.
- Scan the filesystem for recent files; consume explicit cached/snapshot rows only.
- Read other plugin stores by default unless the path is explicitly declared.
- Run `git`, `swift`, `npm`, shells, scripts, Shortcuts, AppleScript, macros, or Hammerspoon Lua.
- Mutate `appquicklaunch`, `fileinbox`, `bookmarkcards`, `linkinbox`, or `contextcard` stores.
- Become a global project search, project registry, or "workspace app" framework.

## First Version

### Data Modes

Fixture mode:

1. Read `Block.Context.storageDirectory/workspacepins-workspaces.json`.
2. Read optional `workspacepins-context.json` for deterministic current-context matching.
3. Read optional `workspacepins-recent-files.json` for cached recent-file rows.
4. Do not scan real folders or open real apps/files/URLs.

Live mode:

1. Read `~/Library/Application Support/Surface/WorkspacePins/workspacepins-workspaces.json`.
2. Optionally read explicit cached files written by other owners, only when configured by absolute path in the workspace record.
3. Resolve file existence and lightweight resource metadata only for configured root/note paths.
4. Use AppKit open/reveal only from explicit row actions and only when external actions are allowed.
5. Persist only local workspace pin state such as `pinned`, `lastOpenedAt`, and `archived`.

### Workspace File

```json
{
  "version": 1,
  "updatedAt": "2026-06-22T03:33:23Z",
  "workspaces": [
    {
      "id": "surface",
      "title": "Surface",
      "subtitle": "SwiftUI overlay and plugin research",
      "rootURL": "file:///Users/snbafana/Documents/personal/Scratch/projects/surface/",
      "primaryLaunchTitle": "Open Surface in editor",
      "primaryLaunchURL": "file:///Users/snbafana/Documents/personal/Scratch/projects/surface/",
      "preferredAppBundleIdentifier": "com.microsoft.VSCode",
      "contextBundleIdentifiers": ["com.microsoft.VSCode", "com.apple.Terminal"],
      "noteURL": "file:///Users/snbafana/Documents/personal/Scratch/projects/surface/research/plugin-ideas.md",
      "bookmarkRefs": ["surface-docs", "block-preview"],
      "launchRefs": ["surface-project", "codex-log"],
      "recentFilesCacheURL": "file:///Users/snbafana/Library/Application%20Support/Surface/FileInbox/surface-recent-files.json",
      "tags": ["swift", "surface", "plugins"],
      "pinned": true,
      "archived": false,
      "lastOpenedAt": "2026-06-22T02:27:23Z"
    }
  ]
}
```

### Optional Context Snapshot

```json
{
  "capturedAt": "2026-06-22T03:33:23Z",
  "bundleIdentifier": "com.microsoft.VSCode",
  "windowTitle": "surface"
}
```

This is a deterministic fixture shape. Live context should come from `contextcard` only after an explicit shared snapshot/handoff format exists.

### Optional Recent Files Cache

```json
{
  "workspaceID": "surface",
  "generatedAt": "2026-06-22T03:30:00Z",
  "files": [
    {
      "url": "file:///Users/snbafana/Documents/personal/Scratch/projects/surface/research/workspacepins-spec.md",
      "displayName": "workspacepins-spec.md",
      "kind": "markdown",
      "modifiedAt": "2026-06-22T03:33:23Z"
    }
  ]
}
```

`fileinbox` or an external writer should own this cache if live recent files matter. `workspacepins` should render it, not generate it.

### Local Data Model

```swift
struct WorkspacePinsState: Codable, Equatable {
    var version: Int
    var updatedAt: Date
    var workspaces: [WorkspacePin]
}

struct WorkspacePin: Identifiable, Codable, Equatable {
    var id: String
    var title: String
    var subtitle: String?
    var rootURL: URL
    var primaryLaunchTitle: String?
    var primaryLaunchURL: URL?
    var preferredAppBundleIdentifier: String?
    var contextBundleIdentifiers: [String]
    var noteURL: URL?
    var bookmarkRefs: [String]
    var launchRefs: [String]
    var recentFilesCacheURL: URL?
    var tags: [String]
    var pinned: Bool
    var archived: Bool
    var lastOpenedAt: Date?
}

struct WorkspaceContextSnapshot: Codable, Equatable {
    var capturedAt: Date
    var bundleIdentifier: String?
    var windowTitle: String?
}

struct WorkspaceRecentFile: Codable, Equatable {
    var url: URL
    var displayName: String
    var kind: String
    var modifiedAt: Date?
}
```

## Implementation Notes

Use existing primitives conservatively:

- `Block.Context.storageDirectory` and `Block.Context.now` for deterministic preview state.
- `NSWorkspace.open(_:)` or the eventual `appquicklaunch` opener only for one explicit target at a time.
- `NSWorkspace.activateFileViewerSelecting(_:)` for reveal root/note actions.
- `URLResourceValues` only for configured root/note existence and dates.
- Optional context/recent-file caches only when paths are explicitly listed in the workspace JSON.

Keep all handoff/reference parsing plugin-local until `appquicklaunch`, `fileinbox`, `bookmarkcards`, and `contextcard` each prove a shared snapshot/reference format is needed. Do not introduce a project registry service.

## Display Rules

Header:

- `Workspaces`
- pinned count
- active/matching workspace count
- missing/stale count

Cards:

- title, subtitle, tags
- root folder short path
- active context pill when bundle/window matches
- primary launch row
- note row if present
- bookmark/reference count
- recent-file cache summary if present
- warning row for missing root/note/cache
- fixed icon actions: open primary, reveal root, copy summary, copy path, open note

Sort:

1. active context match
2. pinned non-archived
3. recently opened
4. title
5. archived hidden by default

Do not render a giant dashboard. Cap visible cards and recent-file rows; this should stay glanceable.

## Actions

- Open primary launch URL.
- Reveal root folder.
- Open note URL.
- Copy root path.
- Copy Markdown workspace summary.
- Copy configured refs/IDs.
- Pin/unpin or archive/unarchive local workspace record if writes are enabled.

No action should launch multiple targets, restore a session, run a command, move windows, switch Spaces, open browser tabs in bulk, mutate other plugin stores, or fetch remote metadata.

## Runtime Shape

Target: `plugins/workspacepins/source/Plugin.swift`

Runtime:

1. `start()`: load workspace JSON and optional fixture/context/cache files.
2. `refresh()`: reload files and recompute active/missing/stale labels.
3. `openPrimary(id:)`: open one configured target.
4. `revealRoot(id:)`: reveal one configured root.
5. `copySummary(id:)`: write deterministic Markdown to pasteboard.
6. `mutate(id:action:)`: pin/archive only local workspace records when allowed.
7. `stop()`: no-op.
8. `makeView()`: render compact workspace cards.

Use a small injected opener for tests. Do not call into other plugin runtimes.

## Fixture Plan

Fixtures:

- `empty`: no workspaces.
- `active-project`: context snapshot matches one workspace.
- `multi-projects`: pinned workspaces with different root/note/link shapes.
- `missing-root`: missing root/note/cache warnings.
- `recent-cache`: cached file rows from an explicit file.
- `read-only`: mutation actions disabled, open/copy still visible as allowed by context.

## Test Plan

- Workspace JSON decodes with stable IDs and typed URLs.
- Missing root/note/cache renders warning rows without crashing.
- Context matching is deterministic from fixture snapshot.
- Recent-file cache is rendered only when explicitly configured.
- Live mode does not scan arbitrary roots for recent files.
- Open/reveal actions operate on exactly one target.
- No action launches groups, runs scripts/commands, moves windows, switches Spaces, restores tabs, or mutates other plugin stores.
- `Block.Context.now` controls age/stale labels.
- Preview fixtures render nonblank PNGs through `Blocks.registry`.

## Recommendation

Implement `workspacepins` as a small project-card block after `appquicklaunch` or alongside it if the opener can be reused cleanly. The v1 value is orientation: what project am I in, what are its anchors, and what one thing do I open/copy/reveal next? Full session restore belongs outside v1.
