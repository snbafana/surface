# `plugintemplates` Plugin Spec

## Decision

Build `plugintemplates` as one read-only, copy-oriented authoring reference `BlockRuntime`. It should help a human or coding agent follow the existing Surface plugin path by showing small pattern cards, copyable snippets, example files, and checklists. It must not become a scaffolder, generator, package editor, registry editor, or second plugin system.

Use the existing `Block` / `BlockRuntime` / `Block.Context` path. The block may copy snippets and open example files; it must not create plugin directories or write source files.

## Existing Owner / Dedup Decision

- `README.md` owns the canonical add-a-plugin checklist and validation commands.
- `AGENTS.md` owns the preview-harness iteration loop.
- `Package.swift` owns target and test-target wiring.
- `plugins/Blocks.swift` owns the active registry.
- `tools/block-preview/support/BlockPreviewSupport.swift` owns preview fixture registration and real-runtime rendering.
- `tests/BlockPreviewTests/BlockPreviewTests.swift` owns preview coverage enforcement.
- Existing plugins own concrete examples: `quicksave` for split runtime/view/filesystem helpers, `copyhistory` for compact inline runtime/view/pasteboard behavior, and `codexlog` for multi-file read-only status plus action rows.
- `readmehub` owns documentation indexing.
- `registryhealth` owns generated registry/package/test/fixture health display.
- `scriptoutput` owns command execution.
- `plugintemplates` owns only curated authoring patterns and copyable snippets/checklists.

If implementation discovers that this is mostly docs navigation, fold the shared parts into `readmehub` rather than adding another docs index. Keep `plugintemplates` distinct only for code-pattern cards and snippet copying.

## Product Boundary

It should:

- Read optional `plugintemplates-catalog.json` from `Block.Context.storageDirectory` in previews/tests or Application Support in live mode.
- Provide a small plugin-local default catalog when no file is present.
- Show pattern cards for minimal block, file-backed block, live-process-gated block, action-row/status block, preview fixture, focused tests, package/registry wiring, and plugin README outline.
- Link each pattern to existing local examples and owner files.
- Let the user copy snippets, copy checklists, open example files, reveal example files, and copy validation commands.
- Use `Block.Context.now` for catalog/example stale labels if timestamps are present.

It should not:

- Create `plugins/<id>/source`, test folders, fixture folders, README files, or spec files.
- Modify `Package.swift`, `plugins/Blocks.swift`, `SurfaceLayout.defaultLayout`, `BlockPreviewSupport.swift`, or `BlockPreviewTests.swift`.
- Run `swift`, `git`, `npm`, `yo`, Raycast commands, editor CLIs, or shell commands.
- Generate a plugin manifest, registry entry, Package target, preview fixture, test file, or README.
- Parse arbitrary Swift ASTs or scan the whole repository.
- Duplicate `readmehub` docs indexing, `registryhealth` wiring checks, or `scriptoutput` command execution.
- Maintain a template marketplace, remote template fetcher, or template repository sync flow.

## First Version

### Data Modes

Fixture mode:

1. Read `Block.Context.storageDirectory/plugintemplates-catalog.json` if present.
2. Use fixture example paths and fixture timestamps only.
3. Do not open files, run commands, or scan the live repo.

Live mode:

1. Load plugin-local default templates.
2. Optionally merge `~/Library/Application Support/Surface/PluginTemplates/plugintemplates-catalog.json`.
3. Read metadata for explicitly configured example paths only.
4. Open/reveal examples only from explicit user actions and only when external actions are allowed.

### Catalog File

```json
{
  "version": 1,
  "title": "Surface Plugin Templates",
  "patterns": [
    {
      "id": "minimal-block",
      "title": "Minimal Block",
      "stage": "source",
      "summary": "Expose Plugin.block and return a BlockRuntime from Block.Context.",
      "examplePaths": ["plugins/quicksave/source/Plugin.swift"],
      "snippets": [
        {
          "id": "plugin-block",
          "title": "Plugin.block skeleton",
          "language": "swift",
          "body": "import Core\n\npublic enum Plugin {\n    public static let block = Block(\n        id: \"example\",\n        title: \"Example\",\n        defaultSize: GridSize(width: 8, height: 6)\n    ) { context in\n        Runtime(context: context)\n    }\n}\n"
        }
      ],
      "checklist": [
        "Choose a stable lowercase block id.",
        "Expose public enum Plugin with static block.",
        "Keep runtime behavior inside BlockRuntime."
      ]
    }
  ]
}
```

Allowed `stage` values:

- `source`
- `runtime`
- `view`
- `data`
- `tests`
- `preview`
- `wiring`
- `docs`

### Default Pattern Set

- `minimal-block`: `Plugin.block`, `BlockID`, title, default size, runtime factory.
- `runtime-lifecycle`: `start()`, `stop()`, `refresh()`, `makeView()`, and side-effect cleanup.
- `context-gates`: `storageDirectory`, `now`, `allowsLiveProcesses`, and `allowsExternalWrites`.
- `file-backed-state`: fixture/live storage fallback using `Block.Context.storageDirectory`.
- `action-row`: copy/open/reveal/status actions without command execution.
- `focused-tests`: plugin-local tests under `plugins/<id>/tests`.
- `preview-fixtures`: fixture rows in `BlockPreviewSupport` and coverage in `BlockPreviewTests`.
- `package-registry-wiring`: manual Package.swift and `plugins/Blocks.swift` checklist.
- `plugin-readme-outline`: concise plugin-local README sections for contract, fixtures, and dev loop.

## Display

Header:

- `Templates`
- pattern count
- snippet count
- checklist count

Rows/cards:

- pattern title
- stage chip
- short summary
- example file count
- snippet count
- checklist progress when copied/checked locally in memory
- fixed icon buttons: copy snippet, copy checklist, open example, reveal example

Sections:

- Start
- Runtime
- Data and Actions
- Tests and Previews
- Wiring
- Docs

Keep the view compact. This is a reference tray for implementation, not an editor or wizard.

## Actions

- Copy one snippet.
- Copy all snippets for one pattern.
- Copy one checklist.
- Copy the full implementation checklist as Markdown.
- Copy validation commands from the README checklist.
- Open an example source/test/fixture/doc file.
- Reveal an example file in Finder.

No action should create files, edit files, run commands, scaffold plugins, mutate package/registry/layout/preview files, or update external docs.

## Source Evidence

- Surface's README already defines the plugin path: create a target, expose `Plugin.block`, conform to `BlockRuntime`, use `Block.Context`, register in `plugins/Blocks.swift`, wire `Package.swift`, add tests, add preview fixtures, and validate with tests/previews.
- Surface's AGENTS preview loop requires plugin UI iteration through `swift run block-preview ...` and the real `Block` / `BlockRuntime.makeView()` path, so templates should point to the existing preview harness.
- Existing plugin source files provide better local examples than invented scaffolds: `quicksave` is split by owner, `copyhistory` is compact, and `codexlog` demonstrates a larger status/action block.
- Raycast provides command/tool/boilerplate templates and a Create Extension flow, validating the user need for starter patterns. Surface should copy the idea of pattern cards, not Raycast's generator/runtime model.
- VS Code's first-extension guide starts with Yeoman scaffolding and then explains extension anatomy, validating that starters help but also showing why a generator becomes another toolchain owner.
- GitHub template repositories generate whole repositories with copied structure and unrelated histories, which is too coarse for adding one plugin target inside an existing package.
- Swift Package Manager treats targets as explicit package-manifest units, so package wiring should remain a manual/checklist step until `registryhealth` can report it.

## Preview Fixtures

Use `Block.Context.storageDirectory`.

- `empty`: no catalog and no defaults enabled.
- `minimal-authoring`: minimal block, runtime lifecycle, and package/registry checklist.
- `file-backed`: storageDirectory/live storage examples.
- `live-gated`: allowsLiveProcesses/allowsExternalWrites examples.
- `fixtures-and-tests`: preview fixture and focused test patterns.
- `docs-outline`: plugin README and validation command checklist.
- `read-only`: examples visible with open/reveal actions disabled by context.

## Tests

- Decode a valid catalog file.
- Fall back to plugin-local default patterns when no catalog exists.
- Group patterns by stage.
- Copy snippets/checklists without writing files.
- Keep open/reveal actions disabled when external actions are not allowed.
- Ensure no action creates plugin folders, writes Package/registry/fixture/test files, or runs commands.
- Add preview coverage for every fixture and include `plugintemplates` in `BlockPreviewTests`.

## Implementation Notes

- Start with static plugin-local data plus an optional JSON override.
- Keep snippets intentionally small; large files should be opened as examples, not copied wholesale.
- Use local examples first. External template systems are source evidence, not runtime dependencies.
- Do not add a separate template syntax. Plain strings, checklist rows, and owner paths are enough for v1.
