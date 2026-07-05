# `registryhealth` Plugin Spec

## Decision

Build `registryhealth` as one read-only `BlockRuntime` that shows whether the current Surface plugin wiring is internally consistent. It should make the existing registry, package targets, plugin tests, default layout, and preview fixture coverage visible without becoming a registry generator, scaffolder, test runner, or second plugin registry.

Use the existing `Block` / `BlockRuntime` / `Block.Context` path. The block can surface commands and files to inspect, but it must not mutate `Package.swift`, `plugins/Blocks.swift`, layout files, preview fixtures, or tests.

## Existing Owner / Dedup Decision

- `plugins/Blocks.swift` owns the active `Blocks.registry`.
- `Package.swift` owns SwiftPM targets and test targets.
- `Sources/Core/Model.swift` owns `BlockRegistry`, duplicate-id rejection, and block lookup.
- `Sources/Core/Layout.swift` owns default layout ids and frames.
- `tools/block-preview/support/BlockPreviewSupport.swift` owns preview fixture definitions and real-runtime rendering through `Blocks.registry`.
- `tests/BlockPreviewTests/BlockPreviewTests.swift` owns fixture coverage and nonblank preview assertions.
- `localbuildstatus` owns build/test/preview pass/fail result display.
- `readmehub` owns docs and plugin-authoring checklists.
- `scriptoutput` owns arbitrary command execution.
- `registryhealth` owns only a bounded health report view over those owners.

If a registry generation step exists later, it should remain the process that updates `plugins/Blocks.swift`. `registryhealth` should read the generated source or a generated status report, not become the generator.

## Product Boundary

It should:

- Read `registryhealth-status.json` from `Block.Context.storageDirectory` in previews/tests or from one configured generated-report path in live mode.
- Show each known block with registry, package target, tests, preview fixtures, default layout, and preview status.
- Show repo-level issues such as duplicate ids, missing registry entries, missing package targets, missing preview fixtures, missing preview-test coverage, unknown layout ids, failed preview renders, and stale reports.
- Use `Block.Context.now` for stale report labels.
- Offer explicit open/reveal/copy actions for the existing owner files and verification commands.
- Stay useful with fixture data even when live repo scanning is unavailable.

It should not:

- Create, generate, sort, or rewrite `plugins/Blocks.swift`.
- Modify `Package.swift`, `SurfaceLayout.defaultLayout`, preview fixtures, or tests.
- Run `swift build`, `swift test`, `swift run block-preview`, `git`, `sed`, or any shell command.
- Parse arbitrary Swift ASTs inside the block runtime.
- Create a plugin manifest, scaffold plugins, add Package targets, or propose a second registry.
- Duplicate `localbuildstatus` result history, `readmehub` docs indexing, or `scriptoutput` command execution.
- Treat missing preview coverage as auto-fixable from inside the block.

## First Version

### Data Modes

Fixture mode:

1. Read `Block.Context.storageDirectory/registryhealth-status.json`.
2. Render the report exactly as data, including stale/missing/failed examples.
3. Do not scan source files, run commands, or open files.

Live mode:

1. Read one configured generated-report path, such as an Application Support file or a repo-local `.build/surface-status/registryhealth.json`.
2. Optionally read a bounded set of configured source files only to show snippets/counts: `plugins/Blocks.swift`, `Package.swift`, `tools/block-preview/support/BlockPreviewSupport.swift`, `tests/BlockPreviewTests/BlockPreviewTests.swift`, and `Sources/Core/Layout.swift`.
3. Prefer an external writer for the status JSON. Candidate owners are the block-preview tool, `localbuildstatus`, or a dedicated explicit verification script. The block should not run that writer.
4. Treat missing or stale status files as a visible warning, not a runtime failure.

### Status File

```json
{
  "version": 1,
  "generatedAt": "2026-06-24T02:36:57Z",
  "repoRoot": "/Users/example/projects/surface",
  "registrySource": "plugins/Blocks.swift",
  "packageSource": "Package.swift",
  "layoutSource": "Sources/Core/Layout.swift",
  "previewSupportSource": "tools/block-preview/support/BlockPreviewSupport.swift",
  "previewTestsSource": "tests/BlockPreviewTests/BlockPreviewTests.swift",
  "blocks": [
    {
      "id": "quicksave",
      "title": "Quicksave",
      "packageTarget": "Quicksave",
      "registered": true,
      "inDefaultLayout": true,
      "pluginTests": "QuicksaveTests",
      "previewFixtures": ["empty", "notes-and-captures"],
      "previewStatus": "passed",
      "issues": []
    }
  ],
  "issues": [
    {
      "severity": "warning",
      "kind": "missingPreviewFixture",
      "blockID": "githubqueue",
      "path": "tools/block-preview/support/BlockPreviewSupport.swift",
      "message": "No preview fixture coverage."
    }
  ]
}
```

Allowed issue severities:

- `info`
- `warning`
- `error`

Suggested issue kinds:

- `duplicateBlockID`
- `missingRegistryEntry`
- `missingPackageTarget`
- `missingPluginTests`
- `missingPreviewFixture`
- `missingPreviewTestCoverage`
- `unknownDefaultLayoutBlock`
- `previewRenderFailed`
- `previewNonBlankFailed`
- `staleReport`
- `missingReport`

## Display

Header:

- `Registry`
- total block count
- issue count by severity
- report age

Rows:

- block title and id
- status chip: healthy, warning, or error
- registry status
- package target status
- test target status
- preview fixture count
- preview render status
- default layout status
- fixed icon buttons: open owner file, reveal file, copy id, copy verification command

Sections:

- Attention
- Blocks
- Owner files
- Verification commands

Keep the view diagnostic and compact. This is an inspection surface, not a repair UI.

## Actions

- Open `plugins/Blocks.swift`.
- Open `Package.swift`.
- Open `tools/block-preview/support/BlockPreviewSupport.swift`.
- Open `tests/BlockPreviewTests/BlockPreviewTests.swift`.
- Open `Sources/Core/Layout.swift`.
- Reveal those files in Finder.
- Copy block id.
- Copy verification commands:
  - `swift test --filter <PluginTests>`
  - `swift run block-preview <block-id> --fixture <fixture> --size 420x520`
  - `swift run block-preview all --output .build/block-previews`
  - `swift test --filter BlockPreviewTests`

No action should write files, run commands, generate code, scaffold plugins, or mutate the registry.

## Source Evidence

- Surface's README defines one plugin path: create a target, expose `Plugin.block`, conform to `BlockRuntime`, use `Block.Context`, register in `plugins/Blocks.swift`, wire `Package.swift`, add tests, add preview fixtures, update preview tests, and validate with previews/tests.
- `BlockRegistry` already rejects duplicate ids and offers lookup by `BlockID`, so duplicate and unknown-id handling belongs to the current model owner.
- `plugins/Blocks.swift` is the active registry source and currently lists `Quicksave.Plugin.block`, `CopyHistory.Plugin.block`, and `CodexLog.Plugin.block`.
- `BlockPreview.render` and `renderSurface` use `Blocks.registry` and real `BlockRuntime.makeView()` with deterministic `Block.Context`, so preview health should report coverage of that path instead of inventing a preview-only UI.
- `BlockPreviewTests` already enforces fixture coverage and nonblank PNG metrics for the current plugins, making it the enforcement owner; `registryhealth` should mirror/report that state.
- Swift Package Manager's package description model makes targets explicit in `Package.swift`; package wiring should be visible but not mutated by this block.

## Preview Fixtures

Use `Block.Context.storageDirectory`.

- `empty`: no status file.
- `healthy-current`: all current plugins passing with fresh report.
- `missing-fixtures`: one block registered and packaged but missing preview fixtures.
- `package-mismatch`: registry entry without a package/test target or package target without a registry entry.
- `preview-failed`: preview render and nonblank failures.
- `stale-report`: generatedAt older than the configured stale threshold.
- `read-only`: report visible with open/reveal/copy actions disabled by context.

## Tests

- Decode a valid status file and roll up severity counts.
- Show missing-report and stale-report warnings using `Block.Context.now`.
- Render block rows for healthy, warning, and error states.
- Produce copyable verification commands without executing them.
- Keep open/reveal actions disabled when external writes/actions are not allowed.
- Verify the runtime never writes source files or generates registry/package/test/fixture code.
- Add preview coverage for every fixture and include `registryhealth` in `BlockPreviewTests`.

## Implementation Notes

- Start with a plain Codable model local to the plugin.
- Use fixed relative owner paths from the status file; do not recursively scan the repo.
- Use simple status sorting: errors first, warnings second, healthy rows last, then id.
- Treat the external status writer as a follow-up research item before implementation if no obvious owner exists.
