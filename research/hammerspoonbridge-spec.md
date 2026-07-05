# `hammerspoonbridge` Plugin Spec

## Why This Matters

Hammerspoon is already a full macOS automation runtime. It can bind hotkeys, manipulate windows, launch apps, listen to URL events, expose a CLI through `hs.ipc`, and write JSON from Lua. That makes it useful to surface, but dangerous to absorb. Surface should not become a second Hammerspoon UI, Lua runner, Spoon manager, or automation registry.

The useful Surface version is a status and handoff bridge over Hammerspoon-owned state: show exported commands/statuses, copy command labels/URLs, open config/docs, and optionally invoke only predeclared action URLs.

## Existing Owner / Dedup Decision

- `scriptoutput` owns generic executable running, stdout/stderr rendering, and process status.
- `windowlayouts` owns focused-window move/resize through native Swift/AX.
- `mediacontrols` owns audio route state.
- `contextcard` owns frontmost app/window identity.
- `permissionsdashboard` owns Surface's own Accessibility, Apple Events, Screen Recording, and related permission states.
- Hammerspoon owns Lua config, Spoons, hotkeys, app/window/audio automation, Hammerspoon permissions, and any raw code execution.
- `hammerspoonbridge` owns only exported Hammerspoon status rows, predeclared command metadata, explicit handoff/open/copy actions, and optional predeclared URL triggers.

Do not add a Lua editor, Spoon installer, generic `hs` command runner, arbitrary `hs -c` evaluator, Hammerspoon config mutator, hotkey registrar, polling daemon, second script runner, or second plugin registry. Implement as one `BlockRuntime` using `Block.Context.storageDirectory` and `Block.Context.now`.

## Product Boundary

It should:

- Read a Hammerspoon-exported bridge file.
- Show Hammerspoon app/config/IPC status when exported.
- Show predeclared command rows with labels, categories, hotkeys, last run, and state.
- Show exported status rows such as `enabled`, `warning`, `error`, or `stale`.
- Copy command labels, hotkeys, and trigger URLs.
- Open Hammerspoon config, docs, or command URLs when explicitly selected.
- Optionally invoke predeclared `hammerspoon://...` URLs from the manifest.
- Show stale/missing bridge file state.

It should not:

- Evaluate Lua strings.
- Call `hs -c` with arbitrary code.
- Install or update Spoons.
- Edit `~/.hammerspoon/init.lua`.
- Register Surface-owned global hotkeys for Hammerspoon commands.
- Inspect every Hammerspoon module or config file.
- Duplicate `scriptoutput` by running scripts on intervals.
- Duplicate `windowlayouts`, `mediacontrols`, or `contextcard` with parallel native implementations.
- Request Accessibility/Input Monitoring on behalf of Hammerspoon.

## First Version

### Data Modes

Fixture mode:

1. Read `Block.Context.storageDirectory/hammerspoonbridge-state.json`.
2. Use `Block.Context.now` for stale labels.
3. Do not call Hammerspoon, `hs`, `osascript`, or URL handlers.
4. Mutating/invoking actions are preview no-ops.

Live mode:

1. Read `~/Library/Application Support/Surface/HammerspoonBridge/hammerspoonbridge-state.json` by default.
2. Allow a user-configured bridge file path later, but keep it one file in v1.
3. Optionally open predeclared URLs through `NSWorkspace.open(_:)` only when `Block.Context.allowsExternalWrites` is true.
4. Do not run `hs` commands from the block runtime in v1.

External writer:

- Hammerspoon config should write the bridge file with `hs.json.write`.
- Hammerspoon should own `hs.urlevent.bind` handlers for any predeclared command URL.
- Hammerspoon should own `hs.ipc`/`hs` CLI setup if the user wants it; Surface should only display exported CLI status.

### Hammerspoon Export Contract

Surface expects Hammerspoon to export one JSON file:

```lua
local json = require("hs.json")

json.write({
  version = 1,
  exportedAt = os.date("!%Y-%m-%dT%H:%M:%SZ"),
  hammerspoon = {
    running = true,
    configPath = os.getenv("HOME") .. "/.hammerspoon/init.lua",
    ipcEnabled = true
  },
  commands = {
    {
      id = "reload-config",
      title = "Reload config",
      category = "System",
      hotkey = "cmd+alt+ctrl+r",
      triggerURL = "hammerspoon://surface/reload-config",
      state = "ready",
      lastRunAt = nil,
      note = "Runs Hammerspoon's own reload handler."
    }
  },
  statuses = {
    {
      id = "window-grid",
      title = "Window grid",
      state = "ok",
      detail = "12 shortcuts loaded",
      updatedAt = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }
  }
}, os.getenv("HOME") .. "/Library/Application Support/Surface/HammerspoonBridge/hammerspoonbridge-state.json", true, true)
```

Surface should document this as an example only. It should not write the user's Hammerspoon config.

### Local Data Model

```swift
struct HammerspoonBridgeState: Codable, Equatable {
    var version: Int
    var exportedAt: Date
    var hammerspoon: HammerspoonAppState
    var commands: [HammerspoonCommand]
    var statuses: [HammerspoonStatus]
}

struct HammerspoonAppState: Codable, Equatable {
    var running: Bool
    var configPath: String?
    var ipcEnabled: Bool?
    var cliPath: String?
    var note: String?
}

struct HammerspoonCommand: Codable, Identifiable, Equatable {
    var id: String
    var title: String
    var category: String?
    var hotkey: String?
    var triggerURL: URL?
    var state: HammerspoonCommandState
    var lastRunAt: Date?
    var note: String?
}

enum HammerspoonCommandState: String, Codable {
    case ready
    case disabled
    case unavailable
    case warning
}

struct HammerspoonStatus: Codable, Identifiable, Equatable {
    var id: String
    var title: String
    var state: HammerspoonStatusState
    var detail: String?
    var updatedAt: Date
}

enum HammerspoonStatusState: String, Codable {
    case ok
    case warning
    case error
    case stale
}
```

### Display Rules

Header:

- `Hammerspoon`
- status pill: `ready`, `stale`, `missing`, or `blocked`
- command count and warning count

Command rows:

- title
- category
- hotkey
- state pill
- last run age if exported
- icon actions: open trigger URL, copy URL, copy hotkey, copy title

Status rows:

- title
- state
- detail
- updated age

Sort rows:

1. warnings/errors
2. ready commands
3. disabled/unavailable commands
4. statuses by updated time

Stale policy:

- If `exportedAt` is older than 10 minutes, mark the bridge stale.
- If a status row is older than 30 minutes, mark that row stale unless it already has an error state.
- Use `Block.Context.now` for all stale/age labels.

### Actions

- Open predeclared `triggerURL`.
- Copy trigger URL.
- Copy command title/hotkey.
- Copy bridge summary Markdown.
- Open Hammerspoon config path.
- Open Hammerspoon docs.
- Reveal bridge JSON.

No action should evaluate Lua, run `hs -c`, mutate config, install a Spoon, register hotkeys, or scan arbitrary Hammerspoon files.

## UI Shape

Top region:

- Hammerspoon status and bridge age
- small row for config path and IPC state

Main list:

- command rows first when actionable
- status rows below
- fixed-size icon buttons for trigger/open/copy/reveal

Empty/missing state:

- `No bridge file`
- show expected file path
- copy example export snippet
- open Hammerspoon docs

Blocked state:

- `Live triggers disabled` in previews/tests or when external writes are not allowed.
- Still allow copy/reveal actions where safe.

## Runtime Shape

Target: `plugins/hammerspoonbridge/source/Plugin.swift`

Runtime:

1. `start()`: load bridge file.
2. `refresh()`: reload bridge file, recompute stale states against `Block.Context.now`.
3. `stop()`: no-op.
4. `makeView()`: render status, commands, blocked/missing states, and explicit actions.

Use plugin-local JSON helpers first. If later bridge blocks share status-file patterns, factor a tiny read-only manifest helper after implementation.

## Fixture Plan

Fixtures:

- `missing`: no bridge file.
- `ready-commands`: active commands with hotkeys and trigger URLs.
- `stale-export`: old `exportedAt` and stale status rows.
- `warnings`: command/status warnings and unavailable commands.
- `trigger-disabled`: ready commands but live triggers blocked in fixture mode.

Example file:

```json
{
  "version": 1,
  "exportedAt": "2026-06-21T23:42:22Z",
  "hammerspoon": {
    "running": true,
    "configPath": "/Users/example/.hammerspoon/init.lua",
    "ipcEnabled": true,
    "cliPath": "/usr/local/bin/hs",
    "note": "Surface bridge loaded"
  },
  "commands": [
    {
      "id": "reload-config",
      "title": "Reload config",
      "category": "System",
      "hotkey": "cmd+alt+ctrl+r",
      "triggerURL": "hammerspoon://surface/reload-config",
      "state": "ready",
      "lastRunAt": null,
      "note": "Hammerspoon-owned reload"
    }
  ],
  "statuses": [
    {
      "id": "window-grid",
      "title": "Window grid",
      "state": "ok",
      "detail": "12 shortcuts loaded",
      "updatedAt": "2026-06-21T23:40:00Z"
    }
  ]
}
```

## Test Plan

- Missing file renders setup state.
- Bridge JSON decodes and invalid rows are reported without crashing.
- Stale bridge and stale status rows use `Block.Context.now`.
- Commands without trigger URLs render copy-only.
- Fixture mode disables trigger actions.
- Open-trigger action only opens a URL that came from a decoded command row.
- Summary Markdown is deterministic.
- No test path runs `hs`, `osascript`, shell commands, or Lua evaluation.
- Preview fixtures render nonblank PNGs through `Blocks.registry`.

## Recommendation

Implement only as a read-mostly bridge. If users want arbitrary Hammerspoon evaluation, they should use Hammerspoon, its console, or an explicit `scriptoutput` command they own. Surface should be the glanceable control surface over a tiny exported manifest, not the automation runtime.
