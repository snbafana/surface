# Plugin Ideas Heartbeat Ledger

## Cycle 1

- `started_at`: 2026-06-21T01:54:51Z
- `mode`: one-shot heartbeat-style research pass
- `scope`: find plugin ideas that make sense for Surface as an editable local macOS control surface
- `write_owner`: `research/`
- `code_owner_to_reuse_later`: existing `Block` / `BlockRuntime` / `Block.Context` path

## Research Heuristic

Prefer ideas with at least one of these traits:

- Glanceable state that benefits from staying visible in the overlay.
- Local-first action loops that avoid opening another app.
- High-frequency personal workflows: copy, capture, approve, triage, search, launch, focus.
- Deterministic preview fixtures can be built without hitting live services.
- A plugin can be implemented as one `BlockRuntime` without a new daemon or registry.

Avoid ideas for now when they require:

- A second plugin system.
- A background service outside `RunningBlocks`.
- OAuth or paid APIs before a fixture-backed prototype exists.
- Broad Accessibility permissions without a visible permission state.
- A giant generic browser/webview block.

## Sources Touched

See `source-ledger.tsv` for the source list. The first pass sampled:

- Raycast extension categories and store patterns.
- xbar and SwiftBar script/plugin model.
- Hammerspoon macOS automation primitives and Spoons.
- Übersicht desktop widget model.
- Menu-bar examples such as GitHub PR lists, stock tickers, weather/air-quality-style ambient data, and system scripting.

## Output

- Main synthesis: `plugin-ideas.md`
- Follow-up queue: `queue.md`

## Cycle 2

- `started_at`: 2026-06-21T02:00:00Z
- `mode`: recurring heartbeat started plus immediate focused pass
- `automation_id`: `surface-plugin-research-loop`
- `focus`: `githubqueue`
- `question`: what would a first GitHub PR/review queue plugin need to be useful without adding OAuth or a parallel integration layer?

### Findings

- GitHub CLI is the right first live integration because it already sits next to git workflow and exposes pull requests, issues, and repository concepts from the terminal.
- `gh pr list` can list open pull requests and emit selected JSON fields, which is enough for a first queue block.
- `gh pr checks` can summarize CI for a PR; the JSON output includes a `bucket` grouping that maps check states into pass/fail/pending/skipping/cancel.
- Raycast's GitHub extension validates the product surface: pull requests, issues, workflows, repository search, and notifications are extension-worthy daily commands.
- The first Surface version should avoid GraphQL/PAT setup and use `gh` when available, then fixture JSON in previews/tests.

### Output

- Added `githubqueue-spec.md`.
- Extended `source-ledger.tsv`.
- Promoted `githubqueue` from idea to concrete implementation spec in `plugin-ideas.md`.
- Updated `queue.md` with implementation tasks and open questions.

## Cycle 3

- `started_at`: 2026-06-21T02:08:00Z
- `mode`: immediate focused pass while heartbeat remains active
- `focus`: `fileinbox`
- `question`: what file-management plugin can be useful locally without becoming Hazel, Dropzone, or a generic file manager?

### Findings

- Hazel validates the watched-folder model: watch folders, match files by name/date/type/source, and organize them with rules.
- Dropzone validates action targets: move/copy/share/open actions are valuable when attached to files in flow.
- Raycast File Search validates quick open/manage/copy workflows, but Surface should avoid duplicating a global search palette.
- The Surface-shaped version should be an inbox triage block, not an automation engine: show recent files and expose a few safe actions.

### Output

- Added `fileinbox-spec.md`.
- Extended `source-ledger.tsv`.
- Promoted `fileinbox` to ready-to-implement after `githubqueue`.

## Cycle 4

- `started_at`: 2026-06-21T07:08:39Z
- `mode`: recurring heartbeat focused pass
- `automation_id`: `surface-plugin-research-loop`
- `focus`: `contextcard`
- `question`: can Surface expose useful current-app/window context without requiring Accessibility for v1?

### Findings

- `NSWorkspace.frontmostApplication` is enough for a v1 app identity card: it returns the app receiving key events.
- `NSWorkspace.didActivateApplicationNotification` gives a low-cost refresh signal when the active app changes.
- `NSRunningApplication` supplies app metadata such as localized name, bundle identifier, process identifier, and activation policy.
- `CGWindowListCopyWindowInfo` can return window dictionaries for the current user session, but window titles are optional and can be missing.
- Accessibility APIs are needed for stronger focused-window/focused-element detail: `AXIsProcessTrustedWithOptions`, `AXUIElementCreateApplication`, `kAXFocusedWindowAttribute`, and `kAXFocusedUIElementAttribute`.
- Therefore v1 should ship without prompting for Accessibility: show app name, bundle id, PID, activation policy, and best-effort front window title only if available from CoreGraphics. Add a visible permission state before any AX-based v2.

### Output

- Added `contextcard-spec.md`.
- Extended `source-ledger.tsv`.
- Promoted `contextcard` to ready-to-implement with a no-AX v1 and AX-gated v2.

## Cycle 5

- `started_at`: 2026-06-21T08:31:19Z
- `mode`: recurring heartbeat focused pass
- `automation_id`: `surface-plugin-research-loop`
- `focus`: `permissionsdashboard`
- `question`: what permission model should Surface use before adding AX, screen capture, calendar, contacts, or Apple Events integrations?

### Findings

- Surface should make permissions a product surface, not a hidden install/debug problem.
- Accessibility can be checked with `AXIsProcessTrustedWithOptions`; prompt-based onboarding should be deliberate, not incidental.
- Screen Recording has explicit CoreGraphics preflight/request APIs; preflight checks and request prompts are separate concepts.
- Input Monitoring is user-managed under Privacy & Security; keyboard/mouse monitoring should stay out of v1 plugins unless the block has a clear permission state.
- EventKit and Contacts have authorization-status APIs and explicit request APIs; future Calendar/Contacts plugins should be fixture-first and show blocked states before asking.
- Apple Events automation needs an Info.plist purpose string and should be treated as a per-target app capability, not a blanket Surface entitlement.
- The repo's current bundled run script needs Info.plist extension points before permission-heavy plugins ship; otherwise the app can compile but fail to prompt correctly.

### Output

- Added `permissionsdashboard-spec.md`.
- Extended `source-ledger.tsv`.
- Promoted `permissionsdashboard` to ready-to-implement as a cross-plugin guardrail block.
- Updated queue to shift remaining work toward implementation and broad source sampling.

## Cycle 6

- `started_at`: 2026-06-21T14:17:02Z
- `mode`: recurring heartbeat focused pass
- `automation_id`: `surface-plugin-research-loop`
- `focus`: `obsidianqueue`
- `question`: which local files should an Obsidian queue read, and how does it stay separate from Codex Log?

### Findings

- Quicksave already owns Obsidian writes, daily-note date naming, template fallback, media copying, and the configured vault/daily-note/inbox paths.
- Codex Log already owns the append-only action log and knows how to split `daily-obsidian-backlink-proposals` and `daily-note-to-genuine-ideas` rows into bite-sized pending actions.
- Obsidian URI gives enough v1 actions to open the daily note, open a source/target note, and open Search with a query without writing to the vault.
- Obsidian Daily notes and Properties support the product model, but Obsidian's own default date naming should not override Quicksave's local configured behavior.
- Obsidian CLI is useful later for daily/search/read/tasks/tag counts, but it requires or launches the Obsidian app, so it should be optional enrichment rather than a v1 dependency.
- Therefore `obsidianqueue` should be a domain dashboard over existing owners: daily-note status, Quicksave capture status, and Obsidian-specific action rows, with approvals routed to Codex Log in v1.

### Output

- Added `obsidianqueue-spec.md`.
- Extended `source-ledger.tsv` with Obsidian URI, Daily notes, Properties, Search, and CLI sources.
- Promoted `obsidianqueue` to ready-to-implement.
- Updated the queue so the next spec targets are `focus` and constrained `scriptoutput`.

## Cycle 7

- `started_at`: 2026-06-21T16:08:27Z
- `mode`: recurring heartbeat focused pass
- `automation_id`: `surface-plugin-research-loop`
- `focus`: `focus`
- `question`: should the Focus block be a pure timer/state block, and how does it avoid becoming Screen Time or a blocker daemon?

### Findings

- The repo has no existing timer/focus owner, but Copy History and Codex Log already show the right runtime patterns: plugin-local files, `Task.sleep` loops while the block is running, and deterministic `Block.Context.now` fixtures.
- Raycast Timers and Pomodoro validate timer/pomodoro surfaces with lightweight start/stop/manage controls.
- Raycast Pomodoro delegates Do Not Disturb integration to another extension, which supports keeping Surface v1 local and non-system-mutating.
- Apple's macOS Focus is a user-managed system feature with notification allowlists, schedules, app triggers, and Focus Filters. Surface should not duplicate that settings surface.
- Apple's Focus Filters are for app behavior adaptation after user configuration; useful later, but not needed for a v1 timer.
- Apple's Screen Time API introduces Managed Settings, Family Controls, Device Activity, privacy, restrictions, and entitlement concerns, so app/site blocking is explicitly out of scope for v1.
- Therefore `focus` should persist one timestamp-based state file and derive phases on refresh; no hidden daemon is required.

### Output

- Added `focus-spec.md`.
- Extended `source-ledger.tsv` with Raycast timer/pomodoro, Apple Focus, Focus Filters, Screen Time API, and Pomodoro sources.
- Promoted `focus` to ready-to-implement.
- Updated the queue so `scriptoutput` is the remaining top spec target.

## Cycle 8

- `started_at`: 2026-06-21T16:45:21Z
- `mode`: recurring heartbeat focused pass
- `automation_id`: `surface-plugin-research-loop`
- `focus`: `scriptoutput`
- `question`: how can Surface support scheduled script output without creating a second plugin framework?

### Findings

- xbar and SwiftBar both validate the core model: execute a local script/program on a schedule and parse stdout into visible status/menu rows.
- xbar and SwiftBar also show the risky part: plugin folders, variable metadata, nested menu syntax, and command-running row actions can easily become a second plugin system.
- The repo already has narrow command runners in Codex Log and Quicksave. Implementation can reuse/factor bounded process execution, but should not add a generic script registry.
- Übersicht reinforces the security boundary: command-output widgets can run arbitrary code, so Surface should require explicit local paths and visible disabled/error states.
- Therefore v1 should run exactly one configured executable with argument-array execution, timeout, byte caps, safe row parsing, and file-backed preview results.

### Output

- Added `scriptoutput-spec.md`.
- Extended `source-ledger.tsv` with xbar, SwiftBar, and Ubersicht command-output sources.
- Promoted `scriptoutput` to ready-to-implement.
- Updated the queue with `localbuildstatus` and `systemhealth` as next spec candidates.

## Cycle 9

- `started_at`: 2026-06-21T17:18:51Z
- `mode`: recurring heartbeat focused pass
- `automation_id`: `surface-plugin-research-loop`
- `focus`: `localbuildstatus`
- `question`: should local build status read git/build/test state from files only, and where should test runners write last-result data?

### Findings

- Git status porcelain v2 is the right live git input because it is intended for stable machine parsing and includes branch headers plus worktree records.
- `git rev-parse --show-toplevel` and `git branch --show-current` are useful validation/fallback commands, but the primary path should be porcelain v2.
- Surface's README already defines the local verification workflow: `swift build`, `swift test`, focused plugin tests, block-preview rendering, and bundled app verification.
- `scriptoutput` now owns scheduled command execution as a plugin idea, so `localbuildstatus` should not run build/test/preview commands.
- `.build/` is already ignored by this repo, so `.build/surface-status` is the least invasive default location for runner-written JSON status files.
- Therefore `localbuildstatus` should use read-only git commands for repo state, and file-only reads for build/test/preview results.

### Output

- Added `localbuildstatus-spec.md`.
- Extended `source-ledger.tsv` with Git status/rev-parse/branch, SwiftPM, and the local Surface README verification loop.
- Promoted `localbuildstatus` to ready-to-implement.
- Updated the queue with `systemhealth` and `linkinbox` as next spec candidates.

## Cycle 10

- `started_at`: 2026-06-21T17:54:51Z
- `mode`: recurring heartbeat focused pass
- `automation_id`: `surface-plugin-research-loop`
- `focus`: `systemhealth`
- `question`: what is the smallest local system-health block that stays actionable and does not become a passive widget pile?

### Findings

- The Surface codebase has no existing system-health owner; existing block patterns are sufficient: one `BlockRuntime`, fixture files through `Block.Context.storageDirectory`, and live refresh only while running.
- Apple `ProcessInfo` gives thermal state and Low Power Mode without shelling out.
- Apple notification APIs can trigger refresh for thermal/power changes, reducing polling.
- Apple `URLResourceValues.volumeAvailableCapacityForImportantUsage` supports low-disk checks from file URLs without parsing `df`.
- `NWPathMonitor` and `NWPath.isConstrained` support local network-path status without pings or external fetches.
- IOKit power-source APIs can provide battery/power-source status when the Mac has a battery; desktop/no-battery should be a normal state.
- Therefore v1 should roll up only actionable conditions: low disk, thermal pressure, Low Power Mode, constrained/offline network, and low battery. CPU/memory/fan/sensor graphs and shell metrics should stay out of v1.

### Output

- Added `systemhealth-spec.md`.
- Extended `source-ledger.tsv` with ProcessInfo thermal/power, URLResourceValues disk capacity, Network.framework path, and IOKit power-source sources.
- Promoted `systemhealth` to ready-to-implement.
- Updated the queue with `linkinbox` and `calendarprep` as next spec candidates.

## Cycle 11

- `started_at`: 2026-06-21T18:24:51Z
- `mode`: recurring heartbeat focused pass
- `automation_id`: `surface-plugin-research-loop`
- `focus`: `linkinbox`
- `question`: should Link Inbox be clipboard-only or fetch titles, and how do previews avoid network fetches?

### Findings

- Copy History already owns general text clipboard history; Link Inbox should store URL-specific records and not duplicate a general clipboard log.
- Quicksave already knows how to read URL/string pasteboard content, so URL extraction should be reused or factored if passive watching is added.
- Raycast Quicklinks validate quick URL/file/deeplink workflows, while Raycast Auto Fill shows that active-browser URL/title capture requires Automation permissions.
- Apple `NSPasteboard.PasteboardType.URL` gives a direct URL pasteboard path before falling back to string scanning.
- Apple `URLComponents` is the right normalization/dedupe tool for scheme/host/path/query handling.
- Apple `LPMetadataProvider` can fetch title/icon/image metadata, but that is network-like work and should not run during previews, startup, or passive refresh.
- Therefore v1 should be clipboard/file-backed with cached metadata only: capture URLs, store optional titles, show host/path fallback, and leave title fetching as an explicit later action.

### Output

- Added `linkinbox-spec.md`.
- Extended `source-ledger.tsv` with Raycast Quicklinks, Apple pasteboard URL, URLComponents, NSWorkspace open, and LPMetadataProvider sources.
- Promoted `linkinbox` to ready-to-implement.
- Updated the queue with `calendarprep` and `snippetprompt` as next spec candidates.

## Next Heartbeat Prompt

Continue Surface plugin research from `research/`. Read `plugin-ideas.md`, `source-ledger.tsv`, and `queue.md`; pick the top unresolved queue item; add source-backed notes and revise rankings only if the new evidence changes implementation priority. Preserve the existing `Block` / `BlockRuntime` owner and do not propose a second plugin registry.

## Stop Conditions

Stop research and switch to implementation when:

- Three top-tier plugin specs have clear data source, runtime behavior, preview fixture, and test plan.
- A proposed idea needs credentials or private dashboard state; move it to `queue.md` instead of guessing.
- The source pass repeats the same patterns: launcher, clipboard, window management, menu-bar scripts, widgets, automation bridges.

## Cycle 12

- `started_at`: 2026-06-21T18:54:51Z
- `mode`: recurring heartbeat focused pass
- `automation_id`: `surface-plugin-research-loop`
- `focus`: `calendarprep`
- `question`: can a next-meeting block be useful while staying fixture-first and respecting modern EventKit full-access boundaries?

### Findings

- Raycast validates Calendar as an everyday launcher/overlay workflow: schedule overview, next meeting, join, attendee/email, and copy actions.
- Apple frames EventKit as the direct calendar-data API. Reading existing events requires full access; write-only access is for adding events and cannot read calendars or existing events.
- Surface already has a permission owner: `permissionsdashboard`. Calendar access requests should route through that explicit status/request pattern instead of a new permission layer.
- The bundle owner is `script/build_and_run.sh` / app generation. Live Calendar support needs `NSCalendarsFullAccessUsageDescription` before any EventKit full-access request ships.
- EventKit fetching should use a short future range with `predicateForEvents(withStart:end:calendars:)` and `events(matching:)`, then sort results before selecting the next meeting.
- Therefore `calendarprep` should start fixture-first, read-only, and copy/open oriented. It should not create/edit/delete events, auto-join calls, email attendees, or parse provider-specific meeting links in v1.

### Output

- Added `calendarprep-spec.md`.
- Extended `source-ledger.tsv` with Raycast Calendar, Apple WWDC Calendar/EventKit guidance, modern full-access Info.plist key, EventKit fetch APIs, and `EKEvent` fields.
- Promoted `calendarprep` to ready-to-implement.
- Updated the queue with `snippetprompt` and `windowlayouts` as next spec candidates.

## Cycle 13

- `started_at`: 2026-06-21T19:24:51Z
- `mode`: recurring heartbeat focused pass
- `automation_id`: `surface-plugin-research-loop`
- `focus`: `snippetprompt`
- `question`: can a snippets/prompts block be useful without duplicating Raycast Snippets, Copy History, or future context capture?

### Findings

- Raycast Snippets validates a tagged reusable text library with search, copy/paste, imports, and dynamic placeholders, but its global keyword auto-expansion implies keyboard monitoring and active-app insertion that Surface should avoid in v1.
- Raycast Dynamic Placeholders show the useful subset: date/time, clipboard, arguments, and context-like values. The broader subset includes selected text, browser tabs, nested snippets, and calculated values that would create permission and runtime scope creep.
- Raycast AI Commands validate prompt libraries and selected-text workflows, but Quick Fix needs Accessibility to read/replace active-app text. Surface should not run AI or mutate the active app in `snippetprompt` v1.
- Espanso forms/variables validate explicit argument fields, but also show why Surface should not add a scripting/expansion language here.
- Existing Surface owners are clear: Copy History owns passive clipboard history, Link Inbox owns URL capture, Quicksave owns durable capture, Context Card owns selected/front-app context, and Script Output owns command execution.
- Therefore `snippetprompt` should be a local read/copy block: load a JSON library, resolve a safe placeholder subset, expose up to three explicit arguments, and copy raw/resolved text.

### Output

- Added `snippetprompt-spec.md`.
- Extended `source-ledger.tsv` with Raycast Snippets, Dynamic Placeholders, AI Commands, Clipboard History, Espanso forms/variables, and Apple pasteboard write sources.
- Promoted `snippetprompt` to ready-to-implement.
- Updated the queue with `windowlayouts` and `packagewatch` as next spec candidates.

## Cycle 14

- `started_at`: 2026-06-21T19:54:51Z
- `mode`: recurring heartbeat focused pass
- `automation_id`: `surface-plugin-research-loop`
- `focus`: `windowlayouts`
- `question`: can Surface support useful window layout actions without becoming a full window manager or a parallel AX/context framework?

### Findings

- Raycast Window Management validates focused-window halves, thirds, center, maximize, restore, saved layouts, custom commands, and explicit macOS Accessibility permission.
- Hammerspoon `hs.window`, `hs.layout`, and WindowHalfsAndThirds validate the same core shape: focused-window movement, unit-rect layout presets, and simple half/third/center/maximize operations.
- Surface already has the needed owners: `permissionsdashboard` for Accessibility request/status and `contextcard` for no-AX frontmost app/window identity.
- Apple Accessibility APIs provide the direct Swift path: check trust, create the app AX element, read focused-window/position/size attributes, then set position/size attributes on explicit action.
- `NSScreen.visibleFrame` should anchor layout math so presets avoid the menu bar and Dock.
- Therefore v1 should be a focused-window action pad with fixture-only previews and visible failure states. Multi-app workspace restore, global hotkeys, automatic tiling, fullscreen/Space/display movement, and app launching should wait.

### Output

- Added `windowlayouts-spec.md`.
- Extended `source-ledger.tsv` with Raycast Window Management, Hammerspoon window/layout sources, Accessibility set/copy/position/size APIs, and `NSScreen.visibleFrame`.
- Promoted `windowlayouts` to ready-to-implement.
- Updated the queue with `packagewatch` and `financewatch` as next spec candidates.

## Cycle 15

- `started_at`: 2026-06-21T20:25:21Z
- `mode`: recurring heartbeat focused pass
- `automation_id`: `surface-plugin-research-loop`
- `focus`: `packagewatch`
- `question`: can Surface show useful package status without carrier credentials, API polling, or account scraping?

### Findings

- Raycast Delivery Tracker validates active delivery rows, status grouping, notes, archive, menu-bar glances, and carrier integrations, but its UPS/FedEx/USPS support requires direct API work and credentials.
- Raycast Parcel validates a package list with active/upcoming deliveries, carrier/tracking/status/history details, copy actions, and add-delivery flow, but depends on the separate Parcel app.
- 17TRACK validates both public tracking-page handoff and API-backed real-time global tracking. The public tracking URL is appropriate for explicit open actions; API polling is not a v1 block responsibility.
- Apple Wallet order tracking depends on participating merchants/apps and merchant-provided order data; Surface should not scrape Wallet or email.
- Existing Surface owners are clear: Link Inbox owns generic URLs, Copy History owns passive clipboard history, and Script Output owns scheduled external polling.
- Therefore `packagewatch` should be a local/manual ledger: read cached package records, group by ETA/status, open tracking pages explicitly, and let users manually mark/archive records.

### Output

- Added `packagewatch-spec.md`.
- Extended `source-ledger.tsv` with Raycast Delivery Tracker, Raycast Parcel, 17TRACK API/tracking pages, and Apple Wallet order tracking.
- Promoted `packagewatch` to ready-to-implement.
- Updated the queue with `financewatch` and `notificationdigest` as next spec candidates.

## Cycle 16

- `started_at`: 2026-06-21T20:57:52Z
- `mode`: recurring heartbeat focused pass
- `automation_id`: `surface-plugin-research-loop`
- `focus`: `financewatch`
- `question`: can Surface show useful market watchlist state without becoming a broker, market-data client, or advice surface?

### Findings

- Raycast Stock Tracker validates watchlist/portfolio-style rows using Yahoo Finance data, but that implies provider stability and live-data dependency.
- Raycast Stock Lookup validates Alpha Vantage-backed stock lookup, but requires an API key stored in preferences.
- Raycast Apple Stocks Search validates a safe open/search handoff: it opens Apple Stocks and avoids displaying prices itself.
- xbar's Yahoo stock ticker validates ambient menu-bar finance rows, delayed prices, and no-key data, but also includes price alarms that Surface should avoid in v1.
- Alpha Vantage confirms live quote/time-series data is an API-key-backed integration path. SEC EDGAR confirms no-key company filings/fundamentals are available, but those are not live quote data.
- Existing Surface ownership points to a cached design: `scriptoutput` or an external job should fetch prices if needed, while `financewatch` reads the cache and shows source/staleness.
- Therefore `financewatch` should start as a local/cached watchlist with no trading, credentials, account balances, cost basis, recommendations, or runtime quote fetching.

### Output

- Added `financewatch-spec.md`.
- Extended `source-ledger.tsv` with Raycast Stock Tracker, Stock Lookup, Apple Stocks Search, xbar Yahoo Stock Ticker, Alpha Vantage docs, and SEC EDGAR APIs.
- Promoted `financewatch` to ready-to-implement.
- Updated the queue with `notificationdigest` and `mediacontrols` as next spec candidates.

## Cycle 17

- `started_at`: 2026-06-21T21:31:22Z
- `mode`: recurring heartbeat focused pass
- `automation_id`: `surface-plugin-research-loop`
- `focus`: `notificationdigest`
- `question`: can Surface show a useful notification digest when macOS-wide notification history is not available through supported public APIs?

### Findings

- Apple's UserNotifications APIs are app-scoped for this use case: Surface can request/check its own notification permission, inspect its own notification settings, and fetch its own delivered notifications that remain in Notification Center.
- That does not provide a supported path to read every other app's Notification Center history.
- Raycast notification-related extensions validate two useful patterns: source-specific notification inboxes with unread/open/read actions, and explicit app-generated notification emission.
- Existing Surface ownership is clear: `permissionsdashboard` should own notification permission request/status, Codex Log owns Codex queues, Copy History owns clipboard history, Focus owns timers, and Script Output owns command failures.
- Therefore `notificationdigest` should be a local Surface/plugin event digest backed by `notificationdigest-events.jsonl`, with optional Surface-owned delivered notification supplement only.
- The block should not scrape Notification Center databases, use Accessibility/OCR, mine global unified logs, poll external services, schedule alerts, or duplicate source-specific queues.

### Output

- Added `notificationdigest-spec.md`.
- Extended `source-ledger.tsv` with Apple UserNotifications, delivered notification, notification settings/request/content, OSLogStore, Raycast Universal Inbox, Raycast Gitea, and Raycast Notification sources.
- Promoted `notificationdigest` to ready-to-implement.
- Updated the queue with `mediacontrols` and `browsersessioncards` as next spec candidates.

## Cycle 18

- `started_at`: 2026-06-21T22:03:22Z
- `mode`: recurring heartbeat focused pass
- `automation_id`: `surface-plugin-research-loop`
- `focus`: `mediacontrols`
- `question`: can Surface offer useful Now Playing/audio route controls without private APIs or duplicating system controls?

### Findings

- Apple's Now Playing and MediaPlayer APIs are app-owned: they help an app publish its playback state and respond to remote commands. They do not provide a supported utility-app path to read/control arbitrary system-wide Now Playing from other apps.
- Public Core Audio device APIs are the viable live path for audio route state: default output/input/sound-effects devices and available device capabilities can be wrapped behind a small adapter.
- Raycast and Hammerspoon validate both patterns separately: audio-device switching is a useful launcher workflow, while Spotify-style playback control is source-specific and permission/credential/app-state dependent.
- Existing Surface ownership points to a split: `scriptoutput` or future source plugins own playback automation; `browsersessioncards` can own browser media later; `permissionsdashboard` owns Apple Events/Accessibility permission flow.
- Therefore `mediacontrols` should be a narrow audio-route block with explicit route-switch actions and optional externally cached now-playing context. It should not render play/pause/skip in v1.

### Output

- Added `mediacontrols-spec.md`.
- Extended `source-ledger.tsv` with Apple Now Playing/MediaPlayer/Core Audio sources, Raycast Spotify Player, Raycast Audio Device, and Hammerspoon audio/Spotify sources.
- Promoted `mediacontrols` to ready-to-implement as audio-route only.
- Updated the queue with `browsersessioncards` and `aicommandscratchpad` as next spec candidates.

## Cycle 19

- `started_at`: 2026-06-21T22:37:22Z
- `mode`: recurring heartbeat focused pass
- `automation_id`: `surface-plugin-research-loop`
- `focus`: `browsersessioncards`
- `question`: can Surface capture active browser context without reading full browser history or duplicating Context Card and Link Inbox?

### Findings

- Existing Surface ownership already covers the neighbors: `contextcard` owns generic frontmost app/window identity, and `linkinbox` owns durable URL records, dedupe, archive/pin/tag, and link triage.
- Raycast validates browser context as useful through browser extension and browser-tab placeholders, but that is an explicit integration path.
- Apple Events/Scripting Bridge can support browser-specific active-tab title/URL adapters after Automation permission and bundle purpose-string support, but should be per-browser and permission-visible.
- Chrome's extension tabs API, `activeTab`, and native messaging docs point to a safer future extension model: user-invoked active-tab capture and native handoff/cache, not profile scraping.
- Chrome DevTools Protocol target discovery is viable only when a user explicitly configures a local debug endpoint. It should be developer/debug mode, never a default dependency.
- Therefore `browsersessioncards` should be fixture-first and read/copy/capture-only: active tab first, bounded session rows when available, and URL handoff to Link Inbox.

### Output

- Added `browsersessioncards-spec.md`.
- Extended `source-ledger.tsv` with Apple Scripting Bridge, NSAppleScript, Safari Web Extension, Chrome tabs/activeTab/native messaging/CDP, and Raycast browser context sources.
- Promoted `browsersessioncards` to ready-to-implement.
- Updated the queue with `aicommandscratchpad` and `hammerspoonbridge` as next spec candidates.

## Cycle 20

- `started_at`: 2026-06-21T23:07:22Z
- `mode`: recurring heartbeat focused pass
- `automation_id`: `surface-plugin-research-loop`
- `focus`: `aicommandscratchpad`
- `question`: can Surface support AI command workflows without becoming a generic chat UI, provider credential store, or duplicate prompt-template block?

### Findings

- Raycast AI Commands validate one-press prompt workflows with selected text, placeholders, tags, model settings, and response windows, but those features blend templates, context capture, and execution in ways Surface should keep separated.
- Raycast AI Extensions validate richer AI/tool integrations, but that belongs to explicit source/plugin integrations rather than a hidden generic runner inside this block.
- OpenAI's text and prompt-engineering docs reinforce that prompt assembly, instructions, examples, context, and output handling are real application state, even if model execution is deferred.
- Existing Surface ownership is clear: `snippetprompt` owns reusable templates and placeholder resolution, `contextcard`/`browsersessioncards`/`linkinbox` own context snapshots, and `scriptoutput` owns command/API execution.
- Therefore `aicommandscratchpad` should own only per-run cards: assembled prompt/input/context, manual or externally written output, status, archive, and copy/handoff actions.
- V1 should not call AI APIs, store keys, stream responses, render chat threads, run tools/scripts/MCP, read selected text/browser content, replace active-app text, or add a second registry.

### Output

- Added `aicommandscratchpad-spec.md`.
- Extended `source-ledger.tsv` with Raycast AI Extensions and official OpenAI text-generation/prompt-engineering docs.
- Promoted `aicommandscratchpad` to ready-to-implement.
- Updated the queue with `hammerspoonbridge` and `keyboardmaestrobridge` as next spec candidates.

## Cycle 21

- `started_at`: 2026-06-21T23:42:22Z
- `mode`: recurring heartbeat focused pass
- `automation_id`: `surface-plugin-research-loop`
- `focus`: `hammerspoonbridge`
- `question`: can Surface surface Hammerspoon commands/status without becoming a Lua runner, Spoon manager, or duplicate scriptoutput?

### Findings

- Hammerspoon already owns a broad macOS automation runtime: Lua config, Spoons, hotkeys, IPC, URL events, app/window/audio automation, and the permissions needed for those actions.
- `scriptoutput` already owns generic executable/status rendering inside Surface, so `hammerspoonbridge` should not run `hs`, evaluate Lua, or become another script runner.
- `hs.json` supports a safe bridge shape: Hammerspoon writes a status/command manifest and Surface reads it.
- `hs.urlevent` and `hs.ipc` show possible trigger/control paths, but v1 should use only predeclared manifest URLs and never raw Lua or arbitrary CLI commands.
- Therefore `hammerspoonbridge` should start read-mostly: exported command/status rows, stale labels, copy/open/reveal actions, and optional predeclared URL triggers only when live actions are allowed.

### Output

- Added `hammerspoonbridge-spec.md`.
- Extended `source-ledger.tsv` with Hammerspoon IPC, URL events, JSON, hotkey, and settings docs.
- Promoted `hammerspoonbridge` to ready-to-implement.
- Updated the queue with `keyboardmaestrobridge` and `contactquicklook` as next spec candidates.

## Cycle 22

- `started_at`: 2026-06-22T00:14:22Z
- `mode`: recurring heartbeat focused pass
- `automation_id`: `surface-plugin-research-loop`
- `focus`: `keyboardmaestrobridge`
- `question`: can Surface show Keyboard Maestro status/macros without becoming a macro runner, editor, CLI wrapper, or plug-in action system?

### Findings

- Keyboard Maestro already owns the automation runtime: the Engine executes macros, watches triggers, manages palettes/clipboard features, and honors macro group activation state.
- Keyboard Maestro exposes several run/edit paths: AppleScript `do script`, `kmtrigger://` local URLs, trigger files, and the bundled `keyboardmaestro` CLI. Some of these can execute action XML or block until a macro finishes.
- `scriptoutput` already owns generic process execution, and `permissionsdashboard` owns Apple Events permission state, so `keyboardmaestrobridge` should not call AppleScript, run `osascript`, run the CLI, or execute action XML in v1.
- Keyboard Maestro's Write to a File action and JSON tooling support a safe export shape: Keyboard Maestro or a user-owned script writes a curated JSON manifest and Surface reads it.
- Therefore `keyboardmaestrobridge` should start read-mostly: exported engine/status rows, curated macro rows, stale labels, copy/open/reveal actions, and optional predeclared local `kmtrigger://` or `keyboardmaestro://m=` opens only when live actions are allowed.

### Output

- Added `keyboardmaestrobridge-spec.md`.
- Extended `source-ledger.tsv` with Keyboard Maestro Engine, scripting, URL trigger/scheme, CLI, Write to File, and JSON export docs.
- Promoted `keyboardmaestrobridge` to ready-to-implement.
- Updated the queue with `contactquicklook` and `bookmarkcards` as next spec candidates.

## Cycle 23

- `started_at`: 2026-06-22T00:46:53Z
- `mode`: recurring heartbeat focused pass
- `automation_id`: `surface-plugin-research-loop`
- `focus`: `contactquicklook`
- `question`: can Surface show useful contact quick cards without broad address-book reads, duplicate contact search, or hidden permission prompts?

### Findings

- Contacts access is sensitive and needs explicit permission UI plus `NSContactsUsageDescription` bundle support before live lookup ships.
- `permissionsdashboard` already owns the permission surface, while Copy History, `contextcard`, and `calendarprep` can own future person hints. `contactquicklook` should not add another capture/search owner.
- Apple Contacts APIs support a constrained shape: `CNContactFetchRequest` with minimal `keysToFetch`, exact predicates for identifiers/email/phone, and localized name formatting through `CNContactFormatter`.
- Apple also provides system/user-mediated contact sharing patterns such as pickers and limited access. Those reinforce explicit, contextual contact access rather than startup enumeration.
- Therefore `contactquicklook` should start fixture/cached-card first, then add explicit exact lookup only after permission and bundle support exist. It should not enumerate all contacts or build a broad address book.

### Output

- Added `contactquicklook-spec.md`.
- Extended `source-ledger.tsv` with Contacts framework, Info.plist, contact fetch/predicate/formatter/change/picker/access sources.
- Promoted `contactquicklook` to ready-to-implement.
- Updated the queue with `bookmarkcards` and `texttransform` as next spec candidates.

## Cycle 24

- `started_at`: 2026-06-22T01:22:23Z
- `mode`: recurring heartbeat focused pass
- `automation_id`: `surface-plugin-research-loop`
- `focus`: `bookmarkcards`
- `question`: can Surface show useful bookmark/read-later cards without duplicating `linkinbox` or scraping browser profiles/history?

### Findings

- `linkinbox` already owns URL capture, dedupe, archive/pin/tag triage, pasteboard extraction, and future metadata fetches. `bookmarkcards` should not become another URL inbox.
- Browser bookmark access is validated by Raycast and browser extension APIs, but those paths imply browser/profile selection, extension permissions, and mutation risk.
- Chrome/WebExtension bookmark APIs are appropriate future extension/cache adapters, while Safari support should also be extension/cache based rather than profile scraping.
- Exported bookmark HTML files and macOS internet-location files are safer future import paths because the user explicitly selects files.
- Therefore `bookmarkcards` should start as a local JSON shelf for curated links: grouped rows, stale/source labels, open/copy/pin/mark-read/archive actions, and no browser profile/history reads in v1.

### Output

- Added `bookmarkcards-spec.md`.
- Extended `source-ledger.tsv` with Raycast Browser Bookmarks, MarkMarks, Chrome/WebExtension bookmark APIs, Safari Web Extensions, Firefox bookmark export, and Apple internet-location sources.
- Promoted `bookmarkcards` to ready-to-implement.
- Updated the queue with `texttransform` and `appquicklaunch` as next spec candidates.

## Cycle 25

- `started_at`: 2026-06-22T01:52:23Z
- `mode`: recurring heartbeat focused pass
- `automation_id`: `surface-plugin-research-loop`
- `focus`: `texttransform`
- `question`: can Surface transform copied/explicit text without becoming selected-text automation, AI rewrite, or a custom script runner?

### Findings

- Raycast text transform extensions validate the workflow: transform selected or clipboard text, then paste or copy. The risky part for Surface is active-app selection and paste-back behavior.
- Existing Surface owners already cover the neighboring responsibilities: Copy History owns passive clipboard history, `snippetprompt` owns templates, `scriptoutput` owns custom scripts, `contextcard` owns selected text, and `aicommandscratchpad` owns AI work.
- Swift/Foundation APIs cover a useful v1 built-in set: string transforms, percent encoding, Base64, JSON serialization, and fixed internal regex cleanup.
- Therefore `texttransform` should start as explicit-input and copy-only: fixture/pasted/explicit clipboard text in, deterministic transform out, no selected-text scraping, no active-app paste, no AI, no shell, no programmable regex pipeline.

### Output

- Added `texttransform-spec.md`.
- Extended `source-ledger.tsv` with Raycast transform examples and Foundation string/URL/Base64/JSON/regex sources.
- Promoted `texttransform` to ready-to-implement.
- Updated the queue with `appquicklaunch` and `clipboardrules` as next spec candidates.

## Cycle 26

- `started_at`: 2026-06-22T02:27:23Z
- `mode`: recurring heartbeat focused pass
- `automation_id`: `surface-plugin-research-loop`
- `focus`: `appquicklaunch`
- `question`: can Surface provide useful app/file/document quick-launch cards without becoming a Raycast/Spotlight clone, macro runner, or workspace restorer?

### Findings

- Raycast Quicklinks validate curated paths/files/URLs/apps, but its root-search, Quick Search, and browser autofill features show the scope Surface should avoid in v1.
- Hammerspoon validates launch-or-focus and bundle-id workflows, but also shows why Surface should not absorb a broader automation runtime or app search layer.
- AppKit has enough direct API surface for a narrow Swift implementation: resolve app URLs by bundle id, launch app URLs, focus running apps, open files/folders/URLs with optional configured app, and reveal targets in Finder.
- Existing Surface owners already cover the neighboring responsibilities: `contextcard` owns front-app state, `fileinbox` owns recent files, `linkinbox` owns URL triage, `bookmarkcards` owns bookmark shelves, and automation bridges own macro/script triggers.
- Therefore `appquicklaunch` should start as a curated JSON launch shelf: explicit targets in, one explicit open/focus/reveal/copy action out, no indexing, global hotkeys, selected text, scripts, workspace restore, or second registry.

### Output

- Added `appquicklaunch-spec.md`.
- Extended `source-ledger.tsv` with Raycast Quicklinks launch behavior, Hammerspoon app launch helpers, and AppKit launch/open/focus/reveal APIs.
- Promoted `appquicklaunch` to ready-to-implement.
- Updated the queue with `clipboardrules` and `workspacepins` as next spec candidates.

## Cycle 27

- `started_at`: 2026-06-22T02:58:53Z
- `mode`: recurring heartbeat focused pass
- `automation_id`: `surface-plugin-research-loop`
- `focus`: `clipboardrules`
- `question`: can Surface add useful clipboard filtering without becoming a second clipboard daemon, rule engine, or automation router?

### Findings

- The repo already has the right owner: `plugins/copyhistory/source/Plugin.swift` polls `NSPasteboard.general.changeCount`, normalizes text, persists `copyhistory.txt`, copies entries back to the pasteboard, and renders the block.
- Raycast, Alfred, and Maccy validate retention, disabled apps, max-size limits, pause/ignore-next controls, and confidential/transient marker handling.
- Keyboard Maestro validates clipboard filter actions, but that path is exactly what Surface should avoid: script/macro actions over clipboard entries would duplicate `scriptoutput` and the automation bridges.
- `NSPasteboard.org` marker conventions give a concrete low-risk v1: ignore transient, concealed, autogenerated, proprietary password/temporary, source, and remote clipboard markers before storing text.
- Therefore `clipboardrules` should be implemented as Copy History Rules inside the existing Copy History block: a pure capture decision before storage, metadata-only blocked counters, no blocked text persistence, no new plugin target, no second watcher, no active-app monitoring, no scripts, and no routing.

### Output

- Added `clipboardrules-spec.md`.
- Extended `source-ledger.tsv` with Raycast/Alfred/Maccy/Keyboard Maestro clipboard behavior, NSPasteboard marker conventions, and Apple pasteboard API sources.
- Promoted `clipboardrules` to ready-to-implement as a Copy History-owned enhancement.
- Updated the queue with `workspacepins` and `scratchcapturestack` as next spec candidates.

## Cycle 28

- `started_at`: 2026-06-22T03:33:23Z
- `mode`: recurring heartbeat focused pass
- `automation_id`: `surface-plugin-research-loop`
- `focus`: `workspacepins`
- `question`: can Surface show useful project/workspace cards by composing existing owners without becoming multi-app session restore or a project registry?

### Findings

- Raycast Quicklinks validate explicit project-folder/file/URL/deeplink anchors, but Root Search and argument-based quicklinks are outside the `workspacepins` v1 boundary.
- VS Code workspaces validate a file-backed model for grouping project folders, but tasks/debug/build execution should remain outside Surface workspace cards.
- macOS Spaces and Hammerspoon Spaces show why session restore is risky: Spaces are user-managed and Hammerspoon's Spaces API depends on private APIs plus Accessibility workarounds.
- Existing Surface owners already split the work: `appquicklaunch` opens one target, `fileinbox` scans recent files, `contextcard` captures app/window context, `bookmarkcards`/`linkinbox` own links, `windowlayouts` moves windows, and `scriptoutput`/`localbuildstatus` own command/status output.
- Therefore `workspacepins` should be a curated read-mostly project-card block: explicit roots/notes/refs in, one open/reveal/copy action out, optional cached summaries, no session restore, no Spaces/window/tab control, no command execution, and no second registry.

### Output

- Added `workspacepins-spec.md`.
- Extended `source-ledger.tsv` with Raycast Quicklinks workspace anchors, VS Code workspace docs, Apple Spaces, and Hammerspoon Spaces/Expose sources.
- Promoted `workspacepins` to ready-to-implement.
- Updated the queue with `scratchcapturestack` and `worktreecards` as next spec candidates.

## Cycle 29

- `started_at`: 2026-06-22T09:40:14Z
- `mode`: recurring heartbeat focused pass
- `automation_id`: `surface-plugin-research-loop`
- `focus`: `scratchcapturestack`
- `question`: can Surface show a short-lived working stack across Quicksave, File Inbox, Copy History, and Link Inbox without becoming a universal inbox, file manager, or action runner?

### Findings

- Dropzone Drop Bar, Yoink, Dropover, and Unclutter validate the user need: a visible shelf for scattered files, text, links, and current-work artifacts reduces Finder/app switching.
- The risk is also clear from those products: shelves easily expand into file managers, clipboard histories, cloud uploaders, processors, watched folders, and unified note/file/clipboard spaces.
- Existing Surface owners already split the durable responsibilities: Quicksave owns capture/write paths, File Inbox owns scanning, Copy History owns passive history/rules, Link Inbox owns URL triage, Bookmark Cards owns durable link shelves, and Workspace Pins owns project refs.
- Therefore `scratchcapturestack` should own only a bounded short-lived JSON stack of explicit refs and row actions: copy/open/reveal/pin/done/remove/clear-expired. It should not scan, watch, fetch, upload, process, or mutate source plugin stores.

### Output

- Added `scratchcapturestack-spec.md`.
- Extended `source-ledger.tsv` with Dropzone Drop Bar detail plus Yoink, Dropover, and Unclutter shelf sources.
- Promoted `scratchcapturestack` to ready-to-implement.
- Updated the queue with `worktreecards` and `readmehub` as next spec candidates.

## Cycle 30

- `started_at`: 2026-06-23T04:43:16Z
- `mode`: recurring heartbeat focused pass
- `automation_id`: `surface-plugin-research-loop`
- `focus`: `worktreecards`
- `question`: can Surface show linked worktree status by composing GitHub Queue, Local Build Status, File Inbox, and App Quick Launch without becoming a git client, build runner, or worktree manager?

### Findings

- Git documents `git worktree list --porcelain` as stable, script-friendly, and safer with `-z`; it exposes exactly the worktree-level fields Surface needs: path, HEAD, branch, locked, prunable, bare, and detached.
- Git worktree mutation commands have nontrivial safety conditions around dirty, locked, missing, moved, and portable worktrees, so create/remove/prune/repair/lock/unlock should stay outside v1.
- `localbuildstatus` already owns the per-worktree branch/dirty/build-status parsing shape, while `githubqueue` owns PR/check/review data, `fileinbox` owns recent-file scans, and `appquicklaunch` owns open/reveal behavior.
- Therefore `worktreecards` should be read-only and cache-backed: worktree list plus optional status/result/PR/recent-file caches, with explicit open/reveal/copy/open-PR actions only.

### Output

- Added `worktreecards-spec.md`.
- Extended `source-ledger.tsv` with Git worktree porcelain/mutation sources, GitHub PR status, and VS Code CLI launch docs.
- Promoted `worktreecards` to ready-to-implement.
- Updated the queue with `readmehub` and `registryhealth` as next spec candidates.

## Cycle 31

- `started_at`: 2026-06-24T02:03:57Z
- `mode`: recurring heartbeat focused pass
- `automation_id`: `surface-plugin-research-loop`
- `focus`: `readmehub`
- `question`: can Surface expose repo/plugin docs, plugin authoring steps, README links, preview commands, and spec status without becoming a Markdown editor, docs generator, scaffolder, health checker, or second registry?

### Findings

- Surface's own README already owns the canonical plugin path: `Block`, `BlockRuntime`, `Block.Context`, `plugins/Blocks.swift`, Package.swift wiring, focused tests, block preview fixtures, and preview smoke tests.
- Plugin-local READMEs such as Codex Log already prove the right owner model for plugin-specific contracts, fixture rules, and development loops.
- External docs reinforce the boundary: GitHub READMEs and Markdown support headings/links/code blocks; CommonMark gives a stable syntax baseline; DocC and VS Code Markdown cover full generation/edit/preview workflows that should stay outside this block.
- Therefore `readmehub` should be a bounded read-only docs index: configured/local docs in, headings/links/commands/checklists out, with open/reveal/copy actions only. It should not generate docs, edit Markdown, run commands, validate registry health, create plugins, or mutate package/registry files.

### Output

- Added `readmehub-spec.md`.
- Extended `source-ledger.tsv` with GitHub README/Markdown docs, CommonMark, Swift-DocC, VS Code Markdown, and local Surface README/Codex Log README sources.
- Promoted `readmehub` to ready-to-implement.
- Updated the queue with `registryhealth` and `plugintemplates` as next spec candidates.

## Cycle 32

- `started_at`: 2026-06-24T02:36:57Z
- `mode`: recurring heartbeat focused pass
- `automation_id`: `surface-plugin-research-loop`
- `focus`: `registryhealth`
- `question`: can Surface show registry, package, preview-fixture, test, and layout health without becoming a second registry, generator, scaffolder, or test runner?

### Findings

- Surface already has the right owners: `plugins/Blocks.swift` is the active registry, `Package.swift` owns targets/tests, `BlockRegistry` rejects duplicate ids, `SurfaceLayout.defaultLayout` owns default block ids, and `BlockPreviewSupport`/`BlockPreviewTests` own fixture rendering and nonblank preview enforcement.
- The README's add-a-plugin checklist is a useful source of the health dimensions: registry entry, package wiring, tests, preview fixtures, optional layout entry, and focused validation commands.
- The safe product boundary is therefore a report-backed diagnostic block. It can display mismatches and copy/open commands/files, but it should not run tests, mutate source files, generate `Blocks.swift`, add Package targets, or scaffold plugins.
- The unresolved implementation question is the writer and location for the generated registry health report: likely `block-preview`, `localbuildstatus`, or a separate explicit verification script. The block should consume that report rather than own generation.

### Output

- Added `registryhealth-spec.md`.
- Extended `source-ledger.tsv` with local registry, package, layout, preview support, preview tests, and Swift PackageDescription sources.
- Promoted `registryhealth` to ready-to-implement as a read-only health view.
- Updated the queue with `plugintemplates` and `diagnosticbundle` as next spec candidates, plus a report-writer research item.

## Cycle 33

- `started_at`: 2026-06-24T03:39:52Z
- `mode`: recurring heartbeat focused pass
- `automation_id`: `surface-plugin-research-loop`
- `focus`: `plugintemplates`
- `question`: can Surface provide useful plugin starter templates and checklists without generating code, mutating Package.swift/Blocks.swift, or creating a second plugin system?

### Findings

- Surface already has the authoring owners: README for the checklist, AGENTS for the preview loop, Package.swift for target wiring, `plugins/Blocks.swift` for the registry, BlockPreviewSupport/BlockPreviewTests for fixture coverage, and existing plugins as examples.
- Raycast and VS Code validate the value of starter templates, but both lean on generators/toolchains. For Surface v1, that would add a second owner for the same files the README already tells users to edit.
- GitHub template repositories are even coarser: they copy whole repository structures into unrelated histories, which does not fit adding one plugin target inside the current Swift package.
- Therefore `plugintemplates` should be a read-only/copy-only authoring reference block: pattern cards, small snippets, checklists, open/reveal example files, and copied validation commands. It should not write files, run tools, fetch remote templates, or own package/registry changes.

### Output

- Added `plugintemplates-spec.md`.
- Extended `source-ledger.tsv` with local Surface authoring owners plus Raycast, VS Code, GitHub template, and Apple PackageDescription target sources.
- Promoted `plugintemplates` to ready-to-implement as a copy-only reference block.
- Updated the queue with `diagnosticbundle` and `previewgallery` as next spec candidates, plus a template catalog ownership research item.

## Cycle 34

- `started_at`: 2026-06-24T04:09:52Z
- `mode`: recurring heartbeat focused pass
- `automation_id`: `surface-plugin-research-loop`
- `focus`: `diagnosticbundle`
- `question`: can Surface collect a shareable local support bundle from existing artifacts without adding telemetry, sysdiagnose, broad log capture, secret collection, or a daemon?

### Findings

- Surface already has the useful inputs: `localbuildstatus` result files, `registryhealth` reports, `readmehub` indexes, `notificationdigest` event summaries, block-preview PNGs, and any explicit artifacts produced by `scriptoutput` or verification scripts.
- External diagnostic systems draw the boundary clearly: GitHub issue forms validate structured support summaries, Sentry and Apple logging docs emphasize redaction/privacy, OpenTelemetry shows that log collection quickly becomes a file-watching agent, and sysdiagnose is a broad system diagnostic archive.
- Therefore `diagnosticbundle` should be a local explicit-export block: read an allowlist manifest, show exactly what will be copied, export selected files into a folder with `summary.md`, `manifest.json`, and `redaction-report.json`, and reveal/copy paths.
- It should not run commands, collect fresh logs, trigger sysdiagnose, upload/share automatically, include Codex databases or private stores by default, compress with shell tools, mutate source stores, or duplicate any status owner.

### Output

- Added `diagnosticbundle-spec.md`.
- Extended `source-ledger.tsv` with local Surface artifact owners plus GitHub issue forms, Sentry scrubbing, Apple OSLog/privacy manifest/sysdiagnose, and OpenTelemetry log-collection sources.
- Promoted `diagnosticbundle` to ready-to-implement as an explicit local support export block.
- Updated the queue with `previewgallery` and `crashreports` as next spec candidates, plus a compression/redaction research item.

## Cycle 35

- `started_at`: 2026-06-24T04:42:52Z
- `mode`: recurring heartbeat focused pass
- `automation_id`: `surface-plugin-research-loop`
- `focus`: `previewgallery`
- `question`: can Surface inspect existing block-preview PNG outputs without running previews, replacing the block-preview harness, becoming a screenshot manager, or owning visual diffs?

### Findings

- Surface already has the preview owners: `BlockPreview.render` writes `<block>-<fixture>.png`, `BlockPreview.renderSurface` writes `surface-active.png`, the CLI prints metrics, and `BlockPreviewTests` enforce fixture coverage and nonblank output.
- The README and AGENTS loop already tells developers to render previews and inspect `.build/block-previews`; the missing surface is a compact local viewer over those artifacts.
- External visual testing systems validate the value of screenshot artifacts and visual snapshots, but their baseline/diff/update workflows would add a new testing owner. GitHub artifacts validate sharing generated images, but export/upload belongs to CI or `diagnosticbundle`.
- Therefore `previewgallery` should be a read-only image artifact viewer: bounded PNG directory in, thumbnails/metadata/status/copy actions out. It should not render, mutate, export, compare, approve, or scan arbitrary screenshots.

### Output

- Added `previewgallery-spec.md`.
- Extended `source-ledger.tsv` with local block-preview output/CLI/metrics sources plus Apple image/thumbnail docs, Storybook/Playwright visual test sources, and GitHub artifact source.
- Promoted `previewgallery` to ready-to-implement as a read-only preview artifact viewer.
- Updated the queue with `crashreports` and `visualbaselines` as next spec candidates, plus a preview baseline policy research item.

## Cycle 36

- `started_at`: 2026-06-24T05:40:59Z
- `mode`: recurring heartbeat focused pass
- `automation_id`: `surface-plugin-research-loop`
- `focus`: `crashreports`
- `question`: can Surface surface crash report pointers from explicit files without reading DiagnosticReports directories broadly, collecting telemetry, symbolication, or duplicating diagnostic/export owners?

### Findings

- Apple positions crash reports as detailed crash-state artifacts with structured fields, and Console exposes user/system crash reports such as `.ips` files. That supports a file-pointer block, not a system-wide scanner.
- Apple's crash report field and JSON documentation show useful bounded metadata: process/app, bundle, incident, OS/app version, exception, termination, threads, frames, and binary images. Surface should show top fields and omit raw frames/images by default.
- MetricKit is an app-integrated diagnostics path. It is useful evidence that crash diagnostics can be app-owned, but it would be a separate collection integration and should not be folded into this pointer block.
- Existing Surface owners already cover the dangerous adjacent jobs: `diagnosticbundle` exports/redacts support artifacts, `fileinbox` triages broad files, `notificationdigest` owns event summaries, and `scriptoutput` owns command producers.
- Therefore `crashreports` should be manifest-backed and explicit-file-only: `.ips`/`.crash` paths in, small metadata/status/copy/open actions out. It should not scan DiagnosticReports, tail unified logs, symbolicate, upload/export, mutate reports, infer root cause, or add a second registry.

### Output

- Added `crashreports-spec.md`.
- Extended `source-ledger.tsv` with local diagnostic owner sources plus Apple crash report, Console, acquiring-reports, and MetricKit sources.
- Promoted `crashreports` to ready-to-implement as an explicit crash artifact pointer block.
- Updated the queue with `visualbaselines` and `crashsymbolication` as next spec candidates, plus a crash symbolication policy research item.

## Cycle 37

- `started_at`: 2026-06-24T06:45:40Z
- `mode`: recurring heartbeat focused pass
- `automation_id`: `surface-plugin-research-loop`
- `focus`: `visualbaselines`
- `question`: should Surface visual baseline/diff policy live in `block-preview`/tests or in a plugin such as `previewgallery`?

### Findings

- Surface already has the right rendering owner: `BlockPreview.renderAll` and `BlockPreview.renderSurface` generate deterministic PNGs through the real `Block` / `BlockRuntime` / `Block.Context` path.
- `BlockPreviewTests` already enforce fixture coverage and nonblank PNGs, so baseline enforcement belongs beside those tests.
- `previewgallery-spec.md` already says the gallery must not implement visual baselines, pixel diffs, approval workflows, or snapshot updates. That remains the correct boundary.
- Playwright, Storybook, and Swift SnapshotTesting all place screenshot/reference comparison in the test workflow, with explicit update/record behavior and test artifacts.
- Apple XCTest attachments support images, screenshots, files, folders, and strings as test outputs, which gives Surface a native path for attaching current/baseline/diff artifacts without inventing an overlay approval UI.
- Therefore `visualbaselines` should be a block-preview/test-harness feature: checked-in baselines plus explicit check/record commands and `.build` diff/report artifacts. It should not be a plugin, registry entry, screenshot manager, hosted service integration, or `previewgallery` mutation path.

### Output

- Added `visualbaselines-spec.md`.
- Extended `source-ledger.tsv` with local preview owner/boundary rows plus Swift SnapshotTesting and XCTest attachment sources.
- Marked `visualbaselines` ready to implement as a harness feature, not a plugin.
- Updated `plugin-ideas.md` with a non-plugin design rule and Cycle 37 decision.
- Updated the queue with `crashsymbolication` and `visualartifactretention` as next spec candidates, plus a visual artifact retention research item.

## Cycle 38

- `started_at`: 2026-06-25T05:33:03Z
- `mode`: recurring heartbeat focused pass
- `automation_id`: `surface-plugin-research-loop`
- `focus`: `crashsymbolication`
- `question`: should Surface run symbolication tools, or should it only expose explicit Xcode/CLI handoffs from `crashreports`?

### Findings

- Apple says Xcode is the preferred crash symbolication path because it can use available dSYM files on the Mac. The command-line path is specialized and tool-specific.
- Apple also documents generating distribution debug info with `DWARF with dSYM File`; without matching symbols, Surface cannot prove a report is symbolication-ready.
- `crashreports-spec.md` already excludes running `atos`, `symbolicatecrash`, `xcrun`, `log`, or Xcode from the block runtime.
- `scriptoutput` already owns bounded command execution if the user later wants an explicit external symbolication producer. `diagnosticbundle` owns export/redaction, and `fileinbox` owns broad file triage.
- Therefore `crashsymbolication` should be a copy-only extension inside `crashreports`: explicit paths and parsed UUID/address clues in, readiness chips and copied Xcode/`atos` instructions out. It should not be a plugin, runner, dSYM scanner, uploader, DWARF parser, or root-cause analyzer.

### Output

- Added `crashsymbolication-spec.md`.
- Extended `source-ledger.tsv` with local owner boundaries plus Apple symbolication, dSYM/debug-info, and crash-diagnosis sources.
- Marked `crashsymbolication` ready to implement as a copy-only `crashreports` extension, not a separate plugin.
- Updated `plugin-ideas.md` with a non-plugin symbolication design rule and Cycle 38 decision.
- Updated the queue with `visualartifactretention` and `dsymcatalog` as next spec candidates, plus a dSYM/archive catalog policy research item.

## Cycle 39

- `started_at`: 2026-06-25T13:43:27Z
- `mode`: recurring heartbeat focused pass
- `automation_id`: `surface-plugin-research-loop`
- `focus`: `visualartifactretention`
- `question`: how should Surface retain visual baseline current/diff/baseline artifacts without adding a plugin, cleanup daemon, uploader, or premature Git LFS setup?

### Findings

- Surface already ignores `.build/`, and `visualbaselines-spec.md` already places generated current images, diff images, and `visualbaselines.json` under `.build`.
- Therefore local generated artifacts should be latest-only and disposable: `baseline-check` should overwrite the known `.build` output directories and report.
- Checked-in baseline PNGs are test fixtures under `tests/BlockPreviewTests/Baselines`; they should be reviewed like source/test data, not managed by a runtime retention system.
- GitHub Actions artifact upload supports `retention-days`, with a 90-day default and a 1-to-90 day range. CI visual artifacts should be uploaded only on failure, with short retention such as 7 days.
- GitHub recommends small repositories, and Git LFS exists for large binary files. For the expected baseline set, plain Git is simpler until measured individual/total baseline size or churn justifies LFS.
- Therefore `visualartifactretention` is repository/test/CI policy: ignored `.build` outputs, failure-only CI artifacts, measured baseline-size thresholds, and optional later LFS. It should not be a block, daemon, watcher, cleaner, uploader, exporter, or registry.

### Output

- Added `visualartifactretention-spec.md`.
- Extended `source-ledger.tsv` with local `.gitignore`/`visualbaselines` rows plus GitHub Actions artifact retention and Git/Git LFS storage sources.
- Marked `visualartifactretention` ready to implement as repository/test/CI policy, not a plugin.
- Updated `plugin-ideas.md` with a non-plugin visual artifact retention design rule and Cycle 39 decision.
- Updated the queue with `dsymcatalog` and `baselineplatforms` as next spec candidates, plus a baseline platform policy research item.

## Cycle 40

- `started_at`: 2026-06-25T19:54:30Z
- `mode`: recurring heartbeat focused pass
- `automation_id`: `surface-plugin-research-loop`
- `focus`: `dsymcatalog`
- `question`: are explicit dSYM/archive catalogs worth supporting after `crashreports`, without scanning DerivedData, Xcode Archives, Spotlight, or symbol stores from a block?

### Findings

- Apple crash-report field docs use binary image UUIDs to connect crash reports to matching dSYM files. UUID matching is the only strong catalog match; bundle id and version/build are useful but weaker.
- Apple symbolication docs say Xcode is preferred and manual symbolication involves tools such as `dwarfdump`/`atos`; those tools should remain outside Surface runtime.
- Apple App Store Connect and Xcode help document debug-symbol download/archive workflows for eligible builds. Those are Xcode/App Store Connect responsibilities, not Surface plugin behavior.
- Existing Surface owners already split the adjacent work: `crashreports` reads explicit crash files, `crashsymbolication` copies handoff text, `scriptoutput` can run future external producers, `diagnosticbundle` exports selected artifacts, and `fileinbox` handles broad file triage.
- Therefore `dsymcatalog` should be an optional explicit JSON manifest read by `crashreports`: explicit dSYM/archive/app paths and UUID metadata in, match/readiness/copy/reveal out. It should not be a plugin, scanner, downloader, symbol store, DWARF parser, or second registry.

### Output

- Added `dsymcatalog-spec.md`.
- Extended `source-ledger.tsv` with local `crashsymbolication` boundary plus Apple crash UUID, symbolication, App Store Connect dSYM, and Xcode debug-symbol sources.
- Marked `dsymcatalog` ready to implement as an explicit manifest inside `crashreports`, not a separate plugin.
- Updated `plugin-ideas.md` with a non-plugin dSYM catalog design rule and Cycle 40 decision.
- Updated the queue with `baselineplatforms` and `crashattachmentpolicy` as next spec candidates, plus a crash attachment policy research item.

## Cycle 41

- `started_at`: 2026-06-25T20:30:31Z
- `mode`: recurring heartbeat focused pass
- `automation_id`: `surface-plugin-research-loop`
- `focus`: `baselineplatforms`
- `question`: should visual baselines be per-macOS/per-architecture/per-scale-factor now, or single-lane until rendering variance is measured?

### Findings

- Surface targets macOS 14+, and the preview harness renders through AppKit/SwiftUI via `NSHostingView.bitmapImageRepForCachingDisplay`.
- `renderSurface` also consults `NSScreen.main?.visibleFrame`, so display/screen context can affect full-surface preview dimensions.
- Apple high-resolution drawing docs distinguish point layout from pixel backing stores and scale factors; `NSScreen.backingScaleFactor` makes scale observable.
- GitHub runner docs and runner-images updates make the CI environment an explicit dependency. Visual-baseline enforcement should pin a concrete macOS runner label rather than `macos-latest`.
- There is no measured evidence yet that Surface needs per-OS, per-architecture, or per-scale baseline directories. Multiple lanes would add maintenance cost and risk hiding renderer instability.
- Therefore `baselineplatforms` should be harness policy: one default baseline lane, platform metadata in `platform.json` and `visualbaselines.json`, `platformMismatch` before pixel mismatch, and additional lanes only after repeated measured variance proves they are necessary.

### Output

- Added `baselineplatforms-spec.md`.
- Extended `source-ledger.tsv` with local Package/BlockPreview rows plus Apple high-resolution/scale docs and GitHub runner environment sources.
- Marked `baselineplatforms` ready to implement as visual-baseline harness policy, not a plugin.
- Updated `plugin-ideas.md` with a non-plugin baseline platform design rule and Cycle 41 decision.
- Updated the queue with `crashattachmentpolicy` and `rendererscalecontrol` as next spec candidates, plus a renderer scale-control research item.

## Cycle 42

- `started_at`: 2026-06-25T21:05:37Z
- `mode`: recurring heartbeat focused pass
- `automation_id`: `surface-plugin-research-loop`
- `focus`: `crashattachmentpolicy`
- `question`: which crash, dSYM, archive, binary, and symbolication artifacts may `diagnosticbundle` export by default, and which require manual review or exclusion?

### Findings

- `diagnosticbundle` already owns export, redaction modes, skipped reasons, and generated support folders. Crash attachment policy belongs there as classification data, not as a new plugin or exporter.
- `crashreports` already treats raw crash text as sensitive and produces bounded summaries; those summaries can export by default, while raw `.ips` and `.crash` files should be manual-review.
- `crashsymbolication` is copy-only handoff text; generated handoff/checklist artifacts can export by default, but raw symbolication output should be manual-review.
- `dsymcatalog` is metadata only; redacted catalog rows can export by default, but dSYM bundles, Xcode archives, app bundles, executables, BCSymbolMaps, and sysdiagnose artifacts should be excluded by default in v1.
- Apple crash reports include detailed crash sections such as thread state and binary images, so raw reports should be treated as sensitive.
- Sentry supports attaching logs/config files to events, and GitHub uploads issue attachments immediately. Surface should copy local summaries and never attach/upload crash artifacts automatically.

### Output

- Added `crashattachmentpolicy-spec.md`.
- Extended `source-ledger.tsv` with local owner boundaries plus Apple crash-report, Sentry attachment, and GitHub file-attachment sources.
- Marked `crashattachmentpolicy` ready to implement as `diagnosticbundle` artifact classification policy, not a plugin.
- Updated `plugin-ideas.md` with a non-plugin crash attachment policy design rule and Cycle 42 decision.
- Updated the queue with `rendererscalecontrol` as the next spec candidate and `diagnosticbundleredactionkeys` as the follow-up policy refinement.

## Cycle 43

- `started_at`: 2026-06-28T17:46:46Z
- `mode`: recurring heartbeat focused pass
- `automation_id`: `surface-plugin-research-loop`
- `focus`: `rendererscalecontrol`
- `question`: should `BlockImageRenderer` accept explicit scale, appearance, and locale configuration before Surface adds another visual-baseline platform lane?

### Findings

- The current renderer owner is `BlockImageRenderer` in `BlockPreviewSupport`: it creates an `NSHostingView`, asks for `bitmapImageRepForCachingDisplay`, caches display into that bitmap, and encodes PNG without explicit scale, appearance, or locale inputs.
- `baselineplatforms-spec.md` already says to prefer renderer determinism before adding baseline lanes and identifies scale, appearance, and locale as platform metadata.
- Apple high-resolution drawing docs and `NSScreen.backingScaleFactor` explain why point size and backing pixel size are separate. Baselines should control renderer scale before treating scale differences as platform lanes.
- Apple `NSBitmapImageRep` and `NSView.cacheDisplay` keep fixed-scale rendering inside the same AppKit rendering family Surface already uses.
- AppKit `NSAppearance` and SwiftUI `locale` / `colorScheme` environment values let previews set deterministic light/dark and locale inputs locally without mutating system settings.
- Therefore `rendererscalecontrol` should be a small `BlockImageRenderer` / `BlockPreview` configuration, not a plugin, second renderer, or platform registry.

### Output

- Added `rendererscalecontrol-spec.md`.
- Extended `source-ledger.tsv` with local renderer/baseline owner rows plus Apple bitmap, cache-display, appearance, locale, and color-scheme sources.
- Marked `rendererscalecontrol` ready to implement as renderer configuration in `BlockPreviewSupport`.
- Updated `plugin-ideas.md` with a non-plugin renderer scale-control design rule and Cycle 43 decision.
- Updated the queue with `diagnosticbundleredactionkeys` as the next spec candidate and `visualbaselinereportschema` as a visual-baseline schema follow-up.

## Cycle 44

- `started_at`: 2026-06-28T18:22:16Z
- `mode`: recurring heartbeat focused pass
- `automation_id`: `surface-plugin-research-loop`
- `focus`: `diagnosticbundleredactionkeys`
- `question`: what exact key/path redaction map and exported summary format should `diagnosticbundle` use first, with `crashattachmentpolicy` as the strictest input class?

### Findings

- `diagnosticbundle` already owns redaction modes, `summary.md`, and `redaction-report.json`; redaction keys should be constants in that owner, not a new sanitizer plugin or registry.
- `crashattachmentpolicy` already keeps raw crash/symbol artifacts manual-review or excluded by default, so this pass should only refine structured summaries and metadata.
- OWASP logging guidance and Sentry sensitive-data guidance both point to secrets, session/auth tokens, credentials, and personal data as redaction candidates.
- Apple OSLog privacy guidance reinforces treating potentially sensitive logged values as private, which supports leaving unstructured text logs manual-review unless they are structured JSON/JSONL.
- Therefore v1 should use exact key/dotted-path maps over JSON/JSONL only, deterministic replacement tokens, repo/home path normalization, and summary/report outputs that never contain original redacted values or value hashes.

### Output

- Added `diagnosticbundleredactionkeys-spec.md`.
- Extended `source-ledger.tsv` with local owner rows plus OWASP logging, Sentry sensitive-data, and Apple OSLog privacy sources.
- Marked `diagnosticbundleredactionkeys` ready to implement inside `diagnosticbundle`, not as a plugin.
- Updated `plugin-ideas.md` with a non-plugin redaction-key design rule and Cycle 44 decision.
- Updated the queue with `visualbaselinereportschema` as the next spec candidate and `diagnosticbundlemanifestv1` as the diagnostic-bundle schema follow-up.

## Cycle 45

- `started_at`: 2026-06-28T18:53:16Z
- `mode`: recurring heartbeat focused pass
- `automation_id`: `surface-plugin-research-loop`
- `focus`: `visualbaselinereportschema`
- `question`: how should `visualbaselines`, `visualartifactretention`, `baselineplatforms`, and `rendererscalecontrol` fit into one exact `.build/surface-status/visualbaselines.json` schema before implementation?

### Findings

- `visualbaselines` already owns `.build/surface-status/visualbaselines.json`; the other visual specs add fields to that report rather than creating separate report owners.
- `visualartifactretention` contributes artifact policy fields: latest-only local retention, failure-only CI upload, retention days, baseline storage, LFS status, and baseline byte counts.
- `baselineplatforms` contributes platform lane metadata, mismatch classification, and the rule that `platformMismatch` happens before pixel interpretation.
- `rendererscalecontrol` contributes renderer configuration: scale policy, fixed scale, appearance, color scheme, locale, and output pixel dimensions.
- JSON Schema gives a standard way to describe JSON document shape, but Surface can start with a documented v1 Codable contract rather than a schema registry.
- Playwright visual comparison docs warn that rendering varies across host OS/settings/hardware, which supports recording platform and renderer metadata separately from UI diffs.
- Therefore v1 should be one generated report contract with required top-level sections, exact enum values, repo-relative paths, deterministic result ordering, and status precedence.

### Output

- Added `visualbaselinereportschema-spec.md`.
- Extended `source-ledger.tsv` with local owner rows plus JSON Schema and Playwright visual-environment evidence.
- Marked `visualbaselinereportschema` ready to implement as the v1 `visualbaselines.json` contract, not a plugin.
- Updated `plugin-ideas.md` with a non-plugin visual baseline report schema design rule and Cycle 45 decision.
- Updated the queue with `diagnosticbundlemanifestv1` as the next spec candidate and `previewgalleryvisualreader` as the read-only visual-report follow-up.
