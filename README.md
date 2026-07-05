# Surface

Surface is a local, editable Raycast-style overlay for macOS.

The first version is model-first and block-first:

```text
Sources/Core   block, layout, and persistence models
Sources/App    app entry, Surface state, overlay view, and AppKit system UI
plugins/       installed blocks plus each block's source and tests
tools/         block preview renderer
docs/          architecture notes
tests/         model tests
```

Surface does not have a separate plugin/provider layer. A block type is the unit of extension. The architecture details live in [docs/overlay-model.md](docs/overlay-model.md).

## Quick Start

Clone the repo on macOS, build the SwiftPM package, then launch the local app bundle:

```bash
swift build
./script/build_and_run.sh
```

`./script/build_and_run.sh` writes `dist/Surface.app` and opens it. Use that app bundle for normal local testing because the script also stops stale Surface processes that can hold old global hotkeys.

To test the installed-app path, copy or install `dist/Surface.app` to `/Applications/Surface.app`, then run:

```bash
./script/verify_alt_e.sh --app /Applications/Surface.app
```

## Requirements

- macOS 14 or newer.
- Swift 6 toolchain / Xcode command line tools.

## Build, Run, and Test

```bash
swift build
```

Run the menu-bar app and overlay:

```bash
./script/build_and_run.sh
```

While the app is running:

- `Option-E` toggles the Surface overlay.
- The menu-bar icon can show, edit, hide, and quit Surface.
- `Escape` hides the overlay.
- In edit mode, the Block Registry is generated from the installed blocks; enable/disable blocks there and drag block cards on the grid.
- The Quicksave block registers `Option-C` while it is enabled.
- The Copy History block watches the macOS pasteboard while enabled, stores recent text copies locally, and lets you click an item to copy it back.
- The Activity Context block reads Coast screen-activity summaries when live processes are allowed.
- The Follow Ups block reads local Cued follow-up candidates when live processes are allowed.
- The GitHub Queue block reads current-repo pull requests through `gh pr list` when live processes are allowed.
- The Integration Hub block shows local readiness for agent/workflow CLIs and source-backed integration ideas without running automations or storing credentials.

The run script builds the SwiftPM product, stages `dist/Surface.app`, kills stale project-local raw `App` processes and legacy `Surface.app` processes that can hold old hotkeys, and opens the bundled app. Use this path for normal UI testing instead of repeatedly launching the raw SwiftPM executable.

Extra run modes:

```bash
./script/build_and_run.sh --verify
./script/build_and_run.sh --logs
./script/build_and_run.sh --telemetry
./script/build_and_run.sh --debug
```

Verify the installed `/Applications/Surface.app` Option-E path, including an idle window:

```bash
./script/verify_alt_e.sh
```

Run the full test suite:

```bash
swift test
```

Useful focused checks:

```bash
swift test --filter CoreTests
swift test --filter BlockPreviewTests
swift test --filter QuicksaveTests
swift test --filter CopyHistoryTests
swift test --filter CodexLogTests
swift test --filter ActivityContextTests
swift test --filter FollowUpQueueTests
swift test --filter GitHubQueueTests
swift test --filter IntegrationHubTests
```

## Block Preview Harness

Use the preview harness for plugin UI iteration before relying on the full overlay. The harness renders real block runtimes through `Blocks.registry`, `Block.makeRuntime(...)`, and `BlockRuntime.makeView()`.

List available preview cases:

```bash
swift run block-preview list
```

Render one block with a deterministic fixture:

```bash
swift run block-preview quicksave --fixture notes-and-captures --size 420x520
```

Render every block fixture:

```bash
swift run block-preview all --output .build/block-previews
```

Render the whole default Surface layout:

```bash
swift run block-preview surface --output .build/block-previews
```

Then inspect the PNGs in `.build/block-previews/` and run:

```bash
swift test --filter BlockPreviewTests
```

The expected loop is:

1. Render the single block fixture.
2. Inspect the PNG.
3. Patch the real block view or fixture.
4. Rerender the single block.
5. Render all fixtures and run the preview smoke test.

Do not create a preview-only SwiftUI surface for a block. If a block needs deterministic data, pass it through `Block.Context` and the fixture code in `tools/block-preview/support/BlockPreviewSupport.swift`.

## Plugin and Block System

The extension unit is a `Block`:

- `Core.Block` stores catalog metadata, default size, and a runtime factory.
- `Core.BlockRuntime` owns live behavior: `start()`, `stop()`, `refresh()`, and `makeView()`.
- `Core.Block.Context` passes app services and deterministic test/preview inputs such as `keyboardShortcuts`, `storageDirectory`, `now`, `allowsLiveProcesses`, and `allowsExternalWrites`.
- `plugins/Blocks.swift` builds the active `Blocks.registry`.
- `Sources/App/Surface.swift` creates `RunningBlocks`, starts runtimes for enabled layout instances, stops disabled runtimes, and asks each runtime for its SwiftUI view.
- `Sources/Core/Layout.swift` stores block ids, enabled state, and grid frames. Runtime behavior never lives in persisted layout JSON.

Current plugin targets are `Quicksave`, `CopyHistory`, `CodexLog`, `ActivityContext`, `FollowUpQueue`, `GitHubQueue`, and `IntegrationHub`. Each exposes `Plugin.block` from its `plugins/<name>/source` directory. `CopyHistory` uses the same runtime contract as the other blocks: previews load `copyhistory.txt` from `Block.Context.storageDirectory`, while the live app watches `NSPasteboard.general` and persists history under Application Support.

Context-aware blocks follow the same contract. Previews read deterministic fixture files from `Block.Context.storageDirectory`, while live adapters are guarded by `Block.Context.allowsLiveProcesses`. Live Coast, Cued, and GitHub CLI reads run in plugin-owned background tasks so app launch and global shortcut registration stay responsive. Integration Hub is intentionally lighter: it checks executable availability and environment readiness, then copies commands or opens source docs from explicit row actions.

## Installed Block Registry

This table mirrors the block registry in `plugins/Blocks.swift`. Treat the Swift registry as the source of truth; update this table when adding, removing, or renaming a block.

| Block ID | Title | Target | Owner Path | Block Default | Initial Layout | Live Dependencies | Preview Fixtures | Boundary |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `quicksave` | Quicksave | `Quicksave` | `plugins/quicksave` | `10x5` | `8x5` | macOS pasteboard and `Option-C` hotkey through `Block.Context.keyboardShortcuts` | `empty`, `notes-and-captures` | Captures clipboard/notes into local files and optional Obsidian paths; does not own Copy History. |
| `copyhistory` | Copy History | `CopyHistory` | `plugins/copyhistory` | `8x8` | `7x6` | macOS pasteboard; Application Support history file | `empty`, `mixed-clipboard` | Stores recent text copies and copy-back actions; no rule engine or cross-plugin clipboard router. |
| `codexlog` | Codex Log | `CodexLog` | `plugins/codexlog` | `8x10` | `7x8` | Local Codex state, session files, action log, and optional process scan | `empty`, `active-thread` | Shows Codex threads/actions and approval rows; remains the generic action-log owner. |
| `activitycontext` | Activity Context | `ActivityContext` | `plugins/activitycontext` | `7x6` | `7x6` | Optional `coast` CLI via `Core.LocalCommand` | `empty`, `work-session` | Shows bounded current/recent screen context; not a timeline browser or OCR search UI. |
| `followupqueue` | Follow Ups | `FollowUpQueue` | `plugins/followupqueue` | `8x5` | `8x5` | Optional `cued` CLI via `Core.LocalCommand` | `empty`, `mixed-followups` | Shows local follow-up candidates; does not send messages or duplicate Cued's contact graph. |
| `githubqueue` | GitHub Queue | `GitHubQueue` | `plugins/githubqueue` | `8x5` | `8x5` | Optional `gh` CLI via `Core.LocalCommand` | `empty`, `mixed-prs` | Shows current-repo PR cards and copy/open actions; not a full GitHub client. |
| `integrationhub` | Integration Hub | `IntegrationHub` | `plugins/integrationhub` | `10x4` | `16x5` | Optional CLI/env checks for `browse`, `bb`, `coast`, `cued`, `gh`, and selected agent tools | `empty`, `mixed-integrations` | Readiness/source cards only; no credential store, installer, automation runner, network crawler, or second registry. |

External integrations are optional. Missing CLIs should produce visible empty or unavailable states, not startup failure. Blocks that read local command output use `Core.LocalCommand` so executable lookup and process execution stay centralized.

## Add a Plugin

Use the existing block path instead of adding a second plugin manager.

1. Add the plugin target under `plugins/<id>/source`.
2. Expose `public enum Plugin { public static let block = Block(...) }`.
3. Implement a runtime that conforms to `BlockRuntime`.
4. Put side effects in `start()`, undo them in `stop()`, reload cheap state from `refresh()`, and return the real SwiftUI UI from `makeView()`.
5. Use `Block.Context` for app services and preview/test determinism. For example, register hotkeys through `context.keyboardShortcuts`, read fixture files from `context.storageDirectory`, and disable process scans or external writes when the context flags say so.
6. Register the block in `plugins/Blocks.swift` and wire the SwiftPM target/dependencies in `Package.swift`.
7. Add focused plugin tests under `plugins/<id>/tests`.
8. Add preview fixtures in `tools/block-preview/support/BlockPreviewSupport.swift`, then update `BlockPreviewTests` coverage.
9. If the block should appear by default, add a `Block.Instance` to `SurfaceLayout.defaultLayout`.
10. Validate with `swift test --filter <PluginTests>`, the single-block preview command, `swift run block-preview all --output .build/block-previews`, and `swift test --filter BlockPreviewTests`.

## Global Hotkey and Accessibility Troubleshooting

The app currently uses Carbon `RegisterEventHotKey`, not an Accessibility event tap:

- Overlay toggle: `Option-E` in `Sources/App/main.swift`.
- Quicksave capture: `Option-C` in `plugins/quicksave/source/Runtime.swift`.
- Registration failures are logged through the `com.snbafana.Surface` subsystem and surfaced in the menu-bar menu as a shortcut issue.

If hotkeys stop working:

1. Relaunch with `./script/build_and_run.sh`; it kills the bundled app, stale project-local raw `App` processes, and legacy `Surface.app` processes before opening `dist/Surface.app`.
2. Check that the Surface menu-bar icon is present; if it is not, the app is not running.
3. Open the menu-bar menu and look for a `Shortcut issue:` row.
4. Wake/screen changes should trigger `reconnectRegisteredShortcuts()`, but relaunch if a shortcut disappears after display changes.
5. Run `./script/verify_alt_e.sh --idle-seconds 130` to relaunch the installed app, press Option-E before and after the idle window, and write logs plus a screenshot under `.build/surface-status`.
6. Check macOS keyboard shortcut conflicts for `Option-E` or `Option-C`.

The current code does not call `AXIsProcessTrusted` or request Accessibility permission. If macOS permission prompts appear while testing future UI automation, grant permission to the launched app or to Terminal when using raw executable debugging. If a future block uses event taps, UI scripting, or input monitoring APIs, add an explicit permission check and a visible failure state rather than assuming Carbon hotkey behavior covers it.
