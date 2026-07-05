# `notificationdigest` Plugin Spec

## Why This Matters

Notification digests are useful when they summarize actionable events instead of replaying every interruption. Raycast extensions validate unread-count and notification-inbox surfaces for specific services, while Apple's supported APIs make a critical boundary clear: an app can manage its own notification behavior and delivered notifications, not read every macOS Notification Center item from other apps.

The useful Surface version is a local digest of Surface-owned/plugin-owned events with source, severity, read/archive state, and explicit open/copy actions.

## Existing Owner / Dedup Decision

- `permissionsdashboard` owns notification permission status and any explicit request path.
- Codex Log owns Codex action queues, running threads, and Codex-specific events.
- Copy History owns clipboard history.
- Focus owns timers and completion state.
- Script Output owns command execution and command failures.
- `notificationdigest` owns only a local digest inbox for Surface/plugin event records and optional Surface-delivered notification snapshots.

Do not add a macOS-wide notification reader, private Notification Center database scraping, Accessibility/OCR capture, unified-log mining as a primary source, a background notification daemon, or a second plugin registry. Implement as one `BlockRuntime` using `Block.Context.storageDirectory` and `Block.Context.now`.

## Product Boundary

It should:

- Show recent Surface-owned event rows grouped by unread, attention, and source.
- Support info/success/warning/error severity.
- Show source block, title, body/detail, occurred time, received time, and optional URL.
- Mark rows read/unread.
- Archive rows.
- Pin or mute a noisy source locally.
- Open a stored URL on explicit action.
- Copy one event or a Markdown digest.
- Show notification permission status if available from a small adapter or fixture.

It should not:

- Read other apps' notifications from Notification Center.
- Scrape private notification databases or plist stores.
- Use Screen Recording, Accessibility, or OCR to reconstruct notifications.
- Read global unified logs or run `log stream`.
- Poll Slack, GitHub, email, calendars, or web services directly.
- Duplicate Codex Log action approvals or source-specific queues.
- Request notification permission during `start()` or `refresh()`.
- Schedule local notifications in v1.
- Treat delivered Notification Center retention as durable history.

## First Version

### Data Modes

Fixture mode:

1. Read `Block.Context.storageDirectory/notificationdigest-events.jsonl`.
2. Read optional `Block.Context.storageDirectory/notificationdigest-settings.json`.
3. Use `Block.Context.now` for relative age, expiry, and grouping.
4. Do not query `UNUserNotificationCenter`.
5. Mutating actions can be preview no-ops or write only to fixture storage.

Live mode:

1. Read `~/Library/Application Support/Surface/NotificationDigest/notificationdigest-events.jsonl`.
2. Write read/archive/pin/mute changes only when `Block.Context.allowsExternalWrites` is true.
3. Optionally read Surface's own delivered notifications through an adapter around `UNUserNotificationCenter.getDeliveredNotifications`, but only as a supplement and only when permission state allows it.
4. Do not read Notification Center data for other apps.

External writers:

- Surface app code may append rows for app-level events such as hotkey registration failure.
- Plugins may append rows for their own events after implementation, such as Focus completion or Script Output failure.
- Automations may append rows if they already own the domain event.
- Source plugins must keep their detailed state in their own files; digest rows are summaries.

### Local Data Model

```swift
struct NotificationDigestEvent: Codable, Identifiable, Equatable {
    var id: String
    var sourceID: String
    var sourceName: String
    var kind: DigestKind
    var title: String
    var detail: String?
    var occurredAt: Date
    var receivedAt: Date
    var url: URL?
    var dedupeKey: String?
    var notificationIdentifier: String?
    var isRead: Bool
    var pinnedAt: Date?
    var archivedAt: Date?
    var expiresAt: Date?
    var metadata: [String: String]
}

enum DigestKind: String, Codable {
    case info
    case success
    case warning
    case error
}

struct NotificationDigestSettings: Codable, Equatable {
    var mutedSourceIDs: [String]
    var maxVisibleRows: Int
    var archiveReadAfterDays: Int?
}
```

Keep the JSONL format append-friendly. Mutations may append replacement rows with the same `id` and updated `isRead`/`archivedAt`, then fold by latest `receivedAt`, matching the Codex Log action-log pattern where useful.

### Display Rules

Rows should show:

- severity icon/pill
- source name
- title
- one-line detail
- relative age from `Block.Context.now`
- unread/read state
- pinned/source-muted state when relevant

Group rows by:

1. pinned attention rows
2. unread warnings/errors
3. unread info/success
4. read recent

Sort rows within groups by:

1. pinned timestamp descending
2. severity, with error and warning first
3. occurred time descending
4. source name

Hidden rows:

- archived rows
- expired rows unless pinned
- rows from muted sources unless the user chooses to show muted sources

### Actions

- Open URL.
- Copy event title/detail.
- Copy Markdown digest.
- Mark read/unread.
- Archive row.
- Pin/unpin row.
- Mute/unmute source.
- Reveal/open backing JSONL file.
- Open notification permission row through `permissionsdashboard` or System Settings when available.

No action should fetch service notifications, execute scripts, or request notification permission implicitly.

## UI Shape

Header:

- `Digest`
- status pill: `3 unread`, `2 attention`, or `Clear`
- permission pill: `notifications allowed`, `blocked`, or `file only`

Rows:

- compact icon/severity column
- source/title/detail stack
- age and action icons
- stable row height with expanded details only on selection if needed

Empty state:

- `No unread events`
- show last archived/read count if useful
- open backing JSONL

Blocked state:

- If notification permission is denied, show `Surface alerts blocked` as a permission status only.
- Still render file-backed digest rows; notification permission is not required for the local digest.

## Runtime Shape

Target: `plugins/notificationdigest/source/Plugin.swift`

Runtime:

1. `start()`: load events, settings, and optional permission fixture/status.
2. `refresh()`: reload files, fold JSONL rows by `id`, drop archived/expired rows from the visible list, and recompute age/grouping against `Block.Context.now`.
3. `stop()`: no-op.
4. `makeView()`: render grouped digest rows and explicit actions.

Use plugin-local JSONL helpers first. If Codex Log action-row folding and digest folding duplicate enough code after implementation, factor a small append-only ledger helper then.

## Fixture Plan

Fixtures:

- `empty`: no event file.
- `mixed-events`: info/success/warning/error rows across Surface, Focus, Script Output, and Local Build Status.
- `attention-unread`: unread warning/error rows plus pinned row.
- `muted-and-archived`: muted source, archived rows, and expired rows.
- `permission-blocked`: file-backed rows plus denied notification permission snapshot.

Example event file:

```json
{"id":"surface-hotkey-failed","sourceID":"surface","sourceName":"Surface","kind":"error","title":"Option-E shortcut failed","detail":"RegisterEventHotKey returned a nonzero status.","occurredAt":"2026-06-21T21:20:00Z","receivedAt":"2026-06-21T21:20:02Z","url":null,"dedupeKey":"surface.hotkey.option-e","notificationIdentifier":null,"isRead":false,"pinnedAt":null,"archivedAt":null,"expiresAt":null,"metadata":{"category":"KeyboardShortcuts"}}
{"id":"focus-finished-1","sourceID":"focus","sourceName":"Focus","kind":"success","title":"Focus block complete","detail":"45 minute session finished.","occurredAt":"2026-06-21T21:25:00Z","receivedAt":"2026-06-21T21:25:00Z","url":null,"dedupeKey":"focus.finished","notificationIdentifier":"focus-finished-1","isRead":false,"pinnedAt":null,"archivedAt":null,"expiresAt":"2026-06-22T21:25:00Z","metadata":{}}
```

## Test Plan

- Missing event file renders empty state.
- JSONL rows decode and invalid rows are reported without crashing the block.
- Latest row wins when multiple rows share the same `id`.
- Archived and expired rows are hidden.
- Pinned rows survive expiry.
- Muted sources are hidden unless show-muted is enabled.
- Grouping and relative age use `Block.Context.now`.
- Severity ordering is deterministic.
- Permission status can be injected through fixture/test adapter.
- Delivered notification adapter returns only Surface/app-owned notifications and is disabled in previews.
- Mark read/archive/pin/mute writes only when fixture storage or external writes allow it.
- Preview fixtures render nonblank PNGs through `Blocks.registry`.

## Recommendation

Implement after another file-backed plugin. Keep v1 to a local digest file and explicit row actions. If Surface later sends local notifications, append the same event to the digest ledger before scheduling the notification so the digest remains durable even when Notification Center drops delivered notifications.
