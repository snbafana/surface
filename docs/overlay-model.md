# Surface Overlay Model

Surface is an editable local control surface. The core object is a block layout, not a plugin system.

## Current Shape

The shipped app is assembled from four owners:

- `Sources/Core`: stable model types for block ids, layout frames, runtime protocol, context, registry validation, and JSON layout encoding.
- `Sources/App`: macOS app lifecycle, menu-bar item, global hotkeys, overlay panel, running runtime cache, generated block registry UI, and grid editing UI.
- `plugins/`: SwiftPM plugin targets plus `plugins/Blocks.swift`, which imports plugin targets and builds the active block registry.
- `tools/block-preview`: deterministic screenshot renderer for blocks and the whole default Surface layout.

There is no second provider layer. A plugin folder is a packaging boundary; the registered `Block` is the product.

## Blocks

The minimum model is:

- `Block`: a possible block type, such as quicksave, copy history, codex log, activity context, follow-up queue, GitHub queue, or integration hub.
- `Block.Instance`: the singleton placement of that block in a layout.
- `BlockRuntime`: the live object backing an enabled block.
- `Workspace`: the available blocks plus the active layout.
- `Block.Context`: app services and deterministic preview/test inputs passed into a runtime factory.

Rules:

- A block type can appear at most once in a layout.
- A block can be enabled or disabled.
- Disabled blocks stay in the layout model so their placement can survive toggling.
- Unknown block ids are invalid.
- The layout stores ids, enabled state, and frames only. Runtime objects, SwiftUI views, hotkey tokens, process readers, and filesystem readers are recreated from the registry.

## Runtime Path

The real app path is:

1. `Surface` is initialized with `Blocks.registry`.
2. `SurfaceLayout.workspace(registry:)` builds a `Workspace` from the default layout.
3. `RunningBlocks.sync(with:)` compares enabled layout instances with cached runtimes.
4. Missing enabled runtimes are created with `block.makeRuntime(context)`.
5. Created runtimes get `start()` exactly once.
6. Disabled runtimes get `stop()` and are removed from the cache.
7. `SurfaceView` renders each enabled block through `surface.runningBlocks.view(for:)`.
8. `RunningBlocks.view(for:)` calls `runtime.makeView()` and wraps missing runtimes in a placeholder.

Edit mode uses the same `Workspace.blocks` collection to render the Block Registry. It should stay generated from the registry-backed workspace instead of drifting into a separate hard-coded plugin list.

Block runtimes should treat lifecycle methods as ownership boundaries:

- `start()`: register hotkeys, begin watching, and load initial state.
- `stop()`: unregister hotkeys, stop watchers, close handles, and leave the runtime reusable only if it is started again.
- `refresh()`: perform cheap reloads that are safe when the overlay opens.
- `makeView()`: return the real SwiftUI view for the runtime state.

## Context

`Block.Context` is how app and preview code share the same runtime path without live side effects:

- `keyboardShortcuts`: the app's global shortcut registrar. Plugins should use this instead of calling Carbon directly unless they are implementing the registrar itself.
- `storageDirectory`: an override root for fixture/test files. When this is `nil`, a runtime may use its normal user data location.
- `now`: deterministic clock input for tests and previews.
- `allowsLiveProcesses`: disables live process scans in previews/tests.
- `allowsExternalWrites`: disables writes outside the fixture directory in previews/tests.

If a block cannot preview deterministically, prefer adding a narrow context input over creating a preview-only UI.

Live command-backed blocks should avoid blocking app launch. If a runtime needs Coast, Cued, GitHub CLI, or another local process, load fixture data synchronously when `Block.Context.storageDirectory` is set, but schedule live reads in a runtime-owned background task when `Block.Context.allowsLiveProcesses` is true.

## Layout

The layout model uses a simple integer grid:

- `Grid`: column and row count.
- `GridFrame`: block origin plus size in grid units.
- Movement is snapped by writing integer grid coordinates.
- Movement is clamped inside the grid.
- Persistence stores `Layout` as plain JSON through `Store`.

This is intentionally enough for the first visual editor and no more.

`SurfaceLayout.defaultLayout` currently owns the default 24-by-17 grid and the default placements for `quicksave`, `copyhistory`, `activitycontext`, `githubqueue`, `followupqueue`, `integrationhub`, and `codexlog`.

## Block Registry

`plugins/Blocks.swift` maps block ids to executable block implementations. Plugin folders are packaging boundaries that contribute blocks:

- `Block`: catalog/layout metadata plus a runtime factory.
- `BlockRuntime`: start, stop, refresh, and SwiftUI view behavior for a live block.
- `BlockRegistry`: the active directory of available block types.

The workspace and layout only store block ids, enabled state, and frames. The registry supplies the UI and runtime behavior for each known block id.

`BlockRegistry` validates that block ids are unique. `Workspace.validate()` then checks that layout ids exist, layout ids are not duplicated, frames stay in the grid, and enabled frames do not overlap.

The human-facing registry table in `README.md` mirrors `plugins/Blocks.swift`. It is documentation, not a second source of truth.

## Add a Block

When adding a plugin, reuse the real registry and runtime path:

1. Create `plugins/<id>/source`.
2. Add a SwiftPM target for the plugin and make the `Blocks` target depend on it.
3. Expose a public `Plugin.block`:

   ```swift
   import Core

   public enum Plugin {
       public static let block = Block(
           id: "example",
           title: "Example",
           defaultSize: GridSize(width: 8, height: 6)
       ) { context in
           Runtime(context: context)
       }
   }
   ```

4. Implement `Runtime: BlockRuntime` in that target.
5. Register the block in `plugins/Blocks.swift`.
6. Add the block to `SurfaceLayout.defaultLayout` only if it should be enabled by default.
7. Add plugin tests under `plugins/<id>/tests`.
8. Add preview fixture coverage in `tools/block-preview/support/BlockPreviewSupport.swift`.

Avoid these parallel systems:

- A separate plugin registry.
- A preview-only SwiftUI implementation.
- A second hotkey manager inside a plugin.
- Persisting runtime state inside `Layout`.
- Adding wrappers around `BlockRuntime` before there are multiple real implementations that need them.

## Preview Harness

`BlockPreview.render(...)` uses the same runtime contract as the app:

1. Look up the block in `Blocks.registry`.
2. Build a deterministic fixture directory.
3. Create the runtime with `Block.Context(storageDirectory:now:allowsLiveProcesses:allowsExternalWrites:)`.
4. Call `runtime.start()`.
5. Render `runtime.makeView()` inside `BlockChrome`.
6. Call `runtime.stop()` with `defer`.
7. Write a PNG and measure whether it is visually nonblank.

Commands:

```bash
swift run block-preview list
swift run block-preview quicksave --fixture notes-and-captures --size 420x520
swift run block-preview all --output .build/block-previews
swift run block-preview surface --output .build/block-previews
swift test --filter BlockPreviewTests
```

For a new block, add it to the fixture list, add at least an empty fixture plus a representative populated fixture, and update `BlockPreviewTests.previewCasesCoverEveryCurrentPlugin()`.

## Hotkeys and Permissions

The app-level global shortcut registrar is `KeyboardShortcuts` in `Sources/App/SystemUI.swift`. It uses Carbon `RegisterEventHotKey` and is passed to blocks through `Block.Context(keyboardShortcuts:)`.

Current shortcuts:

- `Option-E`: app overlay toggle, registered in `Sources/App/main.swift`.
- `Option-C`: Quicksave clipboard capture, registered by the Quicksave runtime while the block is enabled.

The app reconnects registered shortcuts on wake, screen wake, session activation, and screen-parameter changes. `KeyboardShortcuts` logs failed `InstallEventHandler` and `RegisterEventHotKey` attempts through the `com.snbafana.Surface` subsystem and stores the latest failure for the menu-bar status row.

Use `./script/build_and_run.sh` for normal UI testing. It stages `dist/Surface.app`, kills stale bundled and project-local raw SwiftPM processes, and opens the bundled app so old hotkey registrations do not survive across manual runs.

Accessibility is not currently part of the hotkey path. The repo does not call `AXIsProcessTrusted`, install event taps, or surface an Accessibility permission state. If future blocks add UI scripting, event taps, or input monitoring, add explicit permission detection and display a block-level error state.
