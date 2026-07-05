# `bookmarkcards` Plugin Spec

## Why This Matters

Surface already has `linkinbox` for URL capture and triage. `bookmarkcards` should be different: a curated shelf of stable links the user wants visible, grouped, and quickly opened or copied. The useful version is a local read-later/bookmark card block, not browser history, not a browser bookmark manager, and not another URL inbox.

Browser bookmark APIs and extensions are real, but they bring browser-specific permissions, profile handling, extension install cost, and mutation risk. The first version should be file-backed, deterministic in previews, and independent of browser profile databases.

## Existing Owner / Dedup Decision

- `linkinbox` owns captured/pending URL records, dedupe, archive/pin/tag triage, pasteboard URL extraction, and future title fetches.
- `browsersessioncards` owns active browser tab/session snapshots and browser adapters.
- `contextcard` owns frontmost app/window context.
- `snippetprompt` owns reusable text templates.
- `obsidianqueue` owns Obsidian-specific queues and vault handoff.
- Browser extensions own browser bookmark APIs and browser-profile access.
- `bookmarkcards` owns only curated bookmark/read-later rows, local shelf/group state, stale labels, and explicit open/copy/mark actions.

Do not add browser history scraping, browser profile database parsing, global bookmark search, automatic bookmark import, remote read-later API sync, webpage metadata fetching, favicon fetching, webview previews, browser extension install, or a second plugin registry. Implement as one `BlockRuntime` using `Block.Context.storageDirectory` and `Block.Context.now`.

## Product Boundary

It should:

- Read `bookmarkcards-bookmarks.json` from fixture/live storage.
- Show curated bookmark/read-later rows grouped by shelf/tag/state.
- Support explicit open, copy URL, copy Markdown, copy title, pin/unpin, mark read/unread, and archive actions for local records.
- Show stale/cache/source labels when records came from an external export.
- Optionally reveal the local bookmark JSON file.
- Accept future handoff from `linkinbox` by appending a URL record to this local store.

It should not:

- Read Chrome/Safari/Firefox/Arc profile bookmark files in v1.
- Read browser history, open tabs, or page content.
- Install or require a browser extension.
- Use Chrome/WebExtension bookmark APIs directly from the Swift block.
- Import exported browser bookmark HTML automatically.
- Fetch titles, icons, previews, or metadata during preview/startup/refresh.
- Mutate browser bookmarks.
- Become a generic search engine for every saved URL on the machine.
- Duplicate `linkinbox` capture/triage semantics.

## First Version

### Data Modes

Fixture mode:

1. Read `Block.Context.storageDirectory/bookmarkcards-bookmarks.json`.
2. Use `Block.Context.now` for stale and age labels.
3. Do not fetch network metadata.
4. Mutating/open actions are preview no-ops.

Live mode:

1. Read `~/Library/Application Support/Surface/BookmarkCards/bookmarkcards-bookmarks.json`.
2. Write only this local file for pin/read/archive updates, and only when external writes/actions are allowed.
3. Open URLs with `NSWorkspace.open(_:)` only from explicit user action.
4. Do not touch browser bookmark stores in v1.

Future import modes:

- User-exported browser bookmark HTML file, parsed only after explicit import.
- Folder of `.webloc` / internet-location files selected by the user.
- Browser extension/native cache written to Application Support.
- `linkinbox` handoff into a bookmark shelf.

All future import modes should write the same local JSON shape first; the block should keep rendering from the local JSON store.

### Bookmark File

```json
{
  "version": 1,
  "exportedAt": "2026-06-22T01:22:23Z",
  "bookmarks": [
    {
      "id": "surface-docs",
      "title": "Surface plugin architecture",
      "url": "https://example.com/surface/plugins",
      "description": "Reference link for plugin design.",
      "shelf": "Surface",
      "tags": ["plugins", "docs"],
      "state": "unread",
      "source": "manual",
      "pinned": true,
      "addedAt": "2026-06-21T18:00:00Z",
      "updatedAt": "2026-06-22T01:20:00Z",
      "lastOpenedAt": null
    }
  ]
}
```

### Local Data Model

```swift
struct BookmarkCardsState: Codable, Equatable {
    var version: Int
    var exportedAt: Date
    var bookmarks: [BookmarkCard]
}

struct BookmarkCard: Codable, Identifiable, Equatable {
    var id: String
    var title: String
    var url: URL
    var description: String?
    var shelf: String?
    var tags: [String]
    var state: BookmarkReadState
    var source: BookmarkSource
    var pinned: Bool
    var addedAt: Date?
    var updatedAt: Date?
    var lastOpenedAt: Date?
}

enum BookmarkReadState: String, Codable {
    case unread
    case reading
    case read
    case archived
}

enum BookmarkSource: String, Codable {
    case manual
    case linkinbox
    case importedFile
    case browserExtensionCache
    case fixture
}
```

### Display Rules

Header:

- `Bookmarks`
- status pill: `ready`, `empty`, `stale`, or `read-only`
- bookmark count, unread count, shelf count

Rows:

- title
- host/path fallback from URL
- shelf/tag chips
- state pill
- source and age
- icon actions: open, copy URL, copy Markdown, pin, mark read/archive, reveal source file

Sort rows:

1. pinned unread
2. pinned reading
3. recently added unread
4. recently updated/read
5. archived hidden by default

Stale policy:

- If `exportedAt` is older than 7 days and any record source is `importedFile` or `browserExtensionCache`, mark the file stale.
- If a record's `updatedAt` is older than 90 days and state is not archived, mark it as old but still render it.
- Use `Block.Context.now` for all age labels.

## Actions

- Open URL.
- Copy URL.
- Copy Markdown link.
- Copy title.
- Pin/unpin local bookmark.
- Mark read/unread/reading.
- Archive/unarchive local bookmark.
- Reveal bookmark JSON file.

No action should mutate browser bookmarks, import browser data implicitly, fetch metadata, or read browser history/profile files.

## UI Shape

Top region:

- unread count
- active shelf/tag filter
- source/stale status

Main list:

- compact rows grouped by shelf only when groups are short
- otherwise a single sorted list with shelf chips
- fixed icon buttons for open/copy/pin/read/archive

Empty state:

- `No bookmarks yet`
- show expected JSON filename
- offer copyable JSON example
- point URL capture to `linkinbox`

Read-only state:

- previews/tests and locked files render copy/open actions only.
- local mutation actions are disabled with clear row state.

## Runtime Shape

Target: `plugins/bookmarkcards/source/Plugin.swift`

Runtime:

1. `start()`: load local bookmark JSON.
2. `refresh()`: reload file and recompute stale labels.
3. `mutate(id:action:)`: update only local JSON state when allowed.
4. `stop()`: no-op.
5. `makeView()`: render counts, filters, rows, and empty/read-only states.

Use plugin-local JSON read/write helpers first. If later local-list plugins share enough code, factor after implementation.

## Fixture Plan

Fixtures:

- `empty`: no bookmark file.
- `curated-shelves`: several shelves and tags.
- `read-later`: unread/reading/read mix.
- `stale-import`: imported records with old export time.
- `read-only`: fixture rows with mutation disabled.
- `linkinbox-handoff`: records whose source is `linkinbox`.

## Test Plan

- Missing file renders empty state.
- Bookmark JSON decodes and invalid URL rows are reported without crashing.
- Sort order is deterministic.
- Stale file and old row labels use `Block.Context.now`.
- Open/copy actions only use decoded visible URLs.
- Markdown link copy is deterministic.
- Mutations update only local JSON and are disabled in fixture/read-only mode.
- No test path reads browser profile files, browser history, browser bookmark APIs, WebExtension APIs, or the network.
- Preview fixtures render nonblank PNGs through `Blocks.registry`.

## Recommendation

Implement `bookmarkcards` as a local shelf for curated links. Browser bookmark APIs, HTML imports, `.webloc` folders, and extension-backed caches can be future explicit adapters, but v1 should be a predictable local JSON block that complements `linkinbox` instead of replacing it.
