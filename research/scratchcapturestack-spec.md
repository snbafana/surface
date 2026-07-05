# `scratchcapturestack` Plugin Spec

## Decision

Build `scratchcapturestack` as one Surface `BlockRuntime` that shows a short-lived working stack of explicit text, URL, file, and note references. It is a visible shelf for "things I am using right now", not a universal inbox.

Use the existing `Block` / `BlockRuntime` / `Block.Context` path and the generated registry. Do not add another plugin registry, daemon, watcher, or cross-plugin event bus.

## Existing Owner / Dedup Decision

- Quicksave owns durable capture into files, sidecar notes, and optional Obsidian append.
- File Inbox owns recent-file scanning and artifact triage.
- Copy History owns passive pasteboard polling, clipboard storage, copyback, and future rules.
- Link Inbox owns URL-specific records, dedupe, archive/pin/tag triage, and URL actions.
- Bookmark Cards owns durable curated link shelves.
- Workspace Pins owns project/workspace refs.
- App Quick Launch owns opening curated app/file/folder/URL targets.
- `scratchcapturestack` owns only the temporary stack file, row display, and explicit copy/open/reveal/remove/pin/done actions over stack items.

If implementation needs shared pasteboard or workspace-opening helpers, factor only after inspecting the existing call sites. Do not create a shared "capture platform" first.

## Product Boundary

It should:

- Read `scratchcapturestack-items.json` from `Block.Context.storageDirectory` in previews/tests or Application Support in live mode.
- Keep a small visible stack of recently staged items.
- Support explicit add actions only: pasted/current clipboard text or URL, dropped/selected file URL, or records written by a future source-owner handoff.
- Store references for files and URLs, not copied file payloads or fetched web content.
- Store direct text only when the user explicitly adds that text to the stack.
- Prune unpinned items by TTL and max item count.
- Show missing-file, expired, and read-only states clearly.
- Use fixed icon actions for copy, open, reveal, pin/unpin, mark done, remove, and clear expired.

It should not:

- Watch the clipboard passively.
- Scan Desktop/Downloads/Scratch directories.
- Read browser history, active tabs, page content, screenshots, or OCR.
- Fetch URL titles, favicons, previews, or metadata.
- Copy files into its own storage.
- Write Obsidian notes or Quicksave sidecars.
- Duplicate Link Inbox URL triage, Bookmark Cards shelves, Copy History retention, or File Inbox cleanup.
- Run scripts, Shortcuts, AppleScript, Hammerspoon, Keyboard Maestro, webhooks, uploaders, cloud sharing, or batch processors.
- Become a drag-and-drop file manager, read-it-later service, task inbox, or universal inbox.
- Add a second registry or plugin routing layer.

## First Version

### Data Sources

1. Stack file:
   - previews/tests: `Block.Context.storageDirectory/scratchcapturestack-items.json`
   - live: `~/Library/Application Support/Surface/ScratchCaptureStack/scratchcapturestack-items.json`
2. Current pasteboard only when the user presses an explicit add button:
   - Prefer URL and file URL values first.
   - Accept plain text only under a configured size cap.
   - Do not poll `NSPasteboard.changeCount`.
3. Future explicit handoffs:
   - Copy History can add a selected old entry to the stack.
   - File Inbox can add a selected file ref.
   - Link Inbox can add a selected URL ref.
   - Quicksave can add the latest capture file/note ref.

Do not implement handoffs by adding a global event bus. If needed, use the same local JSON shape and owner-specific explicit buttons.

### Stack File

```json
{
  "version": 1,
  "updatedAt": "2026-06-22T09:40:14Z",
  "maxItems": 12,
  "ttlHours": 24,
  "items": [
    {
      "id": "clip-1",
      "kind": "text",
      "title": "Copied note fragment",
      "preview": "Need to flesh out cued on resume...",
      "source": "copyhistory",
      "sourceID": "copyhistory:0",
      "createdAt": "2026-06-22T09:35:00Z",
      "updatedAt": "2026-06-22T09:35:00Z",
      "expiresAt": "2026-06-23T09:35:00Z",
      "pinned": false,
      "state": "active",
      "url": null,
      "text": "Need to flesh out cued on resume...",
      "metadata": {}
    },
    {
      "id": "file-1",
      "kind": "file",
      "title": "Surface screenshot",
      "preview": "Screenshot 2026-06-20 19.15.00.png",
      "source": "fileinbox",
      "sourceID": "file:///Users/example/Desktop/Screenshot.png",
      "createdAt": "2026-06-22T09:36:00Z",
      "updatedAt": "2026-06-22T09:36:00Z",
      "expiresAt": "2026-06-23T09:36:00Z",
      "pinned": true,
      "state": "active",
      "url": "file:///Users/example/Desktop/Screenshot.png",
      "text": null,
      "metadata": { "kindLabel": "image" }
    },
    {
      "id": "url-1",
      "kind": "url",
      "title": "Dropover",
      "preview": "dropoverapp.com",
      "source": "linkinbox",
      "sourceID": "https://dropoverapp.com/",
      "createdAt": "2026-06-22T09:37:00Z",
      "updatedAt": "2026-06-22T09:37:00Z",
      "expiresAt": "2026-06-23T09:37:00Z",
      "pinned": false,
      "state": "active",
      "url": "https://dropoverapp.com/",
      "text": null,
      "metadata": {}
    }
  ]
}
```

Allowed `kind` values:

- `text`
- `url`
- `file`
- `note`
- `ref`

Allowed `state` values:

- `active`
- `done`
- `missing`
- `expired`

### Runtime Behavior

- `start()`: load stack file, prune expired unpinned items in memory, and validate refs.
- `refresh()`: reload file and recompute stale/missing labels.
- `makeView()`: render active/pinned items first, then recent done/expired collapsed or hidden.
- `stop()`: no background work.
- Add current clipboard:
  - run only from explicit button press
  - read URL/file URL/text once
  - reject empty text and text over the max character cap
  - store text directly only for explicit text additions
- File validation:
  - if a file ref is missing, mark row as missing in memory
  - do not delete the row automatically
- Writes:
  - allowed when `Block.Context.storageDirectory` is set or `Block.Context.allowsExternalWrites` is true
  - otherwise render read-only controls disabled

### Display

Header:

- `Stack`
- active count
- pinned count
- oldest expiring item label or `read-only`

Rows:

- kind icon: text, link, file, note, ref
- title
- source chip: `Copy`, `File`, `Link`, `Quicksave`, or `Manual`
- preview, host, file name, or path tail
- age and pinned/missing/expired state
- fixed-size icon buttons:
  - copy text/URL/path
  - open URL/file/note target
  - reveal file target
  - pin/unpin
  - mark done
  - remove

Empty state:

- Show a compact empty message and explicit add affordance.
- Do not describe how the whole plugin system works in-app.

### Actions

- Copy:
  - text item: copy text
  - URL item: copy URL
  - file item: copy file path
  - note/ref item: copy best available title/value
- Open:
  - URL through `NSWorkspace.open(_:)`
  - file/note through `NSWorkspace.open(_:)`
- Reveal:
  - file/note through `NSWorkspace.activateFileViewerSelecting(_:)`
- Pin/unpin:
  - pinned rows ignore TTL pruning
- Done:
  - moves row out of the active group without deleting it
- Remove:
  - deletes only the stack record, never the referenced file or source record
- Clear expired:
  - deletes expired unpinned stack records only

No action should mutate Quicksave, Copy History, Link Inbox, Bookmark Cards, File Inbox, browser state, or external services in v1.

## Source Evidence

- Dropzone Drop Bar keeps references to files from different locations, can group them into stacks, and lets the user drag them out later. Surface should copy the reference-shelf idea but not Dropzone's action runner.
- Yoink is a shelf for files and app content, including dragged text/images and clipboard-history-to-shelf flows. Surface should use that as product evidence for explicit staging while keeping passive history in Copy History.
- Dropover describes a temporary floating shelf for files, links, text, and images, plus move/share/process actions. Surface can support mixed item kinds, but processing/uploading belongs outside v1.
- Unclutter unifies clipboard, files, and notes in one desktop space. That validates convenience, but Surface should keep separate owners and let the stack compose references rather than merge all stores.
- Apple `NSWorkspace.open(_:)` and `activateFileViewerSelecting(_:)` cover open/reveal actions without shelling out or becoming a file manager.

## Preview Fixtures

Use `Block.Context.storageDirectory`.

- `empty`: no stack file.
- `mixed-stack`: text, URL, file, note/ref rows from different sources.
- `pinned-items`: pinned rows older than TTL still visible.
- `expired-items`: unpinned expired rows hidden or collapsed.
- `missing-file`: file ref no longer exists and open/reveal are disabled.
- `read-only`: valid rows with write actions disabled.

## Tests

- Missing stack file renders empty state.
- Invalid JSON renders a blocked/error state without crashing.
- Active rows sort pinned first, then newest active rows.
- TTL pruning ignores pinned rows.
- Max item count is enforced for unpinned rows.
- Missing file refs show missing state and disabled open/reveal.
- Remove deletes only the stack record, not referenced files.
- Done changes only local stack state.
- Copy text/URL/path writes the expected string.
- Fixture mode never reads live pasteboard unless an explicit add action is invoked.
- Runtime does not start timers, file watchers, directory scans, network fetches, shell commands, AppleScript, Accessibility, browser automation, or another plugin registry.
- Preview fixtures render nonblank PNGs and are covered by `BlockPreviewTests`.

## Recommendation

Implement `scratchcapturestack` after File Inbox, Link Inbox, and Copy History Rules if the goal is source-owner handoffs, or earlier as a standalone stack if the goal is a visible mixed-reference shelf. The first version should stay local, bounded, explicit, and reference-only.
