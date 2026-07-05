# `focus` Plugin Spec

## Decision

Build `focus` as one local timer/state `BlockRuntime`. It should not toggle macOS Focus, block apps/websites, monitor app usage, install Screen Time extensions, or run a background daemon outside the existing block lifecycle.

## Dedupe Boundary

- No existing plugin owns focus sessions or timers.
- Reuse the existing plugin runtime pattern: `start()`, `stop()`, `refresh()`, `makeView()`, `Task.sleep` for lightweight ticking, and `Block.Context.now` for deterministic tests/previews.
- Persist state the same way Copy History does: `Block.Context.storageDirectory` for fixtures/tests, otherwise plugin-local Application Support.
- If completion sounds/notifications are added later, keep them behind explicit settings; do not add a shared notification framework until multiple blocks need it.

## Product Shape

Surface should show a small "now" panel:

- current mode: idle, focus, short break, long break, paused, complete
- goal/title for the current session
- remaining time and progress ring/bar
- completed focus rounds today
- next phase preview
- quick controls: start, pause/resume, skip phase, reset, copy session summary

The first version should feel like a dashboard timer for staying honest, not a restrictive productivity app.

## Live Data Sources

1. `focus-state.json` under:
   - `Block.Context.storageDirectory/focus-state.json` in previews/tests
   - `~/Library/Application Support/Surface/Focus/focus-state.json` live
2. `Block.Context.now` for previews/tests; `Date()` live.
3. Optional later: macOS Focus settings link only. Do not read or mutate system Focus state in v1.

## Source Evidence

- Raycast Timers validates a dependency-free timer surface: start/stop countdowns, saved timers, custom timers, stopwatches, and management commands.
- Raycast Pomodoro validates a focused-work variant with a menu-bar timer; its Do Not Disturb integration is explicitly cross-extension, which supports keeping Surface v1 local-only.
- Apple's macOS Focus docs show that Focus has its own user-managed notification, schedule, app-trigger, and filter settings. Surface should not try to become that settings system.
- Apple's Focus Filters docs show that apps can adapt their own content when a user configures a Focus filter. This is useful later for Surface behavior, but it is not a timer/blocker API for v1.
- Apple's Screen Time API is privacy-sensitive and built around Managed Settings, Family Controls, and Device Activity. Blocking apps/websites would pull Surface into a different permission and entitlement domain.
- Pomodoro-style defaults give useful seed settings, but the block should allow custom durations because deep work does not always fit fixed 25-minute intervals.

## State Schema

```json
{
  "version": 1,
  "mode": "focus",
  "goal": "Draft Surface plugin spec",
  "startedAt": "2026-05-20T19:00:00Z",
  "phaseStartedAt": "2026-05-20T19:00:00Z",
  "phaseEndsAt": "2026-05-20T19:25:00Z",
  "pausedRemainingSeconds": null,
  "completedFocusRoundsToday": 2,
  "settings": {
    "focusMinutes": 25,
    "shortBreakMinutes": 5,
    "longBreakMinutes": 20,
    "roundsBeforeLongBreak": 4,
    "autoStartBreaks": false,
    "autoStartFocus": false
  }
}
```

## Runtime Behavior

- `start()`: load state, normalize expired phases, start a one-second tick task when live.
- `stop()`: cancel the tick task; do not continue timing in a hidden daemon.
- `refresh()`: reload state and derive the current phase from persisted timestamps.
- Starting a focus session writes one state file with the current goal and phase end.
- Pausing stores `pausedRemainingSeconds` and clears/ignores `phaseEndsAt`.
- Resuming recomputes `phaseEndsAt` from the remaining seconds.
- If the app is quit and reopened after a phase end, derive the completed/expired state from timestamps instead of requiring a background process.

## Preview Fixtures

Use `Block.Context.storageDirectory` and fixed `Block.Context.now`.

Fixture `idle`:

- no state file
- expected UI: idle state with default durations and start affordance

Fixture `active-focus`:

- `focus-state.json` with a focus phase ending 12 minutes after fixture `now`
- expected UI: current goal, focus mode, remaining time, progress

Fixture `break-due`:

- `focus-state.json` with a focus phase that ended 2 minutes before fixture `now`
- expected UI: completion/break-due state without requiring a background tick

## Tests

- Loads missing state as idle defaults.
- Persists started sessions to `focus-state.json`.
- Derives remaining time from `phaseEndsAt` and injected `now`.
- Pauses/resumes without time drift in injected-time tests.
- Rolls from fourth completed focus phase to long-break suggestion.
- Preview fixture coverage is added to `BlockPreviewTests`.
- Rendered PNGs are nonblank for `idle`, `active-focus`, and `break-due`.

## Explicit Non-Goals

- No app or website blocking.
- No Screen Time, Family Controls, Managed Settings, or Device Activity integration.
- No macOS Focus toggle or hidden automation.
- No global shortcut capture beyond existing Surface hotkey behavior.
- No cross-plugin timer framework until at least two plugins need it.
