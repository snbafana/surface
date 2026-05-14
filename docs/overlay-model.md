# Surface Overlay Model

Surface is an editable local control surface. The core object is a block layout, not a plugin system.

## v0a: Blocks

The minimum model is:

- `BlockDefinition`: a possible block type, such as command, captures, status, or daily note.
- `BlockInstance`: the singleton instance of that block type in a layout.
- `SurfaceDocument`: the available block definitions plus the active layout.

Rules:

- A block type can appear at most once in a layout.
- A block can be enabled or disabled.
- Disabled blocks stay in the layout model so their placement can survive toggling.
- Unknown block ids are invalid.

## v0b: Layout

The layout model uses a simple integer grid:

- `SurfaceGrid`: column and row count.
- `GridFrame`: block origin plus size in grid units.
- Movement is snapped by writing integer grid coordinates.
- Movement is clamped inside the grid.
- Persistence is plain JSON through `SurfaceStore`.

This is intentionally enough for the first visual editor and no more.

## v0c: Plugin Boundary

Plugins are not implemented in v0. The only plugin-facing model is a descriptor:

- `SurfaceProviderDescriptor`: names a future provider and the block ids it owns.
- `SurfaceCatalog`: a list of descriptors and block definitions.

This keeps the host editable before hook execution exists.
