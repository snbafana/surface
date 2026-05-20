# Codex Log

Codex Log is a Surface block for watching local Codex activity. It is not a Codex desktop plugin yet; it reads the on-device Codex state that already exists under `~/.codex` and exposes a small append-only action queue that Codex automations can write to.

## What The Block Reads

- `~/.codex/state_5.sqlite`
  - recent thread metadata from `threads`
  - job status counts from `jobs`
- `~/.codex/logs_2.sqlite`
  - currently running threads, inferred from recent `logs.thread_id` activity
- `~/.codex/automations/*/automation.toml`
  - automation id, name, kind, status, schedule, and target thread
- `ps ax`
  - local Codex process groups
- `~/.codex/codexlog-actions.jsonl`
  - proposed actions and approval/denial/cancel decisions

## Action Queue Contract

Automations and cron jobs should append proposed actions to:

```text
~/.codex/codexlog-actions.jsonl
```

Each row is JSON. The minimum useful pending proposal is:

```json
{"id":"patch-1","title":"Review generated patch","detail":"Apply proposed diff","status":"pending","thread_id":"019...","automation_id":"daily-review","created_at":1779229100000}
```

Fields:

- `id`: stable action id. Reuse this id for later status updates.
- `title`: short user-visible action.
- `detail`: optional explanation. This can be a string or a structured object.
- `status`: `pending`, `approved`, `denied`, `cancelled`, `completed`, or `failed`.
- `thread_id`: optional Codex thread id tied to the action.
- `automation_id`: optional automation id from `~/.codex/automations`.
- `job_id`: optional external job id if the automation has one.
- `created_at` / `updated_at`: epoch milliseconds or seconds.

Surface appends decisions as new rows instead of mutating old rows. The reader folds the log by `id`, preserving history while treating the latest row as the current status. Automations should append `completed` or `failed` after trying to execute an approved action so the same approved action is not repeated on the next run.

Actions must be bite-sized. One approval should map to one thing the user can evaluate quickly, not a bundled file rewrite.

### `daily-codex-guidance-review`

Purpose: propose instruction updates for `AGENTS.md` / Codex guidance files.

JSONL rule: one row per target file and per exact guidance point. If a proposed file edit has five bullets, append five pending rows. Do not bundle a whole section, whole file, or multi-point patch into one approval.

Recommended `detail` object:

```json
{
  "target_path": "/path/to/AGENTS.md",
  "edit_type": "addition",
  "insertion_point": "Append under Abstraction Guardrails",
  "proposed_text": "- Ask what existing code can be reused before adding a parallel runtime.",
  "rationale": "Observed repeated abstraction drift in the Surface repo."
}
```

Compatibility: the current reader can split older structured parent rows by bullet/numbered point from `detail.proposed_text`, `detail.proposed_initial_contents`, or `detail.replace_with`.

### `daily-obsidian-backlink-proposals`

Purpose: propose missing `Related:` wikilinks for Obsidian notes.

JSONL rule: one row per source note and per proposed wikilink. If one note needs eight links, append eight pending rows. Preserve existing `Related:` values and do not ask approval for links already present.

Recommended `detail` object:

```json
{
  "source_note_path": "Inbox/How to Understand ML Papers Quickly.md",
  "current_related": ["[[Machine Learning Trends]]"],
  "link": "[[Deep Learning]]",
  "exists": true,
  "rationale": "Connects the paper-reading note to the existing deep-learning cluster.",
  "approval_patch": {
    "type": "frontmatter_related_add_link",
    "path": "Inbox/How to Understand ML Papers Quickly.md",
    "link": "[[Deep Learning]]"
  }
}
```

Compatibility: the current reader can split older structured parent rows from `detail.proposed_links` and ignores links already present in `detail.current_related`.

### `daily-note-to-genuine-ideas`

Purpose: promote explicit ideas from the daily note into `Future Lists/Genuine Ideas List.md`.

JSONL rule: one row per idea. Do not bundle multiple ideas into one approval.

Recommended `detail` object:

```json
{
  "target_path": "Future Lists/Genuine Ideas List.md",
  "addition_text": "- Local approval queues for long-running agents.",
  "source_daily_note_path": "Zettelkatsen/05-19-2026.md",
  "source_context": "daily note text that explicitly stated the idea",
  "not_duplicate_because": "No existing item about local approval queues."
}
```

Compatibility: the current reader can split older structured parent rows from `detail.ideas` or bullet/numbered points in `detail.addition_text`.

## Automation Prompt Hook

For a Codex automation to show up in this block, include a line like this in the automation prompt:

```text
At the beginning of each run, read ~/.codex/codexlog-actions.jsonl if it exists, fold rows by id, and use the latest row as the current status. First append any new proposed actions for this automation as status="pending" rows with stable ids, title, detail, automation_id, thread_id if known, and created_at. Each row must be bite-sized: one Codex guidance point, one backlink/link for one file, or one idea. Then execute only actions for this automation whose latest status was already "approved" before this run started. Do not execute actions that are pending, denied, cancelled, completed, or failed. After execution, append a row for the same id with status="completed" or "failed" and updated_at.
```

The plugin does not yet mutate Codex automations or cancel running jobs directly. The current control loop is file-based: automations propose actions, Surface records user decisions, and later automation runs read the same log before continuing.

## Twice-Daily Automation Loop

The three cron automations run every 12 hours with interval-based scheduling, not fixed AM/PM duplicate automations. They all use the same two-phase loop every run:

1. Propose actions for the automation's domain by appending `pending` rows to `~/.codex/codexlog-actions.jsonl`.
2. Execute any previously approved actions for that same automation.
3. Mark each attempted approved action as `completed` or `failed` in the same log.

The order matters. A newly proposed action should not be executed in the same run unless it was already approved in an earlier row before the run started. Denied and cancelled actions are closed unless the underlying situation materially changes enough to justify a new action id.

Current consolidated schedule:

- `daily-codex-guidance-review`: `RRULE:FREQ=HOURLY;INTERVAL=12`
- `daily-note-to-genuine-ideas`: `RRULE:FREQ=HOURLY;INTERVAL=12`
- `daily-obsidian-backlink-proposals`: `RRULE:FREQ=HOURLY;INTERVAL=12`

The old PM companion automations are intentionally removed; there should be only one automation per domain. `daily-scratch-cleanup` is intentionally outside this loop. It remains a separate Scratch workspace maintenance automation.

## UI Shape

The block renders:

- `Action Queue`: one focused pending action at a time, including source automation, target file, thread, proposed time, and the exact point/link/idea under review.
- `Running Threads`: threads with recent `logs_2.sqlite.logs.thread_id` activity.

Interaction:

- Right arrow or drag right approves the focused action.
- Left arrow or drag left denies the focused action.
- Up/down arrows move through pending actions.

## Development Loop

Run the focused tests:

```bash
swift test --filter CodexLogTests
```

Render just this block:

```bash
swift run block-preview codexlog --fixture active-thread --output .build/block-previews
```

Then inspect:

```text
.build/block-previews/codexlog-active-thread.png
```

Run the full preview smoke test:

```bash
swift test --filter BlockPreviewTests
```

Run the full package checks before committing:

```bash
swift test
swift build -c release
```

## Fixture Rule

When `Block.Context.storageDirectory` is set, Codex Log reads that directory as a fake `.codex` home and disables live process reads. This keeps plugin previews and tests deterministic.

The real app path uses:

```swift
CodexStateReader.defaultCodexHome
```

which resolves to `~/.codex`.
