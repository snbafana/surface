# Surface Overlay Model

Surface is an editable local control surface. The core object is a block layout, not a plugin system.

## v0a: Blocks

The minimum model is:

- `Block`: a possible block type, such as quicksave, copy history, or codex log.
- `Block.Instance`: the singleton placement of that block in a layout.
- `BlockRuntime`: the live object backing an enabled block.
- `Workspace`: the available blocks plus the active layout.

Rules:

- A block type can appear at most once in a layout.
- A block can be enabled or disabled.
- Disabled blocks stay in the layout model so their placement can survive toggling.
- Unknown block ids are invalid.

## v0b: Layout

The layout model uses a simple integer grid:

- `Grid`: column and row count.
- `GridFrame`: block origin plus size in grid units.
- Movement is snapped by writing integer grid coordinates.
- Movement is clamped inside the grid.
- Persistence stores `Layout` as plain JSON through `Store`.

This is intentionally enough for the first visual editor and no more.

## v0c: Block Registry

Surface does not have a separate plugin/provider layer. A block type is the unit of extension.

`plugins/Blocks.swift` maps block ids to executable block implementations. Plugin folders are packaging boundaries that contribute blocks:

- `Block`: catalog/layout metadata plus a runtime factory.
- `BlockRuntime`: start, stop, refresh, and SwiftUI view behavior for a live block.
- `BlockRegistry`: the active directory of available block types.

The workspace and layout only store block ids, enabled state, and frames. The registry supplies the UI and runtime behavior for each known block id.
