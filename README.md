# Surface

Surface is a local, editable Raycast-style overlay for macOS.

The first version is model-first:

```text
Sources/Core      block, layout, persistence, and future provider descriptors
Sources/App       a minimal preview shell
Sources/Plugins   reserved for built-in providers after block/layout validation
plugins/             reserved for external manifests and scripts
docs/                architecture notes
tests/               model tests
```

v0 order:

1. Blocks.
2. Layout.
3. Plugin boundary.

Plugins are intentionally not implemented until blocks and layout are working.
