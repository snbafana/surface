# `browsersessioncards` Plugin Spec

## Why This Matters

Browser context is high value because many Surface workflows start from the active tab: research, docs, dashboards, tickets, videos, and local app previews. The safe implementation boundary is narrow. Raycast validates active-tab and browser-tab workflows through Automation permissions and a browser extension, while Chrome documents explicit extension/tab permissions and native messaging paths. Those paths are not the same as silently reading browser history, profile databases, cookies, or every page.

The useful Surface version is an active-browser session snapshot card: current tab first, a small list of visible/open tabs when explicitly available, and copy/open/capture actions.

## Existing Owner / Dedup Decision

- `contextcard` owns generic frontmost app/window identity and should not grow browser-specific tab logic.
- `linkinbox` owns durable URL records, URL dedupe, archive/pin/tag state, and long-lived link triage.
- `snippetprompt` owns local prompt templates and should not fetch browser content.
- `aicommandscratchpad` may later consume browser context, but should not own browser capture.
- `permissionsdashboard` owns Automation, Accessibility, and future extension/native-host status.
- `browsersessioncards` owns only browser-specific active tab/session snapshots, explicit refresh, and short-lived capture handoffs.

Do not add browser history/profile database reads, bookmark-tree import, cookie/session extraction, full-page content scraping, hidden JavaScript injection, screenshots, remote browser control, DevTools auto-launching, extension install automation, or a second plugin registry. Implement as one `BlockRuntime` using `Block.Context.storageDirectory` and `Block.Context.now`.

## Product Boundary

It should:

- Show the frontmost supported browser, if known.
- Show active tab title, URL, host, favicon URL when available, audible/muted state when available, and captured age.
- Show a short list of other open tabs only when the adapter explicitly provides them.
- Copy active URL.
- Copy active tab Markdown.
- Copy a session Markdown list.
- Open active URL through `NSWorkspace.open(_:)`.
- Send/copy a URL record for `linkinbox` import rather than owning durable link triage.
- Show blocked states for missing Automation permission, missing browser extension, unsupported browser, or missing fixture.

It should not:

- Read full browser history.
- Read browser profile SQLite/JSON databases.
- Import bookmarks or reading lists in v1.
- Read cookies, local storage, passwords, forms, downloads, or saved sessions.
- Fetch page HTML/content automatically.
- Use screenshots, OCR, Accessibility scraping, or keyboard simulation to infer URLs.
- Run JavaScript in tabs from the block runtime.
- Close, move, reorder, or mutate tabs in v1.
- Control browser media; that belongs to source-specific media work or `mediacontrols` cache writers.
- Become a tab manager with global search across every browser profile.

## First Version

### Data Modes

Fixture mode:

1. Read `Block.Context.storageDirectory/browsersessioncards-session.json`.
2. Use `Block.Context.now` for cache age labels.
3. Do not query browsers, extensions, Apple Events, or DevTools.
4. Mutating actions are no-ops or write only to fixture storage.

Live mode:

1. Start with a browser snapshot adapter that can be disabled or faked in tests.
2. Use `contextcard`-style frontmost app identity, or factor the existing reader after implementation if both call sites need it.
3. Read active-tab title/URL from supported browsers only after the relevant explicit adapter is available.
4. Prefer app-scoped, user-visible adapters:
   - Apple Events/Scripting Bridge for Safari/Chrome-family active tab metadata after Automation permission.
   - Browser extension/native messaging cache if a future Surface extension is deliberately installed by the user.
   - Chrome DevTools Protocol only when the user explicitly configures a local remote-debugging endpoint.
5. Do not persist snapshots as link history. Keep current snapshot state separate from Link Inbox records.

External writers:

- A future browser extension may write `browsersessioncards-session.json`.
- A user script through `scriptoutput` may write the same snapshot shape.
- `linkinbox` may import explicit URL records from this block, but should keep its own store and dedupe logic.

### Adapter Policy

Apple Events adapter:

- Requires `NSAppleEventsUsageDescription` in the bundle.
- Permission state and request/settings help should route through `permissionsdashboard`.
- Read only active browser tab title/URL and, if stable, front-window tab summaries.
- Do not control tab navigation or execute scripts in v1.

Browser extension/native messaging adapter:

- Requires a deliberate Surface browser extension and native messaging host.
- Extension should use an active-tab/user-invoked model where possible.
- Native host registration is an install task, not something the block silently writes.
- The block reads a cache or receives explicit messages; it does not install/update extensions.

Chrome DevTools adapter:

- Disabled by default.
- Requires an explicit localhost endpoint setting, such as `http://127.0.0.1:9222`.
- Treat as developer/debug mode, not general browser integration.
- Never launch Chrome with remote debugging from the block.

### Local Data Model

```swift
struct BrowserSessionSnapshot: Codable, Equatable {
    var capturedAt: Date
    var source: BrowserSessionSource
    var browser: BrowserAppSnapshot?
    var activeTabID: String?
    var tabs: [BrowserTabSnapshot]
    var permissionState: BrowserSessionPermissionState
}

struct BrowserAppSnapshot: Codable, Equatable {
    var appName: String
    var bundleIdentifier: String?
    var processIdentifier: Int32?
}

struct BrowserTabSnapshot: Codable, Identifiable, Equatable {
    var id: String
    var title: String?
    var url: URL?
    var host: String?
    var faviconURL: URL?
    var windowIndex: Int?
    var tabIndex: Int?
    var isActive: Bool
    var isAudible: Bool?
    var isMuted: Bool?
    var isPrivate: Bool?
    var capturedAt: Date
}

enum BrowserSessionSource: String, Codable {
    case appleEvents
    case browserExtension
    case devTools
    case scriptCache
    case fixture
}

enum BrowserSessionPermissionState: String, Codable {
    case ready
    case automationBlocked
    case extensionMissing
    case devToolsNotConfigured
    case unsupportedBrowser
    case fixtureOnly
}
```

### Display Rules

Header:

- `Browser`
- status pill: browser name, `blocked`, or `fixture`
- age pill: `now`, `2m ago`, or `stale`

Active tab card:

- title or host/path fallback
- host and short URL
- badges for `active`, `audible`, `muted`, `private` when present
- copy/open/capture actions

Other tabs:

- show at most 8 rows by default
- active tab first, then same-window tabs, then other tabs by most recent adapter order
- collapse overflow behind `+N more`

Blocked states:

- `Automation blocked`: route to `permissionsdashboard`.
- `Extension missing`: show fixture/cache-only state and open docs later.
- `Unsupported browser`: still show generic `contextcard` app/window data if available, but no tab metadata.
- `DevTools disabled`: show only if user configured DevTools mode.

### Actions

- Open active URL.
- Copy active URL.
- Copy active tab Markdown.
- Copy session Markdown.
- Copy JSON snapshot.
- Capture active tab to Link Inbox handoff file.
- Reveal/open backing snapshot JSON.
- Open permission/status row in `permissionsdashboard` when blocked.

No action should close tabs, switch tabs, mutate tab groups, execute JavaScript, fetch page content, install an extension, or launch a debug browser.

## UI Shape

Top region:

- active tab as the primary card
- compact browser/source/age row
- blocked-state reason when needed

Tab list:

- compact rows with title, host, and badges
- fixed-size icon buttons for open/copy/capture
- stable row height to avoid jitter during refresh

Footer:

- `Capture to Link Inbox`
- `Copy session`
- `Reveal JSON`

## Runtime Shape

Target: `plugins/browsersessioncards/source/Plugin.swift`

Runtime:

1. `start()`: load fixture/cache snapshot and optionally install lightweight app-activation observer if using the frontmost app reader.
2. `refresh()`: reload snapshot file and call the configured live adapter only when live mode is allowed.
3. `stop()`: remove observers/cancel tasks.
4. `makeView()`: render active tab, tab rows, blocked state, and explicit actions.

Keep adapter protocols plugin-local until `contextcard` and `browsersessioncards` both prove they need a shared frontmost-app/context package.

## Fixture Plan

Fixtures:

- `empty`: no browser app and no tabs.
- `active-tab`: one Safari/Chrome active tab with title and URL.
- `research-session`: multiple tabs across one browser window, one audible tab, one missing title.
- `blocked-automation`: supported browser but Automation permission denied.
- `extension-cache`: snapshot written by a hypothetical browser extension/native messaging bridge.
- `devtools-cache`: Chrome DevTools style tabs with explicit debug source.

Example snapshot:

```json
{
  "capturedAt": "2026-06-21T22:37:22Z",
  "source": "fixture",
  "browser": {
    "appName": "Safari",
    "bundleIdentifier": "com.apple.Safari",
    "processIdentifier": 1234
  },
  "activeTabID": "tab-1",
  "permissionState": "ready",
  "tabs": [
    {
      "id": "tab-1",
      "title": "Surface Plugin Research",
      "url": "https://www.raycast.com/browser-extension",
      "host": "www.raycast.com",
      "faviconURL": null,
      "windowIndex": 0,
      "tabIndex": 0,
      "isActive": true,
      "isAudible": false,
      "isMuted": false,
      "isPrivate": false,
      "capturedAt": "2026-06-21T22:37:22Z"
    }
  ]
}
```

## Test Plan

- Missing fixture renders empty/unsupported state.
- Snapshot JSON decodes and active tab resolves by `activeTabID`.
- URL host fallback handles missing title.
- Private/audible/muted badges render only when present.
- Permission states render distinct blocked copy.
- `Block.Context.now` drives stale/age labels.
- Session Markdown includes active tab first and limits overflow deterministically.
- Capture-to-Link-Inbox writes only a handoff record when fixture storage or external writes allow it.
- Live adapters are injectable fakes in tests.
- No history/profile/bookmark files are read in tests or previews.
- Preview fixtures render nonblank PNGs through `Blocks.registry`.

## Recommendation

Implement after `contextcard` or alongside it if the app-context reader can be reused cleanly. Keep v1 read/copy/capture-only. Browser extension and DevTools integrations should be explicit later adapters, not hidden dependencies of the block.
