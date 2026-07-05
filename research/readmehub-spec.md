# `readmehub` Plugin Spec

## Decision

Build `readmehub` as one read-only documentation index `BlockRuntime` for repo and plugin authoring docs. It should surface the canonical README sections, plugin READMEs, architecture docs, research specs, and copyable validation commands without becoming a Markdown editor, docs generator, wiki, or second plugin registry.

Use the existing `Block` / `BlockRuntime` / `Block.Context` path and generated registry. The block can make plugin authoring easier, but it must not create plugins, mutate docs, run checks, or infer registry health.

## Existing Owner / Dedup Decision

- `README.md` owns the canonical plugin authoring steps and preview loop.
- `AGENTS.md` owns repo-specific agent/developer instructions.
- `research/` owns speculative plugin specs and ranking state.
- Plugin-local READMEs own plugin-specific contracts and development loops.
- `registryhealth` should own generated registry/preview fixture coverage once specified.
- `localbuildstatus` owns build/test/preview result status.
- `scriptoutput` owns command execution.
- `fileinbox` owns recent Markdown/file triage.
- `appquicklaunch` owns open/reveal behavior.
- `readmehub` owns only a curated docs index, heading/link extraction, status labels, and explicit open/reveal/copy actions.

If implementation needs shared Markdown heading extraction later, factor only after `readmehub` and `registryhealth` both need it. Do not create a documentation service first.

## Product Boundary

It should:

- Read `readmehub-index.json` from `Block.Context.storageDirectory` in previews/tests or Application Support in live mode.
- Offer sensible repo-local defaults when no index exists: `README.md`, `AGENTS.md`, `docs/*.md`, `plugins/*/README.md`, and `research/README.md`.
- Optionally include `research/*-spec.md` as spec cards when explicitly enabled.
- Extract headings, local Markdown links, and fenced shell commands from configured docs.
- Show plugin-authoring checklist steps from `README.md` as read-only rows.
- Show source path, modified age, status, owner, and missing/stale warnings.
- Let the user open/reveal docs, copy doc links/paths, and copy commands.

It should not:

- Edit Markdown, save notes, add CriticMarkup, or replace Roughdraft.
- Generate READMEs, DocC archives, API docs, tables of contents, plugin manifests, or templates.
- Run `swift`, `git`, `docc`, `gh`, `roughdraft`, editor CLIs, or shell commands.
- Validate registry coverage, preview fixtures, or test results; that belongs to `registryhealth` and `localbuildstatus`.
- Scan the whole repository for Markdown files.
- Render a full Markdown preview/webview.
- Install VS Code/Markdown extensions or open editor-specific preview modes.
- Create plugins, modify `Package.swift`, mutate `plugins/Blocks.swift`, or add a second registry.

## First Version

### Data Modes

Fixture mode:

1. Read `Block.Context.storageDirectory/readmehub-index.json`.
2. Read fixture Markdown files referenced by that index.
3. Do not open files, run commands, or scan the live repo.

Live mode:

1. Read `~/Library/Application Support/Surface/ReadmeHub/readmehub-index.json` if present.
2. If no index exists, use the current repo root only when configured in the index or supplied by the host context later.
3. Read only the bounded default docs and explicitly listed spec files.
4. Use `FileManager` metadata and plain text reads only.
5. Open/reveal through AppKit only from explicit user actions and only when external actions are allowed.

### Index File

```json
{
  "version": 1,
  "title": "Surface Docs",
  "repoRoot": "/Users/example/projects/surface",
  "includeResearchSpecs": true,
  "documents": [
    {
      "id": "surface-readme",
      "title": "Surface README",
      "path": "README.md",
      "kind": "repoReadme",
      "owner": "repo",
      "status": "canonical",
      "pinned": true,
      "sections": ["Build, Run, and Test", "Block Preview Harness", "Add a Plugin"]
    },
    {
      "id": "codexlog-readme",
      "title": "Codex Log README",
      "path": "plugins/codexlog/README.md",
      "kind": "pluginReadme",
      "owner": "codexlog",
      "status": "canonical",
      "pinned": false
    },
    {
      "id": "readmehub-spec",
      "title": "Readme Hub Spec",
      "path": "research/readmehub-spec.md",
      "kind": "researchSpec",
      "owner": "research",
      "status": "draft",
      "pinned": false
    }
  ]
}
```

Allowed `kind` values:

- `repoReadme`
- `agentInstructions`
- `architecture`
- `pluginReadme`
- `researchReadme`
- `researchSpec`
- `commandReference`

Allowed `status` values:

- `canonical`
- `draft`
- `stale`
- `missing`
- `blocked`

### Parsed Document Summary

```json
{
  "id": "surface-readme",
  "title": "Surface README",
  "path": "README.md",
  "kind": "repoReadme",
  "status": "canonical",
  "modifiedAt": "2026-06-24T02:03:57Z",
  "headings": [
    { "level": 2, "title": "Build, Run, and Test", "line": 21 },
    { "level": 2, "title": "Block Preview Harness", "line": 72 },
    { "level": 2, "title": "Add a Plugin", "line": 128 }
  ],
  "links": [
    { "label": "docs/overlay-model.md", "target": "docs/overlay-model.md", "line": 13 }
  ],
  "commands": [
    { "label": "Run full tests", "command": "swift test", "line": 55 },
    { "label": "Render all previews", "command": "swift run block-preview all --output .build/block-previews", "line": 87 }
  ]
}
```

### Parsing Policy

- Use lightweight, deterministic plain-text extraction.
- Extract ATX headings (`#`, `##`, etc.) and fenced `bash`/`sh`/plain command blocks.
- Extract local Markdown links with relative targets.
- Ignore remote image URLs, HTML blocks, frontmatter mutation, task-list state, and Markdown extensions.
- Do not try to render Markdown. If rendering is needed, open the file in the user's editor or Roughdraft outside this block.

## Display

Header:

- `Docs`
- document count
- missing/stale count
- spec count when research specs are included

Rows/cards:

- title
- kind/status chip
- relative path
- modified age from `Block.Context.now`
- matching section count
- command count
- missing/stale warning if applicable
- fixed icon buttons: open, reveal, copy path, copy Markdown link, copy selected command

Sections:

- Pinned docs
- Plugin authoring
- Plugin READMEs
- Research specs
- Architecture/reference

Keep the view compact. This is a launcher/index for docs, not the docs themselves.

## Actions

- Open doc file.
- Reveal doc file.
- Copy absolute path.
- Copy repo-relative Markdown link.
- Copy a command string.
- Copy "Add a Plugin" checklist as Markdown.
- Copy a spec implementation checklist from a selected research spec.

No action should write files, generate docs, run commands, create plugins, modify package/registry files, or open a Markdown preview/editor mode automatically.

## Source Evidence

- GitHub documents repository READMEs as the place to explain why a project is useful, what users can do with it, and how to use it; Surface's `README.md` already carries exactly that role for build/test/plugin authoring.
- GitHub Markdown docs support heading outlines and relative links, which map cleanly to a lightweight docs index.
- CommonMark gives a stable baseline for Markdown headings and links, but `readmehub` should use only a small extraction subset rather than becoming a renderer.
- Swift-DocC converts Markdown-based text into rich Swift documentation, which is useful evidence for later docs generation, but generation belongs outside `readmehub` v1.
- VS Code has a full Markdown editor/preview workflow; Surface should open docs externally rather than embedding a Markdown editor or preview surface.
- Surface's own README says the extension unit is a `Block` and lists the exact plugin creation steps; `readmehub` should point to those steps rather than inventing a scaffolder.

## Preview Fixtures

Use `Block.Context.storageDirectory`.

- `empty`: no index and no docs.
- `surface-docs`: README, AGENTS, docs note, and one plugin README.
- `plugin-authoring`: README with add-plugin checklist and preview commands.
- `research-specs`: research README plus two spec files.
- `missing-docs`: configured docs missing from fixture root.
- `read-only`: docs visible with actions disabled by context.

## Tests

- Missing index renders empty/setup state.
- Index decoding preserves document order, kind, status, pinned state, and relative paths.
- Heading extraction handles ATX headings and line numbers.
- Local Markdown link extraction handles repo-relative links.
- Command extraction finds fenced shell commands and does not execute them.
- Missing docs render warning rows without crashing.
- Default repo-local discovery is bounded to README/AGENTS/docs/plugin READMEs/research README.
- Research spec discovery is disabled unless configured.
- Fixture mode performs no live repo scan, external open, shell command, DocC generation, or editor launch.
- Copy actions return deterministic path/link/command strings.
- Preview fixtures render nonblank PNGs and are covered by `BlockPreviewTests`.

## Recommendation

Implement `readmehub` as a small docs index after the current plugin README/docs pass. It should make plugin authoring usable by surfacing canonical local docs and commands, while `registryhealth`, `localbuildstatus`, and `scriptoutput` own verification, health, and execution.
