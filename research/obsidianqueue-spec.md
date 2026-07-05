# `obsidianqueue` Plugin Spec

## Decision

Build this as one Surface `BlockRuntime` that summarizes Obsidian-facing work already owned by Quicksave and Codex Log. Do not create another plugin registry, approval queue, Obsidian daemon, or vault mutation path.

## Dedupe Boundary

- Daily-note creation, append formatting, template fallback, media copying, and Quicksave path settings are already owned by `plugins/quicksave/source/Obsidian.swift` and `plugins/quicksave/source/Notes.swift`.
- Action approvals, JSONL folding, and `daily-obsidian-backlink-proposals` / `daily-note-to-genuine-ideas` row splitting are already owned by Codex Log.
- `obsidianqueue` should reuse or factor those readers before implementation. If target boundaries make direct imports awkward, move the read-only Obsidian path/date helpers and action-row filtering into shared support; do not duplicate behavior in a new parallel owner.

## Product Shape

Surface should show a note operator panel:

- Today's daily note exists / missing, last modified time, rough line count, and unchecked task count.
- Today's Quicksave capture count and latest capture sidecar note.
- Pending Obsidian action rows from `~/.codex/codexlog-actions.jsonl`, filtered to:
  - `daily-obsidian-backlink-proposals`
  - `daily-note-to-genuine-ideas`
- Fast actions:
  - open today's daily note in Obsidian
  - open the source or target note for a pending row
  - open Obsidian search for a link, title, or source path
  - copy a wikilink, markdown link, or Obsidian URI
  - jump to Codex Log to approve or deny when a row needs mutation

The block can be domain-specific and compact because Codex Log remains the generic queue and approval surface.

## Live Data Sources

1. Quicksave settings from the existing suite `com.snbafana.quicksave`:
   - `obsidianVaultPath`
   - `obsidianDailyNotesPath`
   - `obsidianDailyTemplatePath`
   - `inboxPath`
2. Quicksave defaults when settings are absent:
   - vault: `~/Documents/Obsidian-Vault`
   - daily notes: `~/Documents/Obsidian-Vault/Zettelkatsen`
   - daily template: `~/Documents/Obsidian-Vault/Templates/Daily Note.md`
   - inbox: `~/Quicksave Inbox`
3. Daily note file derived from Quicksave's existing `ObsidianDailyNotes.dailyNoteName(for:)` behavior.
4. `~/.codex/codexlog-actions.jsonl` filtered to Obsidian automations.
5. Optional later enrichment from the official Obsidian CLI, only when it is installed and safe to call.

## Source Evidence

- Obsidian URI supports opening a vault/file/path, creating or opening the daily note, and opening Search with a query. This is enough for `open daily`, `open source note`, and `open search` actions without mutating files.
- Obsidian Daily notes is a core plugin that opens or creates today's note and can use a configured folder, date format, and template. Surface should not hard-code Obsidian's default date naming when Quicksave already has configured local behavior.
- Obsidian Properties are structured frontmatter fields. The queue should read simple status fields such as `Related` when useful, but v1 should not rewrite properties.
- Obsidian Search supports terms and operators, including path/file-oriented search. Search URIs are a good row action for validating backlink proposals.
- Obsidian CLI can open/read/search/daily/tasks/tags, but the docs note the app must be running or will be launched. Treat CLI as v2 enrichment; v1 should work from files and URIs.

## Runtime Behavior

- `start()`: load a snapshot and schedule a lightweight refresh while running. No background service outside the block runtime.
- `refresh()`: rescan configured paths and action log. Use `Block.Context.now` for relative time and daily-note derivation in previews/tests.
- `makeView()`: compact dashboard:
  - header: vault name/path status, today's note status
  - daily note row: open, copy URI, reveal
  - capture row: capture count, latest capture/note
  - queue rows: backlink proposals and Genuine Ideas proposals with source/target/open/search/copy actions
- Mutations:
  - v1: no vault writes and no approval writes. Route approve/deny to Codex Log.
  - v2: approve/deny only if the implementation reuses the same append-only `ActionLog` decision path as Codex Log.

## Preview Fixtures

Use `Block.Context.storageDirectory` as the fixture root.

Fixture `empty`:

- no vault directory
- no action log
- expected UI: missing vault/settings state with setup/open-settings affordance

Fixture `daily-with-queue`:

- `vault/Zettelkatsen/05-20-2026.md`
- `vault/Inbox/How to Understand ML Papers Quickly.md`
- `vault/Future Lists/Genuine Ideas List.md`
- `quicksave-inbox/2026-05-20T19-30-00.000Z.txt`
- `codexlog-actions.jsonl` with one backlink proposal and one Genuine Ideas proposal

The fixture should verify that `obsidianqueue` can render without Obsidian installed or running.

## Tests

- Daily-note path uses existing Quicksave date/path behavior.
- Obsidian URI generation percent-encodes paths, vault names, headings, and search queries.
- Action filtering includes only Obsidian automation rows and ignores unrelated Codex actions.
- Structured Codex Log rows are split through the existing action candidate behavior or factored shared helper.
- Preview fixture coverage is added to `BlockPreviewTests`.
- Rendered PNGs are nonblank for `empty` and `daily-with-queue`.

## Implementation Order

1. Factor shared read-only helpers out of Quicksave/Codex Log if needed.
2. Implement file-backed snapshot parser with fixtures.
3. Add URI/copy/open/reveal actions.
4. Add preview fixtures and smoke tests.
5. Consider optional Obsidian CLI enrichment only after v1 is stable.
