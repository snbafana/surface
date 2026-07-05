# `scriptoutput` Plugin Spec

## Decision

Build `scriptoutput` as one constrained `BlockRuntime` that runs one user-configured executable on a fixed interval and renders its stdout as status rows. Do not create a script-plugin marketplace, plugin folder watcher, script registry, action language, or general automation framework.

## Dedupe Boundary

- The repo already has narrow command execution patterns:
  - Codex Log injects a `CommandRunner` for `sqlite3` and `ps` reads.
  - Quicksave uses a narrow `ObsidianCLI` wrapper for daily-note creation.
- `scriptoutput` can reuse or factor a tiny bounded process runner if implementation needs shared timeout/output-limit handling.
- Do not generalize the xbar/SwiftBar plugin model into Surface. Surface already has `Block`, `BlockRuntime`, `Blocks.registry`, and the generated registry UI.

## Product Shape

Surface should show a compact command-status block:

- header: script name, last status, last run time, next run
- output: up to 8 parsed rows from stdout
- details: exit code, runtime duration, stderr excerpt on failure
- controls: refresh, copy stdout, copy stderr, reveal script, disable block

The primary value is scheduled local status, not arbitrary workflow execution.

## Configuration

Use one JSON file:

```json
{
  "version": 1,
  "title": "Repo Status",
  "executable": "/Users/example/bin/surface-status.sh",
  "arguments": [],
  "workingDirectory": "/Users/example/project",
  "refreshSeconds": 300,
  "timeoutSeconds": 10,
  "maxOutputBytes": 32768,
  "environment": {
    "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
  }
}
```

Locations:

- preview/tests: `Block.Context.storageDirectory/scriptoutput-config.json`
- live: `~/Library/Application Support/Surface/ScriptOutput/scriptoutput-config.json`

Do not support multiple scripts in v1. If a user needs multiple statuses, they should add multiple `scriptoutput` block instances only after the layout model supports per-instance configuration.

## Output Format

Parse a conservative subset of xbar/SwiftBar output:

- stdout split by `\n`
- first section before `---` is header/status
- rows after first `---` are body/details
- each line may use `<title> | key=value key2=value`

Supported v1 parameters:

- `color`
- `sfimage`
- `href`
- `disabled`
- `trim`
- `length`

Explicitly ignore or render inert:

- `shell`, `bash`, `param1`, `terminal`, `refresh`, and any command-running action parameter
- nested submenu levels
- variable metadata
- xbar control URLs

This keeps old menu-bar scripts useful while preventing the block from becoming an action runner.

## Runtime Behavior

- `start()`: load config and last snapshot, then run once if live execution is allowed.
- `refresh()`: run the configured command when `Block.Context.allowsLiveProcesses` is true; in previews/tests, read fixture stdout/stderr/result JSON instead.
- `stop()`: cancel the polling task and any in-flight process when feasible.
- execution:
  - use direct executable path, not shell interpolation
  - pass arguments as an array
  - set explicit working directory
  - enforce timeout
  - cap stdout/stderr bytes
  - capture exit code and duration
  - keep the previous successful output visible when the latest run fails
- interval:
  - minimum live interval: 30 seconds
  - default interval: 5 minutes
  - no sub-second refresh, even if xbar/SwiftBar support very small intervals

## Source Evidence

- xbar's core model is executable output to stdout, with refresh timing encoded in the filename and menu rows parsed from text.
- xbar supports clickable/actions parameters such as `shell`, `param`, `terminal`, and `refresh`; Surface should intentionally not implement those action parameters in v1.
- SwiftBar uses the same executable-script/stdout model and documents header/body parsing around `---`, line parameters after `|`, and filename-based refresh intervals.
- SwiftBar's product page validates schedule-based scripts in many languages and examples such as CPU, GitHub PRs, weather, and battery status.
- Übersicht validates desktop command-output widgets, but its widget gallery explicitly warns that widgets can run arbitrary code and should be inspected. Surface should keep script configuration explicit and local.

## Preview Fixtures

Use `Block.Context.storageDirectory`.

Fixture `empty`:

- no config
- expected UI: setup/disabled state

Fixture `ok-output`:

- `scriptoutput-config.json`
- `last-result.json` with exit code 0, stdout:
  ```text
  Repo OK | color=green sfimage=checkmark.circle
  ---
  main clean
  tests passed 44
  open repo | href=file:///Users/example/project
  ```

Fixture `failed-output`:

- config plus last successful result
- latest result with nonzero exit, stderr excerpt, and stale-success marker

## Tests

- Missing config renders disabled/setup state.
- Parser splits header/body on first `---`.
- Parser accepts supported parameters and ignores action-running parameters.
- Command runner uses executable + argument array, not shell string interpolation.
- Timeout kills or marks overdue runs and records stderr/timeout status.
- Output byte caps apply to stdout and stderr.
- Previous successful output remains visible after failure.
- Preview fixture coverage is added to `BlockPreviewTests`.
- Rendered PNGs are nonblank for `empty`, `ok-output`, and `failed-output`.

## Explicit Non-Goals

- No script directory watcher.
- No plugin repository or marketplace.
- No arbitrary click actions in v1.
- No metadata variable UI.
- No xbar:// control API.
- No nested menu emulation beyond simple rows.
- No background execution outside `BlockRuntime`.
