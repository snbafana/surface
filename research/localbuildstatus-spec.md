# `localbuildstatus` Plugin Spec

## Decision

Build `localbuildstatus` as one read-only repo dashboard `BlockRuntime`. It may read git metadata and runner-written result files, but it must not run builds, tests, previews, package managers, or arbitrary scripts itself.

## Dedupe Boundary

- `scriptoutput` owns scheduled command execution. Do not duplicate that command runner for build/test commands.
- Codex Log owns Codex thread/process state. Do not turn build status into another Codex activity panel.
- Surface's README already defines the local verification vocabulary: `swift test`, focused test filters, block previews, and `script/build_and_run.sh --verify`.
- `localbuildstatus` owns only parsing and rendering:
  - git branch/dirty/ahead-behind state
  - last build/test/preview result files
  - links/copy actions for rerunning commands elsewhere

## Product Shape

Surface should show the repo's current engineering status:

- branch name, upstream, ahead/behind counts
- dirty state split into modified/staged/untracked/conflicted counts
- latest commit short SHA
- last build result
- last test result
- last block-preview result
- age of each result relative to `Block.Context.now`
- quick actions: reveal repo, copy test command, copy preview command, open log artifact

The block should answer "is this repo healthy enough to keep working?" without starting expensive work from the overlay.

## Live Data Sources

1. Config:
   - previews/tests: `Block.Context.storageDirectory/localbuildstatus-config.json`
   - live: `~/Library/Application Support/Surface/LocalBuildStatus/localbuildstatus-config.json`
2. Git metadata:
   - `git -C <repoPath> status --porcelain=v2 --branch`
   - optional fallback: `git -C <repoPath> rev-parse --show-toplevel`
   - optional fallback: `git -C <repoPath> branch --show-current`
3. Result files written by an external runner:
   - default directory: `<repoPath>/.build/surface-status`
   - `last-build.json`
   - `last-test.json`
   - `last-preview.json`
   - optional `last-run.json` for a single combined verification pass

This repo already ignores `.build/`, so `.build/surface-status` is a good default for transient local status artifacts.

## Config Schema

```json
{
  "version": 1,
  "title": "Surface",
  "repoPath": "/Users/example/projects/surface",
  "resultDirectory": ".build/surface-status",
  "commands": {
    "build": "swift build",
    "test": "swift test",
    "preview": "swift run block-preview all --output .build/block-previews",
    "verify": "./script/build_and_run.sh --verify"
  }
}
```

`resultDirectory` may be relative to `repoPath`.

## Result File Schema

```json
{
  "version": 1,
  "kind": "test",
  "status": "passed",
  "command": "swift test",
  "startedAt": "2026-06-21T16:00:00Z",
  "finishedAt": "2026-06-21T16:00:19Z",
  "durationMs": 19000,
  "exitCode": 0,
  "summary": "44 tests passed",
  "counts": {
    "passed": 44,
    "failed": 0,
    "skipped": 0
  },
  "logPath": ".build/surface-status/swift-test.log"
}
```

Allowed `status` values:

- `passed`
- `failed`
- `running`
- `cancelled`
- `unknown`

The writing runner is intentionally external. It can be a shell wrapper, CI sync, `scriptoutput`, or manual command that writes JSON after completion.

## Runtime Behavior

- `start()`: load config, read git snapshot, read result files, and start a lightweight refresh loop.
- `refresh()`: reread git status and result JSON. Do not run build/test commands.
- `stop()`: cancel refresh loop.
- Live execution:
  - read-only git commands are allowed when `Block.Context.allowsLiveProcesses` is true
  - build/test/preview commands are never started by this block
- Previews/tests:
  - use fixture git status text and result JSON from `Block.Context.storageDirectory`
  - do not shell out to git
- If git is missing, repo path is invalid, or not a git worktree, show a blocked state with the configured path and setup action.
- If result files are missing, show `unknown` with copyable command suggestions.

## Source Evidence

- Git `status --porcelain=v2 --branch` is explicitly meant for stable machine parsing and includes branch headers and worktree records.
- Git `rev-parse --show-toplevel` gives the top-level worktree path, useful for validating configured repo paths.
- Git `branch --show-current` gives the current branch name without parsing human status output.
- Swift Package Manager's package-manager docs cover build/test workflows for package-based projects; this repo's `Package.swift` and README make Surface a SwiftPM project.
- Surface's README defines the repo-local validation loop: `swift test`, focused plugin tests, block preview rendering, and `./script/build_and_run.sh --verify`.

## Preview Fixtures

Use `Block.Context.storageDirectory`.

Fixture `empty`:

- no config
- expected UI: setup/disabled state

Fixture `clean-passing`:

- config with `repoPath` pointing at fixture root
- `git-status.txt`:
  ```text
  # branch.oid 1111111111111111111111111111111111111111
  # branch.head main
  # branch.upstream origin/main
  # branch.ab +0 -0
  ```
- `last-build.json`, `last-test.json`, and `last-preview.json` all passed

Fixture `dirty-failing`:

- `git-status.txt` with modified and untracked rows plus `branch.ab +1 -2`
- `last-build.json` passed
- `last-test.json` failed with summary/log excerpt
- missing `last-preview.json`

## Tests

- Missing config renders disabled/setup state.
- Git porcelain v2 parser extracts branch, upstream, ahead, behind, dirty counts, untracked count, conflicted count, and commit OID.
- Result parser handles passed/failed/running/unknown states and relative result directories.
- Missing result files show `unknown` without failing the whole block.
- In fixture context, no git command is executed.
- In live context, only read-only git commands are executed.
- Copy actions return configured command strings; they do not execute them.
- Preview fixture coverage is added to `BlockPreviewTests`.
- Rendered PNGs are nonblank for `empty`, `clean-passing`, and `dirty-failing`.

## Explicit Non-Goals

- No running `swift build`, `swift test`, `xcodebuild`, package managers, or arbitrary commands.
- No CI provider integration.
- No log tailer.
- No background daemon.
- No second script runner.
- No write path except optional future settings edits inside Application Support.
