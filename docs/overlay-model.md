# Surface Overlay Model

Surface is an editable local control surface. The core object is a block layout, not a plugin system.

## v0a: Blocks

The minimum model is:

- `BlockDefinition`: a possible block type, such as command, captures, status, or daily note.
- `BlockInstance`: the singleton instance of that block type in a layout.
- `Workspace`: the available block definitions plus the active layout.

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
- Persistence is plain JSON through `Store`.

This is intentionally enough for the first visual editor and no more.

## v0c: Block Registry

Surface does not have a separate plugin/provider layer. A block type is the unit of extension.

The app registry maps block ids to executable block implementations:

- `BlockDefinition`: catalog/layout metadata for a block type.
- `BlockType`: app-side rendering, action, cached-state, and refresh hooks for a block type.
- `BlockRegistry`: the active directory of available block types.

The workspace and layout only store block ids, enabled state, and frames. The registry supplies the UI and runtime behavior for each known block id.
