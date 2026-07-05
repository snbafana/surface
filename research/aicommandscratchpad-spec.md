# `aicommandscratchpad` Plugin Spec

## Why This Matters

AI command workflows are useful when repeated prompts become concrete work units: draft this reply, review this snippet, summarize this page, extract a checklist, rewrite this paragraph, compare these notes. Raycast AI Commands validates one-press prompt runs, argument placeholders, selected-text workflows, model settings, tags, and response windows. Raycast AI Extensions validates tool-using AI flows, but also shows why Surface should not hide tool execution inside a generic AI block. OpenAI's prompting guidance reinforces that prompt construction, typed inputs, fixtures, tests, and evaluation are real application concerns.

The useful Surface version is a local AI command scratchpad: short-lived prompt run cards with assembled input, context references, manual/external output, and copy/handoff actions.

## Existing Owner / Dedup Decision

- `snippetprompt` owns reusable prompt/snippet templates, placeholder resolution, arguments, and copy actions.
- `contextcard` owns generic app/window context.
- `browsersessioncards` owns browser tab/session snapshots.
- `linkinbox` owns durable URL records.
- `scriptoutput` owns command/API execution and stdout/stderr status.
- Codex Log owns Codex threads, approval queues, and running-thread state.
- `aicommandscratchpad` owns only per-run AI command cards, assembled prompts, run metadata, pasted/external outputs, and archive/status actions.

Do not add an AI API client, model marketplace, provider credential store, chat thread UI, streaming response UI, tool-calling runtime, MCP client, agent runner, selected-text Accessibility reader, browser/page reader, shell execution, or a second plugin registry. Implement as one `BlockRuntime` using `Block.Context.storageDirectory` and `Block.Context.now`.

## Product Boundary

It should:

- Show draft, ready, running-external, needs-output, completed, and archived run cards.
- Store each run's command title, intent, assembled instructions, input text, context references, status, and optional output.
- Copy assembled prompt text.
- Copy a developer/user-message Markdown or JSON payload.
- Capture clipboard text as input or output only from an explicit action.
- Mark a run ready, waiting, completed, or archived.
- Open linked context URLs/files through explicit actions.
- Accept externally written output/status from `scriptoutput`, Codex, or a user script.
- Show model/provider labels as metadata when present, without owning credentials.

It should not:

- Execute prompts against OpenAI, Anthropic, local models, or any provider in v1.
- Store API keys, OAuth tokens, model secrets, or provider account state.
- Choose models automatically or maintain a provider registry.
- Run tools, functions, MCP servers, shell commands, browser automation, or app actions.
- Continue conversations or render a full chat UI.
- Read selected text, browser tabs, page content, clipboard history, files, or URLs except through explicit context files and actions.
- Replace text in another app or paste automatically.
- Duplicate `snippetprompt`'s template library.

## First Version

### Data Modes

Fixture mode:

1. Read `Block.Context.storageDirectory/aicommandscratchpad-runs.jsonl`.
2. Read optional `Block.Context.storageDirectory/aicommandscratchpad-context.json`.
3. Use `Block.Context.now` for age and stale labels.
4. Do not read the real clipboard, call AI APIs, execute scripts, or query context owners.
5. Mutating actions can be preview no-ops or write only to fixture storage.

Live mode:

1. Read `~/Library/Application Support/Surface/AICommandScratchpad/aicommandscratchpad-runs.jsonl`.
2. Read optional `~/Library/Application Support/Surface/AICommandScratchpad/aicommandscratchpad-context.json`.
3. Write status/output/archive changes only when `Block.Context.allowsExternalWrites` is true.
4. Resolve clipboard input/output only when the user presses a capture button.
5. Do not call AI providers from the block runtime.

External writers:

- `scriptoutput` or a user script may append run output/status after calling an AI provider.
- Codex workflows may append completed outputs or links to threads.
- `snippetprompt`, `contextcard`, `browsersessioncards`, and `linkinbox` may later write explicit handoff files, but they keep ownership of their own stores.

### Local Data Model

```swift
struct AICommandRun: Codable, Identifiable, Equatable {
    var id: String
    var title: String
    var intent: String?
    var sourceTemplateID: String?
    var instructions: String
    var input: String
    var contextItems: [AICommandContextItem]
    var output: AICommandOutput?
    var status: AICommandRunStatus
    var providerLabel: String?
    var modelLabel: String?
    var createdAt: Date
    var updatedAt: Date
    var archivedAt: Date?
    var metadata: [String: String]
}

struct AICommandContextItem: Codable, Identifiable, Equatable {
    var id: String
    var kind: AICommandContextKind
    var title: String
    var value: String
    var url: URL?
    var capturedAt: Date
}

enum AICommandContextKind: String, Codable {
    case text
    case url
    case file
    case browserTab
    case appWindow
    case clipboard
    case note
}

struct AICommandOutput: Codable, Equatable {
    var text: String
    var capturedAt: Date
    var source: AICommandOutputSource
    var sourceURL: URL?
}

enum AICommandOutputSource: String, Codable {
    case pasted
    case externalRunner
    case codex
    case fixture
}

enum AICommandRunStatus: String, Codable {
    case draft
    case ready
    case runningExternal
    case needsOutput
    case completed
    case failed
    case archived
}
```

Use append-friendly JSONL. Mutations may append replacement rows with the same `id`, then fold by latest `updatedAt`, matching Codex Log's action-log pattern where useful.

### Prompt Assembly

V1 stores assembled `instructions` and `input` directly. It may show `sourceTemplateID`, but it should not own a template library or placeholder engine.

Supported copy formats:

- Plain prompt:
  ```text
  # Instructions
  ...

  # Input
  ...

  # Context
  ...
  ```
- Message JSON:
  ```json
  {
    "instructions": "...",
    "input": "..."
  }
  ```
- Markdown run card:
  ```markdown
  ## Run Title
  Status: ready

  ...
  ```

### Display Rules

Group rows by:

1. running external
2. ready / needs output
3. drafts
4. failed
5. completed recent

Rows should show:

- title
- status pill
- provider/model label if present
- context count and output state
- updated age from `Block.Context.now`
- short input/output preview

Sort rows within groups by:

1. pinned/favorited later if added
2. updated time descending
3. title

Hidden rows:

- archived rows by default
- completed rows older than a configurable threshold, default 48 hours

### Actions

- Copy assembled prompt.
- Copy message JSON.
- Copy output.
- Copy run Markdown.
- Capture clipboard as input.
- Capture clipboard as output.
- Mark ready.
- Mark waiting for external output.
- Mark completed.
- Mark failed.
- Archive/unarchive.
- Open context URL/file.
- Reveal/open backing JSONL file.

No action should call an AI API, run a shell command, invoke a tool, replace active-app text, or mutate a source owner.

## UI Shape

Header:

- `AI Scratch`
- status pill: `2 ready`, `1 waiting`, or `Clear`
- source pill: `local only` or `external output`

Primary row:

- compact status icon
- title and one-line prompt/input preview
- context/output badges
- icon actions for copy prompt, copy JSON, capture output, archive

Expanded view:

- instructions/input/context/output sections
- copy buttons per section
- no chat transcript bubbles in v1

Empty state:

- `No active runs`
- open backing JSONL
- handoff note: `Create from Snippet Prompt or paste a run`

## Runtime Shape

Target: `plugins/aicommandscratchpad/source/Plugin.swift`

Runtime:

1. `start()`: load runs and optional context file.
2. `refresh()`: reload files, fold JSONL rows by `id`, hide archived/expired rows, recompute age/status summaries.
3. `stop()`: no-op.
4. `makeView()`: render grouped run cards and explicit copy/status actions.

Use plugin-local JSONL helpers first. If this and Codex Log both need append-only ledger folding after implementation, factor a tiny ledger helper then.

## Fixture Plan

Fixtures:

- `empty`: no runs.
- `draft-run`: draft with instructions/input and no context.
- `ready-with-context`: ready run with context references from browser/link/app snapshots.
- `waiting-output`: run marked `runningExternal` or `needsOutput`.
- `external-output`: externally written output and provider/model labels.
- `archived-completed`: completed and archived rows hidden by default.

Example JSONL:

```json
{"id":"run-1","title":"Review PR comment","intent":"Draft a concise reply","sourceTemplateID":"reply-review","instructions":"Write a direct reply. Preserve the user's wording where possible.","input":"Reviewer asked for clearer test coverage.","contextItems":[{"id":"ctx-1","kind":"url","title":"PR #42","value":"https://github.com/example/repo/pull/42","url":"https://github.com/example/repo/pull/42","capturedAt":"2026-06-21T23:00:00Z"}],"output":null,"status":"ready","providerLabel":null,"modelLabel":null,"createdAt":"2026-06-21T23:00:00Z","updatedAt":"2026-06-21T23:00:00Z","archivedAt":null,"metadata":{}}
```

## Test Plan

- Missing run file renders empty state.
- JSONL rows decode and invalid rows are reported without crashing.
- Latest row wins when multiple rows share an `id`.
- Archived rows are hidden by default.
- Completed rows older than threshold are hidden unless configured.
- Grouping and age use `Block.Context.now`.
- Copy prompt, JSON, output, and Markdown format deterministically.
- Clipboard capture uses fixture clipboard text in previews and a pasteboard adapter in tests.
- Status mutations write only when fixture storage or external writes allow it.
- No test path calls AI APIs, shells, browsers, Accessibility, or source-owner stores.
- Preview fixtures render nonblank PNGs through `Blocks.registry`.

## Recommendation

Implement only after `snippetprompt` exists or when there is a concrete handoff format from it. Keep v1 local and copy-oriented. Add live AI execution only as a separate explicit integration or external writer after credential storage, provider policy, rate limits, cost display, cancellation, and output persistence are designed.
