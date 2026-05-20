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
- `detail`: optional explanation.
- `status`: `pending`, `approved`, `denied`, `cancelled`, `completed`, or `failed`.
- `thread_id`: optional Codex thread id tied to the action.
- `automation_id`: optional automation id from `~/.codex/automations`.
- `job_id`: optional external job id if the automation has one.
- `created_at` / `updated_at`: epoch milliseconds or seconds.

Surface appends decisions as new rows instead of mutating old rows. The reader folds the log by `id`, preserving history while treating the latest row as the current status. Automations should append `completed` or `failed` after trying to execute an approved action so the same approved action is not repeated on the next run.

## Automation Prompt Hook

For a Codex automation to show up in this block, include a line like this in the automation prompt:

```text
At the beginning of each run, read ~/.codex/codexlog-actions.jsonl if it exists, fold rows by id, and use the latest row as the current status. First append any new proposed actions for this automation as status="pending" rows with stable ids, title, detail, automation_id, thread_id if known, and created_at. Then execute only actions for this automation whose latest status was already "approved" before this run started. Do not execute actions that are pending, denied, cancelled, completed, or failed. After execution, append a row for the same id with status="completed" or "failed" and updated_at.
```

The plugin does not yet mutate Codex automations or cancel running jobs directly. The current control loop is file-based: automations propose actions, Surface records user decisions, and later automation runs read the same log before continuing.

## Twice-Daily Automation Loop

Daily cron automations should run twice per day and use the same two-phase loop every time:

1. Propose actions for the automation's domain by appending `pending` rows to `~/.codex/codexlog-actions.jsonl`.
2. Execute any previously approved actions for that same automation.
3. Mark each attempted approved action as `completed` or `failed` in the same log.

The order matters. A newly proposed action should not be executed in the same run unless it was already approved in an earlier row before the run started. Denied and cancelled actions are closed unless the underlying situation materially changes enough to justify a new action id.

Current twice-daily schedule targets:

- `daily-codex-guidance-review`: 9:00 AM and 9:00 PM.
- `daily-note-to-genuine-ideas`: 10:00 AM and 10:00 PM.
- `daily-obsidian-backlink-proposals`: 10:30 AM and 10:30 PM.

`daily-scratch-cleanup` is intentionally outside this loop. It remains a separate Scratch workspace maintenance automation.

## UI Shape

The block renders:

- `Running Now`: threads with recent `logs_2.sqlite.logs.thread_id` activity.
- `Needs Attention`: threads tied to pending actions and failed job buckets.
- `Jobs`: counts for running, completed, and attention-needed jobs.
- `Action Queue`: the first pending action, with approve, deny, and cancel buttons.
- `Active automations`: count of automation TOML files with `status = "ACTIVE"`.

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
