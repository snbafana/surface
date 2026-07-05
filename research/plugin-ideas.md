# Surface Plugin Ideas

This ranking is for Surface as it exists now: a local macOS overlay with `Block`, `BlockRuntime`, `Block.Context`, deterministic previews, and a generated Block Registry.

## Highest-Leverage Next Plugins

| Rank | Plugin | Why It Fits | First Version | Preview Fixture |
| --- | --- | --- | --- | --- |
| 1 | GitHub PR / Review Queue | xbar has PR menu-bar plugins; Raycast developer/project categories lean heavily on GitHub-style triage. Surface already has action-card UI patterns via Codex Log. | Read `gh pr list --search review-requested:@me` or fixture JSON; show PR title, repo, status, and open/copy buttons. | `github-prs.json` with 3 PRs, one failing, one waiting, one draft. |
| 2 | Active Context Card | Hammerspoon validates app/window-aware automation. Surface's overlay is useful if it knows the current app, selected text, front document, and recent file. | Show frontmost app/window, copied selection fallback, and quick actions: copy title, capture context, open containing folder. | Fixture JSON with app, window title, URL/file path, selected text. |
| 3 | File Inbox / Screenshot Triage | The user's desktop and Scratch workflows create screenshots, downloads, notes, and generated artifacts. Raycast emphasizes file search; xbar/SwiftBar show ambient filesystem status. | Watch Desktop/Downloads/Scratch recent files; show newest files with reveal, move-to-folder, and copy-path actions. | Directory fixture with screenshots, PDFs, markdown, and stale temp files. |
| 4 | Obsidian Daily Note / Backlink Queue | Quicksave already writes to Obsidian; Codex Log already models approval queues; Obsidian URI/CLI make open/search/read paths concrete. | Show today's note status, recent captures, and pending backlink/idea rows from local queue files, with mutation routed back to Codex Log. | Fixture vault subset with daily note, quicksave capture, related links, pending rows. |
| 5 | Permissions Dashboard | Current hotkey/accessibility work makes permissions visible, and future context/window/calendar/contact plugins need explicit blocked states. | Show plugin-to-permission map and current status, with request/settings actions only where platform APIs support them. | Fixture JSON with all-clear, mixed-blocked, and manual-only rows. |
| 6 | Focus / Now Block | Raycast timer/pomodoro extensions validate lightweight focus surfaces; Apple Focus and Screen Time show why blocking/system mutation should stay out of v1. | Local timer with goal, focus/break phases, pause/skip/reset/copy summary, and persisted state. | Fixed clock plus `focus-state.json` fixtures for idle, active, and break-due states. |

## Strong Second Wave

| Plugin | Why It Fits | First Version | Risk |
| --- | --- | --- | --- |
| Window Layouts | Hammerspoon Spoons include window switchers/desktop arrangers. | Save and apply named layouts for a few common apps. | Needs Accessibility permission and careful visible failure state. |
| Script Output Block | xbar, SwiftBar, and Ubersicht prove scheduled command output is useful; their action/marketplace models also show the boundary Surface should avoid. | Run one configured executable on an interval, parse a safe stdout subset, render rows, and ignore command-running action params. | Easy to become a second plugin system; keep it one block with one script config. |
| Local Build Status | Developer users need fast feedback; Git porcelain gives stable repo state and this repo already has a clear SwiftPM/preview verification loop. | Read git branch/dirty/ahead-behind state plus `.build/surface-status/last-*.json` result files written by an external runner. | Must not duplicate `scriptoutput` by running build/test commands itself. |
| Worktree Cards | Git worktrees are common in parallel Codex/developer lanes, and Git exposes stable porcelain worktree metadata. | Read-only cards for linked worktrees with branch, dirty/build/PR summaries, and open/reveal/copy actions. | Must not become a git client, build runner, worktree manager, or second project registry. |
| README / Plugin Docs Hub | Surface's README already defines the block/plugin path and preview loop; plugin READMEs can hold owner-specific contracts. | Read-only docs cards for README/AGENTS/docs/plugin READMEs/research specs with heading, link, and command copy actions. | Must not become a Markdown editor, DocC generator, scaffolder, health checker, or second plugin registry. |
| Registry Health | Surface already has one `Blocks.registry`, explicit Package.swift target wiring, and preview smoke tests. | Read a generated status report and show registry/package/test/fixture/layout mismatches with open/copy actions. | Must not generate registry files, mutate Package.swift, run tests/previews, scaffold plugins, or create a second registry. |
| Plugin Templates | Raycast and VS Code show starter templates reduce authoring friction; Surface already has local plugin examples and a README checklist. | Copy-only pattern cards for minimal block, runtime lifecycle, context gates, fixtures, tests, wiring, and README outline. | Must not generate files, edit Package.swift/Blocks.swift, run commands, maintain a marketplace, or duplicate Readme Hub/Registry Health. |
| Diagnostic Bundle | Surface specs now produce status reports, preview PNGs, event summaries, and docs indexes that are useful for support. | Explicitly export selected existing artifacts into a local folder with summary and redaction report. | Must not upload, tail logs, run sysdiagnose, collect private stores, scan arbitrary folders, or become telemetry. |
| Preview Gallery | Surface already renders real block fixtures to `.build/block-previews`; inspecting those PNGs is part of the dev loop. | Read-only gallery for existing preview PNGs, metadata, stale labels, and copyable render commands. | Must not render previews, run tests, manage screenshots, export artifacts, or own visual diff/baseline approval. |
| Crash Report Pointers | Local crash artifacts are useful for debugging, but Console, Xcode, and MetricKit already own browsing, analysis, and collection. | Read explicit `.ips`/`.crash` files from a manifest, show top metadata and stale/missing warnings, and copy redacted summaries. | Must not scan DiagnosticReports folders, tail logs, symbolicate, upload/export, install crash reporters, or duplicate file inbox/export owners. |
| Calendar / Next Meeting | Raycast has Calendar in core daily tools. | Read macOS Calendar or a fixture; show next event and prep notes. | Calendar permission and account state. |
| Snippet / Prompt Palette | Raycast has snippets and quicklinks. | Local JSON/Markdown snippets with copy buttons and tags. | Overlaps with Raycast unless Surface adds context-aware snippets. |
| System Health | Ubersicht and SwiftBar prove ambient status is useful, while Apple APIs give low-risk direct signals. | Show only actionable local conditions: low disk, thermal pressure, Low Power Mode, constrained/offline network, and low battery. | Must avoid becoming passive CPU/memory/sensor graphs; custom metrics belong in `scriptoutput`. |
| Link Inbox | Raycast Quicklinks validate URL/deeplink workflows, and Surface already has Copy History for general clipboard text. | Clipboard/file-backed URL queue with cached titles, open/archive/pin/copy Markdown actions, and no automatic metadata fetch in v1. | Must not duplicate Copy History or make previews depend on network title fetches. |
| Scratch Capture Stack | Dropzone Drop Bar, Yoink, Dropover, and Unclutter validate temporary visible shelves for scattered working items. | Local JSON stack of explicit text/URL/file/note refs with copy/open/reveal/pin/done/remove actions. | Must not become a universal inbox, file manager, clipboard watcher, URL inbox, or action runner. |
| Package Tracker / Deliveries | Widget/menu-bar apps often show ambient external status. | Fixture-first package list with carrier links. | Needs external APIs or manual entry. |
| Finance Watchlist | xbar stock ticker examples validate this pattern. | Local watchlist, price/percent rows, no trading. | Market data source stability. |
| Obsidian Queue | Quicksave and Codex Log already prove local markdown plus approval queues. | Show daily-note status, capture count, and pending Obsidian action rows. | Must avoid mutating the vault without approval. |

## More Speculative

| Plugin | Shape | Why Not First |
| --- | --- | --- |
| Hammerspoon Bridge | Read Hammerspoon-exported status/command manifest and optionally open predeclared trigger URLs. | Must not become a Lua runner, Spoon manager, or duplicate `scriptoutput`. |
| Keyboard Maestro Bridge | Read a curated Keyboard Maestro-exported manifest and optionally open predeclared local `kmtrigger://` or editor URLs. | Must not become a macro runner, editor, CLI wrapper, or plug-in action installer. |
| Browser Session Cards | Active tab/session snapshot with copy/open/capture handoff. | Requires explicit Automation, extension, or debug adapter; must avoid history/profile scraping. |
| AI Command Scratchpad | Local AI run cards with assembled prompts, context references, copy actions, and manual/external outputs. | Must not become generic chat UI, provider credential store, or duplicate `snippetprompt`. |
| Notification Digest | Group Surface/plugin-owned event rows by source and actionability. | macOS-wide notification history is not exposed through supported public APIs. |
| Media Controls | Audio route/device switcher with optional external now-playing cache. | Generic Now Playing control would require private or source-specific APIs. |
| Contact Quick Look | Fixture/cached contact cards plus explicit exact lookup by Contacts identifier, email, or phone. | Requires Contacts permission, `NSContactsUsageDescription`, and strict no-broad-read boundaries. |
| Bookmark Cards | Curated local bookmark/read-later shelves with open/copy/mark actions. | Must not duplicate `linkinbox` or read browser profiles/history in v1. |
| Text Transform | Deterministic built-in transforms over explicit input with copy-only output. | Must not become selected-text automation, AI rewrite, or custom script runner. |
| App Quick Launch | Curated app/file/folder/URL/deeplink launch cards with explicit open/focus/reveal/copy actions. | Must not become Spotlight/Raycast search, app indexing, global hotkeys, macro execution, or workspace restore. |
| Copy History Rules | Copy History-owned capture filters, pause/ignore-next controls, and metadata-only blocked counters. | Must not become a separate clipboard daemon, scriptable rule engine, or cross-plugin router. |
| Workspace Pins | Curated project cards with root path, primary launch, note, refs, context match, and cached recent-file summary. | Must not become multi-app session restore, Spaces control, build runner, or project registry. |

## Best Implementation Order

1. `githubqueue`: developer queue, local CLI/fixture first.
2. `fileinbox`: local file triage, no credentials.
3. `contextcard`: app/window context, no-AX v1 with permission-aware v2.
4. `obsidianqueue`: builds on Quicksave and Codex Log queue patterns.
5. `permissionsdashboard`: needed before permission-heavy v2 plugins.
6. `focus`: timer and state, low integration risk.

## Design Rules For These Plugins

- Each idea must enter as one `BlockRuntime`, not a new manager.
- Every plugin needs at least two fixtures: empty and representative.
- External services start fixture-first; live credentials come later.
- Permission-heavy plugins must show blocked/needs-permission states inside the block.
- Action rows should use icon buttons for copy/open/reveal/approve/deny, matching the Copy History update.
- Visual baseline comparison is not a plugin. Keep rendering, record/check commands, and baseline enforcement in `block-preview`/`BlockPreviewTests`; `previewgallery` may only display reports read-only.
- Visual artifact retention is not a plugin. Keep generated current/diff/report files under ignored `.build`, upload CI failure artifacts with short retention, and add Git LFS only after measured baseline size warrants it.
- Baseline platform policy is not a plugin. Start with one pinned visual-baseline lane, record OS/architecture/scale metadata, and add more lanes only after measured renderer variance proves they are necessary.
- Renderer scale control is not a plugin. Add one small `BlockImageRenderer` configuration for fixed scale, appearance, and locale before adding any second visual-baseline platform lane.
- Visual baseline report schema is not a plugin or schema registry. Keep one `.build/surface-status/visualbaselines.json` contract owned by `visualbaselines`, with platform, renderer, artifact policy, tolerance policy, summary, and ordered results.
- Crash symbolication is not a plugin or hidden runner. Keep it as copied Xcode/CLI handoff inside `crashreports`; execution belongs to Xcode, developer tools, `scriptoutput`, or an external producer.
- dSYM catalogs are not a plugin or symbol store. Keep them as explicit JSON manifests read by `crashreports`; discovery, download, UUID verification, and symbolication stay with Xcode, App Store Connect, developer tools, `scriptoutput`, or external producers.
- Crash attachment policy is not a plugin or exporter. Keep it as `diagnosticbundle` artifact classification: summaries and handoff text can export by default, raw crash/symbol outputs require manual review, and dSYM/archive/app/sysdiagnose binaries are excluded by default in v1.
- Diagnostic bundle redaction keys are not a plugin or sanitizer service. Keep the first version as fixed `diagnosticbundle` constants over JSON/JSONL only, with deterministic tokens, summary formatting, and no arbitrary text-log scrubbing.

## Cycle 2 Promotion: `githubqueue`

`githubqueue` is now concrete enough to implement. See `githubqueue-spec.md`.

Implementation should start current-repo only, with:

- `gh pr list --json number,title,url,headRefName,baseRefName,author,isDraft,reviewDecision,updatedAt`
- Optional `gh pr checks <number> --json name,state,bucket,startedAt,completedAt,link`
- Fixture path through `Block.Context.storageDirectory`
- Preview fixtures: `empty`, `mixed-prs`
- Blocked state for missing `gh`, unauthenticated `gh`, or non-git directories

## Cycle 3 Promotion: `fileinbox`

`fileinbox` is concrete enough to implement after `githubqueue`, or before it if a credentials-free plugin is preferred. See `fileinbox-spec.md`.

The boundary matters:

- Use watched directories and recent-file triage.
- Do not implement a Hazel-style rule engine.
- Do not implement Dropzone-style arbitrary scripting.
- Do not clone Raycast global file search.
- Start with open, reveal, copy path, copy Markdown link, and disabled archive.

## Cycle 4 Promotion: `contextcard`

`contextcard` is now concrete enough to implement as a no-Accessibility v1. See `contextcard-spec.md`.

Implementation should start with:

- `NSWorkspace.shared.frontmostApplication`
- `NSWorkspace.didActivateApplicationNotification`
- `NSRunningApplication` metadata
- Best-effort `CGWindowListCopyWindowInfo` title lookup
- No selected-text capture until AX permission handling exists

This slightly lowers the risk of `contextcard`: the original concern was broad Accessibility permission, but v1 can avoid that entirely.

## Cycle 5 Promotion: `permissionsdashboard`

`permissionsdashboard` is now concrete enough to implement. See `permissionsdashboard-spec.md`.

It should sit between local-first plugins and permission-heavy plugins:

- Implement after `githubqueue` or `fileinbox`.
- Implement before `contextcard` v2, `windowlayouts`, Calendar, Contacts, browser automation, Screen Recording, or Input Monitoring ideas.
- Keep permission checking plugin-local at first; do not add a shared permission framework until multiple plugins consume it.
- Update `script/build_and_run.sh` / bundle Info.plist generation before shipping EventKit, Contacts, or Apple Events functionality.

## Cycle 6 Promotion: `obsidianqueue`

`obsidianqueue` is now concrete enough to implement. See `obsidianqueue-spec.md`.

The boundary is the main design point:

- Quicksave remains the owner for daily-note writes, template fallback, media copying, and configured Obsidian paths.
- Codex Log remains the owner for the append-only action log and generic approve/deny UI.
- `obsidianqueue` becomes a domain dashboard for daily-note status, Quicksave capture status, and pending Obsidian-specific action rows.
- v1 should be file/URI backed. Obsidian CLI can enrich daily/search/tasks behavior later, but should not be required for preview/tests or startup.

## Cycle 7 Promotion: `focus`

`focus` is now concrete enough to implement. See `focus-spec.md`.

The first version should be deliberately small:

- Store one local `focus-state.json` file.
- Derive timer state from timestamps and `Block.Context.now`, so quitting/reopening the app does not require a hidden daemon.
- Use configurable focus/break durations with Pomodoro-style defaults.
- Expose only local controls: start, pause/resume, skip, reset, copy summary.
- Do not toggle macOS Focus, use Screen Time APIs, block apps/sites, or add Focus Filters in v1.

## Cycle 8 Promotion: `scriptoutput`

`scriptoutput` is now concrete enough to implement. See `scriptoutput-spec.md`.

The first version should be constrained by design:

- One explicitly configured executable, not a plugin folder.
- Direct executable path plus argument array, not shell-string interpolation.
- Scheduled refresh with timeout and output byte caps.
- Parse only a safe xbar/SwiftBar stdout subset.
- Render `href` as an open action, but ignore `shell`, `bash`, `param`, `terminal`, `refresh`, variables, nested submenus, and xbar control APIs.
- Keep preview/test fixtures file-backed so no script runs during block preview.

## Cycle 9 Promotion: `localbuildstatus`

`localbuildstatus` is now concrete enough to implement. See `localbuildstatus-spec.md`.

The first version should be read-only:

- Use `git status --porcelain=v2 --branch` for branch, ahead/behind, dirty, untracked, and conflict state.
- Read build/test/preview status from `.build/surface-status/last-build.json`, `last-test.json`, and `last-preview.json`.
- Keep `.build/surface-status` as the default result directory because `.build/` is already ignored in this repo.
- Copy or reveal command/log paths, but do not run `swift build`, `swift test`, block previews, or arbitrary commands.
- Treat the external runner as the write owner for result files.

## Cycle 10 Promotion: `systemhealth`

`systemhealth` is now concrete enough to implement. See `systemhealth-spec.md`.

The first version should stay actionable:

- Use direct Apple APIs: `ProcessInfo` thermal/power, `URLResourceValues` disk capacity, `NWPathMonitor`, and IOKit power sources.
- Roll up conditions into OK/Watch/Attention, then show only the top few actionable rows.
- Avoid CPU/memory/fan/sensor graphs, speed tests, pings, and shell commands.
- Route custom status scripts to `scriptoutput` instead of expanding this block.
- Use fixture snapshots through `Block.Context.storageDirectory` for previews/tests.

## Cycle 11 Promotion: `linkinbox`

`linkinbox` is now concrete enough to implement. See `linkinbox-spec.md`.

The first version should be clipboard/file-backed:

- Store URL records in `linkinbox-links.jsonl` with optional cached titles.
- Capture URL pasteboard data and string URLs, but do not become a general clipboard history.
- Do not fetch titles automatically. Use stored title, cached metadata, pasteboard link text, or host/path fallback.
- Keep `LPMetadataProvider` as an explicit later title-fetch action with cache, timeout, and preview disablement.
- Use `NSWorkspace.open(_:)` for open actions and pasteboard writes for copy URL / copy Markdown.

## Cycle 12 Promotion: `calendarprep`

`calendarprep` is now concrete enough to implement as a fixture-first read-only block. See `calendarprep-spec.md`.

The first version should stay narrow:

- Use `calendarprep-events.json` fixtures through `Block.Context.storageDirectory` for previews/tests.
- Live support requires `NSCalendarsFullAccessUsageDescription` in the bundle and `EKEventStore.authorizationStatus(for: .event)` checks.
- Request full Calendar access only from an explicit user action, ideally through `permissionsdashboard`.
- Query a short future range with `predicateForEvents(withStart:end:calendars:)`, fetch with `events(matching:)`, and sort before display.
- Show next meeting, short lookahead rows, and copy/open actions; do not create/edit/delete events, auto-join calls, or email attendees in v1.

## Cycle 13 Promotion: `snippetprompt`

`snippetprompt` is now concrete enough to implement as a local read/copy block. See `snippetprompt-spec.md`.

The first version should stay deliberately bounded:

- Read `snippetprompt-library.json` from `Block.Context.storageDirectory` in previews/tests or Application Support in live mode.
- Resolve only safe placeholders: date/time, explicit arguments, explicit fixture/context JSON, and clipboard text on user copy action.
- Reuse/factor pasteboard write behavior with Copy History only when implementation proves a shared helper is needed.
- Do not add typed auto-expansion, global keyboard monitoring, AI execution, browser-tab reading, selected-text scraping, shell placeholders, or in-place active-app replacement.
- Add `empty`, `mixed-library`, `needs-context`, and `context-ready` preview fixtures.

## Cycle 14 Promotion: `windowlayouts`

`windowlayouts` is now concrete enough to implement as an Accessibility-gated focused-window action block. See `windowlayouts-spec.md`.

The first version should be explicit and small:

- Reuse `permissionsdashboard` for Accessibility status/request flow.
- Reuse `contextcard`-style frontmost app/window identity; do not add a second context owner.
- Read fixtures from `windowlayouts-layouts.json` and `windowlayouts-snapshot.json`; preview apply/save actions are no-ops.
- Live actions should operate only on the focused window using AX focused-window, position, and size attributes.
- Start with halves, thirds, center, maximize, restore, and save current frame. Defer global hotkeys, automatic tiling, multi-app workspace restore, fullscreen toggles, display/Space movement, and app launching.

## Cycle 15 Promotion: `packagewatch`

`packagewatch` is now concrete enough to implement as a local/manual package ledger. See `packagewatch-spec.md`.

The first version should avoid live integrations:

- Read `packagewatch-packages.json` from `Block.Context.storageDirectory` in previews/tests or Application Support in live mode.
- Group by arriving today, needs attention, in transit, delivered, and archived.
- Store manual/cached package records with carrier, tracking number, status, ETA, note, and tracking URL.
- Open a stored URL or 17TRACK universal tracking URL only from explicit row actions.
- Do not poll carrier APIs, require carrier credentials, scrape email/Wallet/merchant accounts, run webhooks, or infer status from tracking pages.
- Add `empty`, `active-deliveries`, `attention`, and `archived` preview fixtures.

## Cycle 16 Promotion: `financewatch`

`financewatch` is now concrete enough to implement as a local/cached watchlist block. See `financewatch-spec.md`.

The first version should be informational only:

- Read `financewatch-watchlist.json` from `Block.Context.storageDirectory` in previews/tests or Application Support in live mode.
- Show cached/manual prices, day change, percent change, currency, source, and stale age.
- Treat external quote data as cache written by `scriptoutput`, an external job, or a later explicit integration.
- Do not fetch live quotes in the block runtime, store API keys, connect broker accounts, show balances/cost basis, place trades, or generate buy/sell signals.
- Add `empty`, `mixed-watchlist`, `stale-data`, and `external-cache` preview fixtures.

## Cycle 17 Promotion: `notificationdigest`

`notificationdigest` is now concrete enough to implement as a local Surface-owned event digest. See `notificationdigest-spec.md`.

The first version should be file-backed and app-scoped:

- Read `notificationdigest-events.jsonl` and optional `notificationdigest-settings.json` from `Block.Context.storageDirectory` in previews/tests or Application Support in live mode.
- Show unread/attention rows with source, severity, title, detail, age, read/archive state, and explicit open/copy actions.
- Treat `UNUserNotificationCenter.getDeliveredNotifications` as optional Surface-owned notification supplement only.
- Reuse `permissionsdashboard` for notification permission status/request flow.
- Do not read other apps' notifications, scrape Notification Center databases, use Accessibility/OCR, mine global unified logs, poll services, schedule alerts, or duplicate Codex Log/source-specific queues.
- Add `empty`, `mixed-events`, `attention-unread`, `muted-and-archived`, and `permission-blocked` preview fixtures.

## Cycle 18 Promotion: `mediacontrols`

`mediacontrols` is now concrete enough to implement only as a narrow audio-route block. See `mediacontrols-spec.md`.

The first version should avoid generic playback control:

- Read `mediacontrols-audio.json`, optional `mediacontrols-presets.json`, and optional `mediacontrols-nowplaying.json` from `Block.Context.storageDirectory` in previews/tests.
- In live mode, use a small public Core Audio adapter, preferably `AudioHardwareSystem` on supported macOS versions, for device/default route state.
- Support explicit set-output, set-input, set-sound-effects, apply-preset, save-preset, copy-summary, and open-Sound-settings actions.
- Treat now-playing data as externally cached context only; do not render play/pause/skip in v1.
- Do not use private MediaRemote, scrape system Now Playing, use AppleScript/Apple Events, add Spotify/Music/browser clients, connect Bluetooth/AirPlay, enforce routes in a loop, or add a second registry.
- Add `simple-output`, `desk-setup`, `missing-preset-target`, `cached-nowplaying`, and `unsupported-live` preview fixtures.

## Cycle 19 Promotion: `browsersessioncards`

`browsersessioncards` is now concrete enough to implement as a fixture-first active-browser snapshot block. See `browsersessioncards-spec.md`.

The first version should stay read/copy/capture-only:

- Read `browsersessioncards-session.json` from `Block.Context.storageDirectory` in previews/tests.
- Reuse or factor `contextcard`-style frontmost app identity only after implementation proves both call sites need it.
- Support explicit adapters later: Apple Events/Scripting Bridge after Automation permission, browser extension/native messaging cache after deliberate install, or Chrome DevTools only when the user configures a local debug endpoint.
- Show active tab first, then a short bounded list of other tabs when the adapter provides them.
- Handoff URLs to `linkinbox` instead of owning durable URL triage.
- Do not read browser history/profile databases, import bookmarks, scrape page content, run JavaScript, capture screenshots/OCR, mutate tabs, install extensions, launch debug browsers, or add a second registry.
- Add `empty`, `active-tab`, `research-session`, `blocked-automation`, `extension-cache`, and `devtools-cache` preview fixtures.

## Cycle 20 Promotion: `aicommandscratchpad`

`aicommandscratchpad` is now concrete enough to implement as a local per-run scratchpad. See `aicommandscratchpad-spec.md`.

The first version should stay local and copy-oriented:

- Read `aicommandscratchpad-runs.jsonl` and optional `aicommandscratchpad-context.json` from `Block.Context.storageDirectory` in previews/tests.
- Store per-run assembled instructions, input, context references, status, provider/model labels, and pasted or externally written output.
- Group by running external, ready/needs-output, draft, failed, and completed recent.
- Copy assembled prompt, message JSON, run Markdown, and output.
- Capture clipboard as input/output only from explicit actions.
- Treat `snippetprompt` as the reusable template owner and source; do not duplicate its template library.
- Do not call AI APIs, store provider keys, stream responses, render chat threads, run tools/scripts/MCP, read selected text/browser content, replace active-app text, or add a second registry.
- Add `empty`, `draft-run`, `ready-with-context`, `waiting-output`, `external-output`, and `archived-completed` preview fixtures.

## Cycle 21 Promotion: `hammerspoonbridge`

`hammerspoonbridge` is now concrete enough to implement as a read-mostly Hammerspoon manifest bridge. See `hammerspoonbridge-spec.md`.

The first version should keep Hammerspoon as the automation owner:

- Read `hammerspoonbridge-state.json` from `Block.Context.storageDirectory` in previews/tests or Application Support in live mode.
- Show exported Hammerspoon app/config/IPC status, command rows, hotkeys, last-run age, and status rows.
- Use `Block.Context.now` for bridge and row stale labels.
- Allow copy/open/reveal actions and, only when allowed, open predeclared `hammerspoon://...` trigger URLs from decoded command rows.
- Do not run `hs`, evaluate Lua, call `hs -c`, install Spoons, edit config, register hotkeys, inspect arbitrary config files, request Hammerspoon permissions, or duplicate `scriptoutput`.
- Add `missing`, `ready-commands`, `stale-export`, `warnings`, and `trigger-disabled` preview fixtures.

## Cycle 22 Promotion: `keyboardmaestrobridge`

`keyboardmaestrobridge` is now concrete enough to implement as a curated Keyboard Maestro manifest bridge. See `keyboardmaestrobridge-spec.md`.

The first version should keep Keyboard Maestro as the automation owner:

- Read `keyboardmaestrobridge-state.json` from `Block.Context.storageDirectory` in previews/tests or Application Support in live mode.
- Show exported engine/editor status, macro rows, trigger labels, last-run age, and status rows.
- Use `Block.Context.now` for bridge and row stale labels.
- Allow copy/open/reveal actions and, only when allowed, open decoded local `kmtrigger://` trigger URLs or `keyboardmaestro://m=` editor URLs from manifest rows.
- Do not run AppleScript, `osascript`, the `keyboardmaestro` CLI, action XML, remote trigger URLs, macro import/export, or Keyboard Maestro plug-in actions.
- Add `missing`, `ready-macros`, `stale-export`, `disabled-macros`, `trigger-disabled`, and `warnings` preview fixtures.

## Cycle 23 Promotion: `contactquicklook`

`contactquicklook` is now concrete enough to implement as a privacy-first contact card block. See `contactquicklook-spec.md`.

The first version should stay fixture-first and exact-lookup only:

- Read `contactquicklook-contacts.json` from `Block.Context.storageDirectory` in previews/tests or Application Support in live mode.
- Show compact cached/contact rows with name, organization/title, email, phone, URL, source, and stale labels.
- Use `Block.Context.now` for cache/card stale labels.
- Reuse `permissionsdashboard` for Contacts status/request flow and require `NSContactsUsageDescription` before live lookup ships.
- Live lookup may use exact Contacts identifiers, email predicates, or phone predicates only after explicit user action.
- Do not enumerate all contacts, build broad search, create/edit/delete/merge contacts, background-sync the address book, infer relationships, or auto-match clipboard/selected text.
- Add `empty`, `cached-cards`, `blocked-permission`, `exact-email-match`, `stale-cache`, and `partial-fields` preview fixtures.

## Cycle 24 Promotion: `bookmarkcards`

`bookmarkcards` is now concrete enough to implement as a local bookmark/read-later shelf. See `bookmarkcards-spec.md`.

The first version should stay file-backed and separate from `linkinbox`:

- Read `bookmarkcards-bookmarks.json` from `Block.Context.storageDirectory` in previews/tests or Application Support in live mode.
- Show curated bookmark rows with title, URL host/path, shelf, tags, state, source, age, and pinned/read/archive state.
- Use `Block.Context.now` for cache and row stale labels.
- Allow explicit open/copy/pin/mark-read/archive actions only against local JSON records.
- Treat browser bookmark APIs, exported bookmark HTML, `.webloc` folders, and browser-extension caches as future explicit import paths that write the same local JSON shape.
- Do not read browser profile files, browser history, active tabs, page content, WebExtension bookmark APIs, or network metadata in v1.
- Add `empty`, `curated-shelves`, `read-later`, `stale-import`, `read-only`, and `linkinbox-handoff` preview fixtures.

## Cycle 25 Promotion: `texttransform`

`texttransform` is now concrete enough to implement as a local deterministic text utility. See `texttransform-spec.md`.

The first version should stay explicit-input and copy-only:

- Read `texttransform-state.json` from `Block.Context.storageDirectory` in previews/tests or Application Support in live mode.
- Support built-in transforms for plain text, whitespace cleanup, case changes, slugify, URL encode/decode, Base64 encode/decode, JSON string escape, and Markdown quote/code fence.
- Use Foundation/Swift APIs for transforms where possible, including `StringTransform`, percent encoding, Base64 data APIs, JSON serialization, and fixed internal regexes.
- Reuse/factor pasteboard writes with Copy History or `snippetprompt` only after implementation proves the shared adapter is needed.
- Do not watch clipboard passively, read selected text, paste into active apps, run scripts/Shortcuts/AppleScript, expose custom regex pipelines, call AI APIs, or duplicate `snippetprompt` templates.
- Add `empty`, `clean-whitespace`, `case-and-slug`, `url-json`, `base64-error`, and `markdown` preview fixtures.

## Cycle 26 Promotion: `appquicklaunch`

`appquicklaunch` is now concrete enough to implement as a curated local launch shelf. See `appquicklaunch-spec.md`.

The first version should stay explicit and JSON-backed:

- Read `appquicklaunch-items.json` from `Block.Context.storageDirectory` in previews/tests or Application Support in live mode.
- Support only curated targets: app by bundle id/path, file, folder, URL, and deeplink.
- Use AppKit APIs directly: `NSWorkspace.urlForApplication`, `NSWorkspace.openApplication`, `NSRunningApplication.runningApplications`, `activate(options:)`, `NSWorkspace.open`, and `activateFileViewerSelecting`.
- Keep the workspace opener as a tiny injected adapter, plugin-local until `contextcard`, `fileinbox`, or `bookmarkcards` prove a shared adapter is needed.
- Reuse existing owners: `contextcard` for front-app state, `fileinbox` for recent files, `linkinbox` for URL triage, `bookmarkcards` for bookmark shelves, and automation bridges for macros/scripts.
- Do not enumerate installed apps, query Spotlight, add global hotkeys, read selected text/browser tabs/clipboard, run scripts/AppleScript/Shortcuts/macros, select menu items, move windows, restore workspaces, or add a second registry.
- Add `empty`, `apps-ready`, `project-files`, `urls-and-deeplinks`, `missing-targets`, and `external-actions-blocked` preview fixtures.

## Cycle 27 Promotion: `clipboardrules`

`clipboardrules` is concrete enough only as a Copy History-owned enhancement, not as a new plugin target. See `clipboardrules-spec.md`.

The first version should extend the existing `copyhistory` runtime:

- Read `copyhistory-rules.json` next to `copyhistory.txt`.
- Keep the existing Copy History pasteboard polling loop and storage owner.
- Evaluate a pure capture decision before `CopyHistoryStore.add`.
- Ignore transient/concealed/autogenerated/proprietary pasteboard marker types by default.
- Support pause capture, ignore next copy, max character limit, and source-marker bundle exclusions.
- Persist only accepted text entries; blocked events may store metadata-only counts/reasons, never blocked text, hashes, or excerpts.
- Do not add `plugins/clipboardrules`, a new package target, registry entry, second pasteboard watcher, active-app monitoring, scripts/macros, transformations, routing, network enrichment, AI, or active-app paste.
- Extend the `copyhistory` preview fixtures with `rules-paused`, `rules-filtered`, `rules-invalid`, and `rules-sensitive`.

## Cycle 28 Promotion: `workspacepins`

`workspacepins` is now concrete enough to implement as a curated project-card block. See `workspacepins-spec.md`.

The first version should stay read-mostly and composition-oriented:

- Read `workspacepins-workspaces.json` from `Block.Context.storageDirectory` in previews/tests or Application Support in live mode.
- Show one card per explicit workspace with root path, primary launch, note, tags, refs, current-context match, and optional cached recent-file summary.
- Use optional fixture/cache files only when explicitly configured: `workspacepins-context.json` and `workspacepins-recent-files.json`.
- Reuse existing owners conceptually: `appquicklaunch` owns single target launch rows, `fileinbox` owns recent-file scanning, `contextcard` owns current app/window snapshots, `bookmarkcards`/`linkinbox` own links, `windowlayouts` owns window movement, and `scriptoutput`/`localbuildstatus` own commands/status.
- Open/reveal/copy exactly one configured target per user action.
- Do not launch groups of apps/tabs/files, switch Spaces, control Stage Manager, move windows, scan recent files, run commands/builds/git/scripts/macros, mutate other plugin stores, create a project registry, or add a second registry.
- Add `empty`, `active-project`, `multi-projects`, `missing-root`, `recent-cache`, and `read-only` preview fixtures.

## Cycle 29 Promotion: `scratchcapturestack`

`scratchcapturestack` is now concrete enough to implement as a short-lived mixed-reference shelf. See `scratchcapturestack-spec.md`.

The first version should stay bounded, explicit, and reference-only:

- Read `scratchcapturestack-items.json`.
- Show a short stack of explicit `text`, `url`, `file`, `note`, and `ref` items.
- `quicksave` owns durable capture and Obsidian writes; `fileinbox` owns file scanning; Copy History owns passive clipboard history; `linkinbox` owns URL triage; `bookmarkcards` owns durable shelves.
- Store file/URL refs rather than copying file payloads or fetching URL metadata.
- Store direct text only when the user explicitly adds that text to the stack.
- Support copy/open/reveal/pin/unpin/mark-done/remove/clear-expired actions against stack records only.
- Do not watch the clipboard, scan directories, read browser state, fetch metadata, mutate source plugin stores, run scripts/macros/uploads/processors, become a universal inbox or file manager, or add a second registry.
- Add `empty`, `mixed-stack`, `pinned-items`, `expired-items`, `missing-file`, and `read-only` preview fixtures.

## Cycle 30 Promotion: `worktreecards`

`worktreecards` is now concrete enough to implement as a read-only worktree dashboard. See `worktreecards-spec.md`.

The first version should stay cache-backed and non-mutating:

- Read `worktreecards-worktrees.json` in previews/tests or `worktreecards-config.json` in live mode.
- Use `git worktree list --porcelain -z` only for read-only discovery when live processes are allowed.
- Reuse/factor `localbuildstatus` git-status/result parsing only after implementation proves overlap.
- Join PR data only from `githubqueue` cache/handoff, not a second GitHub query owner.
- Join recent files only from explicit File Inbox/external cache files.
- Support open/reveal/copy/open-PR actions over one worktree at a time.
- Do not create/remove/prune/repair/lock worktrees, checkout/switch branches, stage/commit/stash/pull/push/fetch, run builds/tests/previews, run editor CLIs, mutate other plugin stores, launch groups, or add a second registry.
- Add `empty`, `multi-worktrees`, `dirty-failing`, `locked-prunable`, `pr-linked`, and `read-only` preview fixtures.

## Cycle 31 Promotion: `readmehub`

`readmehub` is now concrete enough to implement as a read-only documentation index. See `readmehub-spec.md`.

The first version should expose canonical local docs without becoming tooling:

- Read `readmehub-index.json`.
- Default to bounded local docs only: `README.md`, `AGENTS.md`, `docs/*.md`, `plugins/*/README.md`, and `research/README.md`.
- Include `research/*-spec.md` only when configured.
- Extract headings, local Markdown links, and fenced shell command strings; do not render or edit Markdown.
- Surface the existing README add-a-plugin checklist and preview commands as read-only/copyable rows.
- Open/reveal docs and copy paths, Markdown links, commands, or checklists.
- Do not generate READMEs/DocC/templates, run commands, validate registry/preview/test health, scan the whole repo, create plugins, mutate Package.swift or `plugins/Blocks.swift`, launch editor CLIs, or add a second registry.
- Add `empty`, `surface-docs`, `plugin-authoring`, `research-specs`, `missing-docs`, and `read-only` preview fixtures.

## Cycle 32 Promotion: `registryhealth`

`registryhealth` is now concrete enough to implement as a read-only plugin wiring health view. See `registryhealth-spec.md`.

The first version should stay report-backed and non-mutating:

- Read `registryhealth-status.json` from `Block.Context.storageDirectory` in previews/tests or one configured generated-report path in live mode.
- Show each block's registry, package target, plugin tests, preview fixture coverage, default layout status, and preview render status.
- Use `Block.Context.now` for missing/stale report labels.
- Open/reveal/copy only the existing owner files and verification commands.
- Keep the active registry in `plugins/Blocks.swift`; if a generator exists later, it should write that file/report outside this block.
- Do not generate registry files, mutate `Package.swift`, edit layout/fixture/test files, run tests/previews, parse arbitrary Swift ASTs, scaffold plugins, duplicate `localbuildstatus`/`readmehub`/`scriptoutput`, or add a second registry.
- Add `empty`, `healthy-current`, `missing-fixtures`, `package-mismatch`, `preview-failed`, `stale-report`, and `read-only` preview fixtures.

## Cycle 33 Promotion: `plugintemplates`

`plugintemplates` is now concrete enough to implement as a copy-only plugin authoring reference block. See `plugintemplates-spec.md`.

The first version should stay read-only and snippet/checklist-oriented:

- Read optional `plugintemplates-catalog.json` from `Block.Context.storageDirectory` in previews/tests or Application Support in live mode.
- Fall back to plugin-local default pattern cards.
- Show minimal block, runtime lifecycle, context gates, file-backed state, action row, focused tests, preview fixture, package/registry wiring, and plugin README outline patterns.
- Open/reveal local example files and copy snippets, checklists, and validation commands.
- Reuse existing owners: `readmehub` for docs, `registryhealth` for wiring validation, `scriptoutput` for command execution, README for the canonical checklist, and existing plugins for examples.
- Do not create files/folders, mutate `Package.swift`/`plugins/Blocks.swift`/layout/fixture/test files, run commands, parse arbitrary Swift ASTs, add a template marketplace, fetch remote templates, or add a second registry.
- Add `empty`, `minimal-authoring`, `file-backed`, `live-gated`, `fixtures-and-tests`, `docs-outline`, and `read-only` preview fixtures.

## Cycle 34 Promotion: `diagnosticbundle`

`diagnosticbundle` is now concrete enough to implement as an explicit local support export block. See `diagnosticbundle-spec.md`.

The first version should stay manifest-backed and local-only:

- Read `diagnosticbundle-manifest.json` from `Block.Context.storageDirectory` in previews/tests or Application Support in live mode.
- Show selected artifacts with source plugin, kind, path, size, age, redaction mode, and missing/stale/oversized/manual-review status.
- Export only selected allowlisted files into a local folder when external writes are allowed.
- Generate `summary.md`, `manifest.json`, and `redaction-report.json`.
- Reuse existing owners: `localbuildstatus` for build/test/preview result files, `registryhealth` for registry reports, `readmehub` for docs indexes, `notificationdigest` for event summaries, `scriptoutput` for any command-produced artifacts, and block-preview for PNG generation.
- Do not upload, email, AirDrop, run commands, trigger sysdiagnose, tail/read unified logs, collect Keychain/env/browser/contact/calendar/clipboard/Codex databases by default, scan arbitrary folders, compress archives, mutate source stores, or add a second registry.
- Add `empty`, `ready-artifacts`, `stale-and-missing`, `manual-review`, `redacted-events`, `oversized`, and `export-disabled` preview fixtures.

## Cycle 35 Promotion: `previewgallery`

`previewgallery` is now concrete enough to implement as a read-only block-preview artifact viewer. See `previewgallery-spec.md`.

The first version should stay read-only and output-directory-backed:

- Read optional `previewgallery-index.json` from `Block.Context.storageDirectory` in previews/tests or Application Support in live mode.
- Read PNGs from a configured preview output directory, defaulting to `.build/block-previews` when a repo root is configured.
- Parse known filenames such as `<block-id>-<fixture>.png` and `surface-active.png`.
- Show thumbnail, block id, fixture, dimensions, byte size, modified age, optional metrics, and stale/missing/failed/unknown status.
- Open/reveal/copy paths, copy Markdown image links, copy render commands, and copy a gallery summary.
- Reuse existing owners: `block-preview` for rendering and metrics, `BlockPreviewTests` for fixture/nonblank enforcement, `registryhealth` for coverage, `localbuildstatus` for last run status, and `diagnosticbundle` for export.
- Do not render previews, run tests/commands, instantiate block runtimes, take desktop screenshots, scan arbitrary image folders, mutate/delete/export images, implement visual baselines/diffs/approvals, or add a second registry.
- Add `empty`, `current-previews`, `stale-previews`, `missing-indexed`, `failed-metrics`, `unknown-files`, and `read-only` preview fixtures.

## Cycle 36 Promotion: `crashreports`

`crashreports` is now concrete enough to implement as an explicit crash artifact pointer block. See `crashreports-spec.md`.

The first version should stay manifest-backed and non-collecting:

- Read `crashreports-index.json` from `Block.Context.storageDirectory` in previews/tests or Application Support in live mode.
- Support only explicit `.ips` and `.crash` paths from the manifest.
- Parse bounded metadata: process/app name, bundle id, incident id, report date, OS version, app version, exception type, termination reason, triggered thread, file size, and modified age.
- Show ready, stale, missing, unreadable, oversized, unsupported, and parse-warning states.
- Open/reveal/copy explicit files, copy paths, copy Markdown summaries, and copy redacted issue snippets.
- Reuse existing owners: Console/Finder for browsing crash directories, Xcode for analysis/symbolication, MetricKit for app-integrated collection, `diagnosticbundle` for export/redaction, `fileinbox` for broad file triage, `notificationdigest` for events, and `scriptoutput` for any external producers.
- Do not scan `~/Library/Logs/DiagnosticReports` or `/Library/Logs/DiagnosticReports`, read unified logs, tail Console data, install a crash reporter, adopt MetricKit, run symbolication tools, upload/export/mutate reports, parse full frames/images by default, infer root cause, or add a second registry.
- Add `empty`, `mixed-reports`, `parse-warning`, `stale-reports`, `oversized`, `unsupported`, and `external-actions-disabled` preview fixtures.

## Cycle 37 Decision: `visualbaselines`

`visualbaselines` should not be implemented as a Surface plugin. It is concrete enough to implement as a `block-preview` / `BlockPreviewTests` harness feature. See `visualbaselines-spec.md`.

The first version should stay test-owned and explicit:

- Render current images through existing `BlockPreview.renderAll` and `BlockPreview.renderSurface`.
- Store checked-in baselines under `tests/BlockPreviewTests/Baselines`.
- Add `swift run block-preview baseline-check` for compare-only runs and `swift run block-preview baseline-record` for explicit local recording.
- Compare decoded pixels and exact dimensions, not PNG file bytes.
- Write current images, diff images, and `.build/surface-status/visualbaselines.json`.
- Attach current/baseline/diff artifacts to test failures where XCTest-compatible attachment APIs are available.
- Keep CI check-only by default.
- Let `previewgallery` read `visualbaselines.json` later, but never call check/record, update baselines, approve diffs, or delete artifacts.
- Do not create a `visualbaselines` `BlockRuntime`, registry entry, overlay approval queue, screenshot manager, hosted visual-test integration, shell/ImageMagick path, or second fixture registry.

## Cycle 38 Decision: `crashsymbolication`

`crashsymbolication` should not be implemented as a separate Surface plugin. It is concrete enough to implement as a copy-only handoff extension inside `crashreports`. See `crashsymbolication-spec.md`.

The first version should stay non-executing:

- Extend `crashreports-index.json` entries with optional explicit symbolication fields: app bundle, executable, dSYM, archive, architecture, binary UUID, load address, and frame addresses.
- Parse symbolication clues only from crash files already loaded by `crashreports`.
- Show handoff states such as `symbolicated`, `ready for Xcode`, `ready for atos`, `needs dSYM`, `needs executable`, `needs address`, and `unknown`.
- Copy Xcode handoff steps, `atos` command templates, and a Markdown checklist.
- Reveal only explicit manifest paths.
- Reuse existing owners: Xcode for preferred symbolication, Apple command-line tools for manual symbolication, `scriptoutput` for any future explicit execution, `diagnosticbundle` for export/redaction, and `fileinbox` for broad file triage.
- Do not add a `crashsymbolication` `BlockRuntime`, run `atos`/`symbolicatecrash`/`dwarfdump`/`xcrun`/Xcode, search DerivedData or Archives, download dSYMs, upload symbols, mutate crash files, parse DWARF/Mach-O contents, infer root cause, or add a second registry.

## Cycle 39 Decision: `visualartifactretention`

`visualartifactretention` should not be implemented as a Surface plugin. It is concrete enough to implement as repository/test/CI policy around `visualbaselines`. See `visualartifactretention-spec.md`.

The first version should stay simple:

- Keep generated current images, diff images, and reports under ignored `.build`.
- Make `baseline-check` overwrite `.build/block-preview-current`, `.build/block-preview-diffs`, and `.build/surface-status/visualbaselines.json`.
- Keep checked-in baselines under `tests/BlockPreviewTests/Baselines` as code-reviewed test fixtures.
- Upload current/diff/report artifacts in CI only on visual-baseline failure.
- Use `actions/upload-artifact` with `retention-days: 7`.
- Start without Git LFS; revisit only when individual baselines, total baseline size, clone cost, or churn justify it.
- Let `previewgallery` read artifact policy/report fields later, but never clean, upload, expire, approve, or move artifacts.
- Let `diagnosticbundle` manually export selected visual artifacts when needed.
- Do not add a block, daemon, watcher, cleaner, scheduled retention service, successful-run uploads, generated artifact source control, automatic baseline pruning, compression, or a second registry.

## Cycle 40 Decision: `dsymcatalog`

`dsymcatalog` should not be implemented as a Surface plugin. It is concrete enough to implement as an optional explicit manifest read by `crashreports` and `crashsymbolication`. See `dsymcatalog-spec.md`.

The first version should stay manifest-only:

- Read `dsymcatalog.json` from `Block.Context.storageDirectory` in previews/tests or Application Support in live mode.
- Let `crashreports-index.json` optionally reference a `symbolCatalogPath`.
- Match catalog rows to crash reports using explicit bundle id, app version/build, architecture, executable name, platform, and binary image UUIDs.
- Treat UUID matches as strong, version/build text matches as possible, and conflicts/ambiguity as warnings.
- Show matched row, UUIDs, architecture, app version/build, explicit dSYM/archive/app/executable paths, stale/missing path warnings, and copy/reveal actions inside `crashreports`.
- Copy Xcode handoff Markdown, dSYM checklists, catalog row JSON, and `atos` templates only when `crashsymbolication` has a single strong match plus required addresses.
- Reuse Xcode and App Store Connect for archive/debug-symbol workflows, Apple CLI tools for manual UUID verification, `scriptoutput` for future explicit catalog producers, `diagnosticbundle` for export/redaction, and `fileinbox` for broad file triage.
- Do not add a `dsymcatalog` `BlockRuntime`, scan DerivedData/Archives/Spotlight/folders, run `dwarfdump`/`atos`/`xcrun`/`mdfind`, download/upload symbols, parse DWARF/Mach-O, mutate files, create a symbol database, or add a second registry.

## Cycle 41 Decision: `baselineplatforms`

`baselineplatforms` should not be implemented as a Surface plugin. It is concrete enough to implement as visual-baseline harness policy. See `baselineplatforms-spec.md`.

The first version should stay single-lane:

- Keep one default checked-in baseline lane under `tests/BlockPreviewTests/Baselines`.
- Add optional `tests/BlockPreviewTests/Baselines/platform.json`.
- Pin CI visual-baseline checks to a concrete macOS runner label, not `macos-latest`.
- Extend `visualbaselines.json` with platform metadata: OS version, architecture, runner label, renderer, display/renderer scale, appearance, locale, and lane.
- Collect metadata through Swift/Foundation/AppKit APIs where possible, not shell commands.
- Add `platformMismatch` status before pixel interpretation when OS major version, architecture, rendered pixel dimensions, or renderer scale differs.
- Treat patch-version or unavailable scale differences as warnings first.
- Add multiple baseline directories only after repeated measured variance proves a second stable platform lane is necessary.
- Do not add a `baselineplatforms` `BlockRuntime`, per-user/per-machine baselines, automatic lane creation, `previewgallery` mutation, broad tolerances, shell-based metadata collection, or a second registry.

## Cycle 42 Decision: `crashattachmentpolicy`

`crashattachmentpolicy` should not be implemented as a Surface plugin. It is concrete enough to implement as a manifest policy extension inside `diagnosticbundle`. See `crashattachmentpolicy-spec.md`.

The first version should stay classification-only:

- Reuse `diagnosticbundle` export/redaction modes and do not add another exporter, registry, or diagnostics bus.
- Add crash/symbol artifact kinds such as `crash-summary`, `crash-report`, `symbolication-handoff`, `symbolication-output`, `dsym-catalog`, `dsym-bundle`, `xcode-archive`, `app-bundle`, `app-binary`, `bcsymbolmap`, `sysdiagnose`, and `third-party-crash-export`.
- Include generated crash summaries, copied symbolication handoffs, and redacted dSYM catalog metadata by default.
- Mark raw `.ips`/`.crash` reports, raw symbolication output, and third-party crash exports as `manual-review` by default.
- Exclude dSYM bundles, Xcode archives, app bundles, app binaries, BCSymbolMaps, and sysdiagnose artifacts by default in v1.
- Require an explicit `allowSensitiveCrashArtifact` flag before a sensitive crash/symbol kind can use a less-restrictive redaction than the policy default.
- Skip directory-valued artifacts in v1 and write deterministic skipped reasons into `redaction-report.json`.
- Do not upload, attach, compress, scan, run symbolication tools, collect logs, copy directories, mutate source files, or add a second registry.

## Cycle 43 Decision: `rendererscalecontrol`

`rendererscalecontrol` should not be implemented as a Surface plugin. It is concrete enough to implement as renderer configuration inside `BlockImageRenderer` and `BlockPreview`. See `rendererscalecontrol-spec.md`.

The first version should stay owner-local:

- Add one `BlockRenderConfiguration` in `BlockPreviewSupport` with scale, appearance, and locale fields.
- Keep `previewDefault` on current behavior: actual scale, system appearance, and current locale.
- Add `baselineDefault`: fixed scale `2.0`, light appearance, and `en_US_POSIX` locale.
- Pass the configuration through `BlockPreview.render`, `renderAll`, `renderSurface`, and `BlockImageRenderer.pngData`.
- Add CLI flags `--scale`, `--appearance`, and `--locale` for ad hoc preview rendering.
- Make future `baseline-check` and `baseline-record` use the stable baseline default and record renderer metadata in `visualbaselines.json`.
- Do not put renderer settings in `Block.Context`, change live overlay rendering, mutate global appearance/locale, resize PNGs after rendering, add per-scale lanes, or create a plugin/registry entry.

## Cycle 44 Decision: `diagnosticbundleredactionkeys`

`diagnosticbundleredactionkeys` should not be implemented as a Surface plugin. It is concrete enough to implement as fixed redaction policy constants and summary/report formatting inside `diagnosticbundle`. See `diagnosticbundleredactionkeys-spec.md`.

The first version should stay structured and exact:

- Add policy version `diagnosticbundle-redaction-v1`.
- Apply `redact-known-keys` only to JSON and JSONL artifacts.
- Use exact key and dotted-path maps for secrets, identity, paths, local context, and crash-detail fields.
- Replace values with deterministic tokens such as `[redacted:secret]`, `[redacted:identity]`, `[redacted:path]`, `[redacted:local-context]`, and `[redacted:crash-detail]`.
- Normalize repo-root, home, fixture, and safe relative paths for `summary.md`; redact unsafe absolute paths.
- Generate deterministic `summary.md` tables for included artifacts, skipped artifacts, and redactions.
- Generate `redaction-report.json` with counts, key paths, and tokens, but never original values or value hashes.
- Skip non-JSON/JSONL `redact-known-keys` artifacts with `redaction-unsupported-format`.
- Do not add broad regex text-log scrubbing, per-plugin DSLs, AI scrubbing, shell tools, upload-time scrubbing, or a second registry.

## Cycle 45 Decision: `visualbaselinereportschema`

`visualbaselinereportschema` should not be implemented as a Surface plugin. It is concrete enough to implement as the v1 report contract for `.build/surface-status/visualbaselines.json`. See `visualbaselinereportschema-spec.md`.

The first version should consolidate the visual policies:

- Use `schema: "surface.visualbaselines.report.v1"` and `version: 1`.
- Keep one generated report path: `.build/surface-status/visualbaselines.json`.
- Include required top-level sections: `paths`, `platform`, `renderer`, `artifactPolicy`, `tolerancePolicy`, `summary`, `results`, and `warnings`.
- Use exact enum values for mode, result kind, status, scale policy, appearance, and artifact policy.
- Preserve result order from `BlockPreview.cases` plus `surface-active`.
- Classify statuses in order: render failed, unreadable, missing baseline, extra baseline, platform mismatch, dimension mismatch, pixel mismatch, passed.
- Use repo-relative paths and `${repoRoot}` instead of absolute repo paths.
- Let `previewgallery`, `diagnosticbundle`, and `localbuildstatus` read or summarize the report, but never mutate, approve, upload, or regenerate it.
