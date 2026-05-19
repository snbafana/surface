# Surface

Surface is a local, editable Raycast-style overlay for macOS.

The first version is model-first:

```text
Sources/Core   block, layout, and persistence models
Sources/App    AppKit overlay shell, editor UI, and block registry
docs/          architecture notes
tests/         model tests
```

v0 order:

1. Blocks.
2. Layout.
3. Block registry.

Surface does not have a separate plugin/provider layer. A block type is the unit of extension.
