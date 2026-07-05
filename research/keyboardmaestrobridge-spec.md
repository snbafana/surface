# `keyboardmaestrobridge` Plugin Spec

## Why This Matters

Keyboard Maestro is already a macOS automation engine. Its background engine runs macros, responds to hotkeys and many other triggers, manages palettes and clipboard features, and executes user-defined action chains. It also exposes multiple control paths: AppleScript `do script`, `kmtrigger://` URLs, trigger files, and the bundled `keyboardmaestro` CLI.

That makes it useful to surface, but the ownership line has to stay strict. Surface should not become a second Keyboard Maestro editor, macro database reader, action runner, plug-in action installer, or automation registry.

The useful Surface version is a read-mostly bridge over Keyboard Maestro-owned state: show exported macro/status rows, copy trigger links/snippets, open the macro in Keyboard Maestro, reveal the exported bridge file, and optionally open only predeclared local trigger URLs.

## Existing Owner / Dedup Decision

- Keyboard Maestro owns macros, macro groups, triggers, actions, palettes, clipboard features, editor state, engine state, remote/web triggers, and macro execution.
- `scriptoutput` owns generic process execution, stdout/stderr rendering, intervals, timeouts, and command status.
- `hammerspoonbridge` owns the Hammerspoon-specific manifest bridge pattern.
- `permissionsdashboard` owns Surface's Apple Events and Accessibility permission state.
- `contextcard`, `windowlayouts`, `mediacontrols`, and `browsersessioncards` own their native Surface domains.
- `keyboardmaestrobridge` owns only a Keyboard Maestro-exported JSON manifest, display/stale logic, copy/open/reveal actions, and optional predeclared `kmtrigger://` handoff.

Do not add a Keyboard Maestro macro runner, macro editor, AppleScript command builder, `keyboardmaestro` CLI runner, XML action executor, macro import/export tool, remote trigger client, plug-in action package, polling daemon, or second plugin registry. Implement as one `BlockRuntime` using `Block.Context.storageDirectory` and `Block.Context.now`.

## Product Boundary

It should:

- Read a Keyboard Maestro-exported bridge file.
- Show Keyboard Maestro engine/app status when exported.
- Show curated macro rows with title, group, hotkey/trigger label, state, last run, and optional note.
- Show status rows for bridge health, export warnings, disabled groups, or macro-specific warnings.
- Copy macro titles, hotkeys, trigger URLs, AppleScript snippets, and summary Markdown.
- Open `keyboardmaestro://m=<macro-or-group-id>` editor URLs when explicitly selected.
- Reveal the bridge JSON file.
- Optionally open predeclared local `kmtrigger://...` URLs from decoded rows when external actions are allowed.

It should not:

- Run `osascript` or tell `Keyboard Maestro Engine` to `do script` in v1.
- Run the bundled `keyboardmaestro` CLI.
- Execute arbitrary Keyboard Maestro action XML.
- Read or parse the full Keyboard Maestro macro database.
- Enable/disable macros or macro groups.
- Import `.kmmacros` files or install Keyboard Maestro plug-in actions.
- Create, edit, delete, rename, duplicate, or reorder macros.
- Use public/remote/web trigger URLs.
- Duplicate `scriptoutput` by running shell commands or scripts.
- Request Apple Events, Accessibility, Screen Recording, or Input Monitoring on behalf of Keyboard Maestro.

## First Version

### Data Modes

Fixture mode:

1. Read `Block.Context.storageDirectory/keyboardmaestrobridge-state.json`.
2. Use `Block.Context.now` for age and stale labels.
3. Do not call Keyboard Maestro, AppleScript, `osascript`, the CLI, or URL handlers.
4. Trigger/open actions are preview no-ops.

Live mode:

1. Read `~/Library/Application Support/Surface/KeyboardMaestroBridge/keyboardmaestrobridge-state.json` by default.
2. Allow a user-configured bridge file path later, but keep one file in v1.
3. Use `NSWorkspace.open(_:)` only for explicit open actions and only when `Block.Context.allowsExternalWrites` is true.
4. Do not run AppleScript, `osascript`, or the `keyboardmaestro` CLI in v1.

External writer:

- A Keyboard Maestro macro or user-owned script writes the bridge file.
- Keyboard Maestro should own any macro execution, including `kmtrigger://`, AppleScript `do script`, CLI triggers, trigger files, and remote/web triggers.
- The bridge file should include only curated macros that the user wants Surface to display.
- Surface should not inspect the full macro database to discover macros.

### Keyboard Maestro Export Contract

Surface expects one JSON file:

```json
{
  "version": 1,
  "exportedAt": "2026-06-22T00:14:22Z",
  "keyboardMaestro": {
    "engineRunning": true,
    "editorRunning": false,
    "version": "11.0",
    "note": "Surface bridge export macro ran"
  },
  "macros": [
    {
      "id": "984A3DBF-5B70-4031-979F-5AD44E3B24A5",
      "title": "Append Scratch Note",
      "group": "Surface",
      "state": "ready",
      "triggerLabel": "cmd+ctrl+n",
      "triggerURL": "kmtrigger://macro=984A3DBF-5B70-4031-979F-5AD44E3B24A5",
      "editURL": "keyboardmaestro://m=984A3DBF-5B70-4031-979F-5AD44E3B24A5",
      "lastRunAt": "2026-06-22T00:02:00Z",
      "note": "Uses Keyboard Maestro-owned action chain"
    }
  ],
  "statuses": [
    {
      "id": "surface-export",
      "title": "Bridge export",
      "state": "ok",
      "detail": "3 macros exported",
      "updatedAt": "2026-06-22T00:14:22Z"
    }
  ]
}
```

Keyboard Maestro can produce this with a user macro using its JSON/text tokens and Write to a File action, or with a user-owned script that queries Keyboard Maestro and writes JSON. Surface should document the shape, not generate or install the macro automatically.

### Local Data Model

```swift
struct KeyboardMaestroBridgeState: Codable, Equatable {
    var version: Int
    var exportedAt: Date
    var keyboardMaestro: KeyboardMaestroAppState?
    var macros: [KeyboardMaestroMacro]
    var statuses: [KeyboardMaestroStatus]
}

struct KeyboardMaestroAppState: Codable, Equatable {
    var engineRunning: Bool?
    var editorRunning: Bool?
    var version: String?
    var note: String?
}

struct KeyboardMaestroMacro: Codable, Identifiable, Equatable {
    var id: String
    var title: String
    var group: String?
    var state: KeyboardMaestroMacroState
    var triggerLabel: String?
    var triggerURL: URL?
    var editURL: URL?
    var lastRunAt: Date?
    var note: String?
}

enum KeyboardMaestroMacroState: String, Codable {
    case ready
    case disabled
    case inactive
    case unavailable
    case warning
}

struct KeyboardMaestroStatus: Codable, Identifiable, Equatable {
    var id: String
    var title: String
    var state: KeyboardMaestroStatusState
    var detail: String?
    var updatedAt: Date
}

enum KeyboardMaestroStatusState: String, Codable {
    case ok
    case warning
    case error
    case stale
}
```

### Display Rules

Header:

- `Keyboard Maestro`
- status pill: `ready`, `stale`, `missing`, or `blocked`
- macro count and warning count

Macro rows:

- title
- macro group
- trigger label
- state pill
- last run age if exported
- icon actions: run trigger URL, open in editor, copy trigger URL, copy AppleScript snippet, copy title

Status rows:

- title
- state
- detail
- updated age

Sort rows:

1. warnings/errors
2. ready macros with trigger URLs
3. ready macros without trigger URLs
4. disabled/inactive/unavailable macros
5. status rows by updated time

Stale policy:

- If `exportedAt` is older than 10 minutes, mark the bridge stale.
- If a status row is older than 30 minutes, mark that row stale unless it is already `error`.
- Use `Block.Context.now` for all age labels.

### Actions

- Open predeclared local `kmtrigger://` URL.
- Open predeclared `keyboardmaestro://m=` editor URL.
- Copy trigger URL.
- Copy AppleScript `do script` snippet for the macro UID.
- Copy macro title/group/hotkey.
- Copy bridge summary Markdown.
- Reveal bridge JSON.
- Open Keyboard Maestro scripting docs.

No action should run AppleScript, execute action XML, run `keyboardmaestro`, import macros, mutate macro state, or call remote/public trigger URLs.

## UI Shape

Top region:

- Keyboard Maestro engine/editor status
- bridge age and exported macro count
- small warning if triggers are blocked in preview or by policy

Main list:

- curated macro rows first
- status rows below
- fixed-size icon buttons for trigger/open/copy/reveal

Empty/missing state:

- `No bridge file`
- show expected file path
- copy JSON contract example
- open Keyboard Maestro scripting docs

Blocked state:

- `Live triggers disabled` in previews/tests or when external actions are not allowed.
- Still allow copy and reveal actions where safe.

## Runtime Shape

Target: `plugins/keyboardmaestrobridge/source/Plugin.swift`

Runtime:

1. `start()`: load bridge file.
2. `refresh()`: reload bridge file and recompute stale labels with `Block.Context.now`.
3. `stop()`: no-op.
4. `makeView()`: render engine status, macro rows, status rows, and missing/blocked states.

Use plugin-local manifest parsing first. If `hammerspoonbridge` and `keyboardmaestrobridge` later share enough file/age/action code, factor a small read-only bridge-manifest helper after both implementations exist.

## Fixture Plan

Fixtures:

- `missing`: no bridge file.
- `ready-macros`: active exported macros with trigger and edit URLs.
- `stale-export`: old `exportedAt` and stale status rows.
- `disabled-macros`: inactive/disabled/unavailable macros.
- `trigger-disabled`: ready macros but live triggers blocked in fixture mode.
- `warnings`: export warnings and macro warnings.

## Test Plan

- Missing file renders setup state.
- Bridge JSON decodes and invalid rows are reported without crashing.
- Stale bridge and stale status rows use `Block.Context.now`.
- Fixture mode disables trigger and editor open actions.
- Open-trigger action only opens a decoded `kmtrigger://` URL from a macro row.
- Open-editor action only opens a decoded `keyboardmaestro://m=` URL from a macro row.
- Public `http` or `https` remote trigger URLs are refused for trigger actions.
- Summary Markdown and AppleScript snippets are deterministic.
- No test path runs `osascript`, `keyboardmaestro`, shell commands, action XML, or AppleScript.
- Preview fixtures render nonblank PNGs through `Blocks.registry`.

## Recommendation

Implement `keyboardmaestrobridge` as a curated manifest bridge. If users want to execute macros, build macro action chains, or query the full macro database, Keyboard Maestro should own that. Surface should show a compact, stale-aware control surface over exported rows and explicit handoff URLs only.
