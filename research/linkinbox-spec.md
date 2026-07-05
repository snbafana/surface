# `linkinbox` Plugin Spec

## Decision

Build `linkinbox` as one URL-specific triage `BlockRuntime`. It should capture, store, open, copy, archive, and tag links. It should not become a browser history reader, bookmark manager, read-it-later service clone, network crawler, or second clipboard history.

V1 should be clipboard/file-backed with cached metadata only. Do not automatically fetch titles or page metadata during startup, preview rendering, or passive refresh.

## Dedupe Boundary

- Copy History already owns general clipboard text history and pasteboard polling.
- Quicksave already owns rich clipboard capture into files and Obsidian append behavior.
- `linkinbox` owns only URL records and URL-specific actions.
- If implementation needs passive pasteboard watching, factor or reuse URL/text extraction with Copy History instead of copying a second general clipboard loop. The safer v1 is an explicit "capture current link" action plus fixture/file reads.
- `scriptoutput` owns custom URL-processing scripts. `linkinbox` should not run unfurling/summarization commands.

## Product Shape

Surface should show a compact URL inbox:

- top row: pending count, pinned count, latest capture age
- list rows: title or domain/path fallback, host, tags, captured age
- quick actions:
  - open URL
  - copy URL
  - copy Markdown link
  - archive
  - pin/unpin
  - reveal source note/file only if a source path exists

The block is for triage: "what links did I mean to come back to?" It is not for full-text reading, browser tab sync, or long-term bookmark hierarchy.

## Data Sources

1. Link store:
   - previews/tests: `Block.Context.storageDirectory/linkinbox-links.jsonl`
   - live: `~/Library/Application Support/Surface/LinkInbox/linkinbox-links.jsonl`
2. Optional metadata cache:
   - previews/tests: `Block.Context.storageDirectory/linkinbox-metadata.json`
   - live: `~/Library/Application Support/Surface/LinkInbox/linkinbox-metadata.json`
3. Current pasteboard when the user explicitly captures a link:
   - `NSPasteboard.PasteboardType.URL`
   - `.string` containing one or more HTTP(S) URLs
4. Optional import source:
   - Copy History text entries may be scanned for URLs only if implemented through shared parsing code.

## Link Record Schema

```json
{
  "id": "sha256-normalized-url",
  "url": "https://example.com/surface-preview",
  "normalizedURL": "https://example.com/surface-preview",
  "title": "Surface Preview Notes",
  "host": "example.com",
  "tags": ["surface"],
  "status": "pending",
  "source": "clipboard",
  "sourcePath": null,
  "capturedAt": "2026-06-21T18:00:00Z",
  "updatedAt": "2026-06-21T18:00:00Z",
  "lastOpenedAt": null,
  "metadataFetchedAt": null
}
```

Allowed `status` values:

- `pending`
- `pinned`
- `archived`

## URL Normalization

- Accept only `http` and `https` in v1.
- Parse with `URLComponents`.
- Lowercase scheme and host.
- Drop URL fragments by default.
- Keep query strings because many useful links depend on them.
- Reject empty hosts, unsupported schemes, and obvious non-URLs.
- Deduplicate by normalized URL.

## Metadata Policy

V1:

- Do not fetch metadata automatically.
- Use title from stored record, cached metadata, HTML/RTF pasteboard link text if already available, or host/path fallback.
- Preview/test mode reads fixtures only and never starts network work.

Later:

- Add an explicit per-row "Fetch title" or batch "Fetch missing titles" action.
- Use `LPMetadataProvider` for URL metadata and cache the result.
- Do not fetch if `Block.Context.storageDirectory` is non-nil.
- Add rate limits, timeout/error states, and a visible "network metadata" setting before enabling batch fetches.

## Runtime Behavior

- `start()`: load links and cache; do not fetch network metadata.
- `refresh()`: reload files and re-sort; optionally capture current clipboard only when the user presses the capture button.
- `stop()`: cancel any local refresh task.
- Capture:
  - extract URLs from URL pasteboard type first
  - then scan normalized string text for URLs
  - dedupe against normalized URL
  - write/append JSONL only when `Block.Context.allowsExternalWrites` or fixture storage is set
- Actions:
  - `open`: `NSWorkspace.shared.open(url)`
  - `copy URL`: write URL string to pasteboard
  - `copy Markdown`: use `[title](url)` with title fallback to host/path
  - `archive`: append/update local record status
  - `pin`: append/update local record status

## Source Evidence

- Raycast Quicklinks validate fast URL/file/deeplink opening as a daily workflow.
- Raycast Quicklink autofill can pull from active browser or clipboard, but active-browser URL/title access requires Automation permissions. Surface should avoid that in v1 and stay clipboard/file-backed.
- Apple `NSPasteboard.PasteboardType.URL` provides URL pasteboard transfer support, so link capture can use pasteboard URL data before falling back to strings.
- Apple `URLComponents` is the standard structured URL parsing/building API, suitable for normalization and dedupe.
- Apple `NSWorkspace.open(_:)` opens a URL in the user's default app/browser, matching the expected row action.
- Apple `LPMetadataProvider` can fetch URL metadata such as title/icon/image, but fetching is network-like work and should be explicit, cached, and disabled in previews.

## Preview Fixtures

Use `Block.Context.storageDirectory`.

Fixture `empty`:

- no links file
- expected UI: empty inbox and capture affordance

Fixture `pending-links`:

- `linkinbox-links.jsonl` with three pending links:
  - one with stored title
  - one with host/path fallback
  - one pinned

Fixture `archived-cache`:

- pending and archived rows
- `linkinbox-metadata.json` with a cached title for one URL
- expected UI: pending rows first, archived hidden/collapsed

## Tests

- Missing links file renders empty state.
- URL extraction handles pasteboard URL and text URLs.
- Normalization dedupes scheme/host case and strips fragments.
- Unsupported schemes are rejected.
- Stored title, cached title, and host/path fallback are selected in that order.
- Preview context never starts metadata fetches.
- Archive/pin update only local JSONL/store state.
- Copy Markdown formats `[title](url)` correctly.
- Preview fixture coverage is added to `BlockPreviewTests`.
- Rendered PNGs are nonblank for `empty`, `pending-links`, and `archived-cache`.

## Explicit Non-Goals

- No browser history/tab reading.
- No active browser automation in v1.
- No automatic title fetching in v1.
- No full-text page fetch, summarization, screenshots, or readability extraction.
- No sync to Pocket/Raindrop/Instapaper/Obsidian in v1.
- No bookmark tree, folders, or rules engine.
