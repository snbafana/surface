# `previewgallery` Plugin Spec

## Decision

Build `previewgallery` as one read-only `BlockRuntime` that displays existing block-preview PNG outputs and their metadata. It should make the current visual fixture set easy to inspect without running previews, replacing the block-preview harness, becoming a screenshot manager, or introducing a visual-regression system.

Use the existing `Block` / `BlockRuntime` / `Block.Context` path. The block may read PNG files, optional index JSON, and optional result/status JSON. It must not render, regenerate, compare, overwrite, upload, or delete preview images.

## Existing Owner / Dedup Decision

- `tools/block-preview/support/BlockPreviewSupport.swift` owns rendering previews through `Blocks.registry`, `Block.Context`, and the real `BlockRuntime.makeView()` path.
- `tools/block-preview/source/main.swift` owns the `block-preview` CLI commands and printed metrics.
- `tests/BlockPreviewTests/BlockPreviewTests.swift` owns fixture coverage and nonblank preview assertions.
- `registryhealth` owns registry/package/test/fixture health reporting.
- `localbuildstatus` owns last build/test/preview run status.
- `diagnosticbundle` owns support export of selected PNG artifacts.
- `fileinbox` owns broad file scanning and file triage.
- `previewgallery` owns only preview-image indexing, thumbnail display, metadata display, open/reveal/copy actions, and copied render commands.

If implementation needs fresh preview images, route that to the existing `block-preview` CLI or an external runner. Do not make `previewgallery` run the renderer.

## Product Boundary

It should:

- Read optional `previewgallery-index.json` from `Block.Context.storageDirectory` in previews/tests or Application Support in live mode.
- Read PNG files from a configured preview output directory, defaulting to `.build/block-previews` when a repo root is configured.
- Parse known preview filenames such as `<block-id>-<fixture>.png` and `surface-active.png`.
- Show block id, fixture, image dimensions, byte size, modified age, optional metrics, and optional last-render status.
- Use `Block.Context.now` for stale labels.
- Let the user open, reveal, copy path, copy Markdown image link, copy render command, and copy a gallery summary.
- Show missing/stale/unknown image states without failing the whole block.

It should not:

- Run `swift run block-preview`, `swift test`, `git`, shell commands, image optimizers, screenshot tools, or external CLIs.
- Render previews, call `BlockPreview.render`, instantiate plugin runtimes, or create a preview-only UI path.
- Create, overwrite, delete, rename, move, compress, upload, or export PNG files.
- Take screenshots of the desktop or other apps.
- Read arbitrary screenshot folders, Desktop, Downloads, Photos, browser caches, or user image libraries.
- Implement visual baselines, pixel diffs, approval workflows, or snapshot updates in v1.
- Duplicate `registryhealth` coverage checks, `localbuildstatus` run history, `diagnosticbundle` export, or `fileinbox` scanning.
- Add a second registry or preview fixture registry.

## First Version

### Data Modes

Fixture mode:

1. Read `Block.Context.storageDirectory/previewgallery-index.json` if present.
2. Read only PNG files under `Block.Context.storageDirectory/previews`.
3. Do not open files, run commands, scan live paths, or read `.build`.

Live mode:

1. Read `~/Library/Application Support/Surface/PreviewGallery/previewgallery-index.json` if present.
2. Use `repoRoot + outputDirectory` from the index, or a host-configured repo root plus `.build/block-previews`.
3. Enumerate only the configured output directory, non-recursively, and include only `.png` files whose names match known preview patterns or explicit index entries.
4. Load image dimensions using AppKit/ImageIO APIs and file metadata using `FileManager`.
5. Open/reveal only from explicit user actions and only when external actions are allowed.

### Index File

```json
{
  "version": 1,
  "title": "Surface Preview Gallery",
  "repoRoot": "/Users/example/projects/surface",
  "outputDirectory": ".build/block-previews",
  "staleAfterHours": 24,
  "entries": [
    {
      "id": "quicksave-notes-and-captures",
      "kind": "block",
      "blockID": "quicksave",
      "fixture": "notes-and-captures",
      "path": ".build/block-previews/quicksave-notes-and-captures.png",
      "renderCommand": "swift run block-preview quicksave --fixture notes-and-captures --size 420x520",
      "metrics": {
        "width": 600,
        "height": 281,
        "byteCount": 31518,
        "distinctSampledColors": 55,
        "nonBackgroundSampleCount": 102
      },
      "renderedAt": "2026-06-24T04:42:52Z",
      "status": "passed"
    }
  ]
}
```

Allowed `kind` values:

- `block`
- `surface`
- `unknown`

Allowed `status` values:

- `passed`
- `failed`
- `unknown`
- `missing`
- `stale`

The index is optional. Without it, the block should infer id/fixture/path from file names and mark status as `unknown`.

## Display

Header:

- `Previews`
- image count
- stale/missing count
- output directory age

Rows/cards:

- thumbnail
- block id or `surface`
- fixture name
- dimensions
- byte size
- modified age
- status chip
- optional metrics line: colors and nonbackground samples
- fixed icon buttons: open, reveal, copy path, copy Markdown image link, copy render command

Sections:

- Surface
- Current Blocks
- Stale or Missing
- Unknown Files

Use stable thumbnail sizes so image loading does not resize the gallery layout.

## Actions

- Open image file.
- Reveal image file.
- Copy absolute path.
- Copy repo-relative path.
- Copy Markdown image link.
- Copy single render command.
- Copy all render commands from the visible gallery.
- Copy gallery summary as Markdown.

No action should render previews, run commands, write files, export images, update baselines, or approve visual diffs.

## Source Evidence

- Surface's README and AGENTS instructions already require inspecting `.build/block-previews` PNGs after running the real block-preview harness. `previewgallery` should make that inspection easier, not replace the loop.
- `BlockPreview.renderAll` writes block fixture PNGs to `.build/block-previews` through `Blocks.registry`, `Block.Context`, and real runtime views.
- `BlockPreview.renderSurface` writes `surface-active.png` using the default layout and real block runtimes.
- `BlockPreviewMetricsReader` already reads PNG dimensions, byte count, sampled color count, and nonbackground sample count for smoke tests.
- `BlockPreviewTests` already enforce fixture coverage and nonblank PNG metrics; the gallery should display this state but not enforce it.
- Apple `NSImage(contentsOf:)` and ImageIO thumbnail APIs support local image loading/thumbnail generation without shell tools.
- Apple Quick Look Thumbnailing validates local thumbnail generation for common file types, but PNG thumbnails are enough for v1.
- Storybook and Playwright visual testing docs validate image snapshots as a useful UI review artifact, while their baseline/diff/update workflows should stay outside `previewgallery` v1.
- GitHub Actions artifact upload validates that generated screenshots are often treated as artifacts, but upload/export belongs to `diagnosticbundle` or CI, not this gallery.

## Preview Fixtures

Use `Block.Context.storageDirectory`.

- `empty`: no index and no preview directory.
- `current-previews`: block previews and `surface-active.png` with fresh metadata.
- `stale-previews`: previews older than `staleAfterHours`.
- `missing-indexed`: index rows whose files are missing.
- `failed-metrics`: metadata reports failed/nonblank status.
- `unknown-files`: extra PNG files that do not match known preview names.
- `read-only`: previews visible with open/reveal actions disabled by context.

## Tests

- Decode a valid index file.
- Infer block id/fixture from known PNG filenames when no index exists.
- Treat `surface-active.png` as a surface preview.
- Reject path traversal and ignore non-PNG files.
- Classify fresh, stale, missing, failed, and unknown entries.
- Load PNG dimensions/byte size deterministically from fixture files.
- Produce copyable render commands without executing them.
- Keep open/reveal actions disabled when external actions are not allowed.
- Verify the runtime never calls block rendering APIs, shell commands, screenshot APIs, or file mutation APIs.
- Add preview coverage for every fixture and include `previewgallery` in `BlockPreviewTests`.

## Implementation Notes

- Start with a plugin-local Codable model and a tiny filename parser.
- Use `NSImage(contentsOf:)` or ImageIO for dimensions/thumbnails; do not add a screenshot/image-processing dependency.
- Keep gallery scanning non-recursive and bounded to the configured output directory.
- Prefer optional metadata written by the preview runner over duplicating nonblank threshold logic.
- If baseline/diff support becomes important, spec it as a block-preview/test-harness feature first.
