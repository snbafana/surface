# Context Integration Builds - 2026-07-04

## Selected Builds

1. `activitycontext`
   - Source basis: Coast CLI exposes local screen/activity sessions, top apps, representative frames, current screenshot capture, and OCR/AX commands.
   - Built boundary: show current screen/app, top apps, and recent representative activity segments.
   - Deferred: OCR search UI, screenshot gallery, timeline browser, screen recording permission management, and arbitrary app control.

2. `followupqueue`
   - Source basis: Cued local CLI exposes synced contacts, conversations, messages, unread counts, and relationship patterns.
   - Built boundary: show Cued-derived unread and sent-but-waiting DM rows using local iMessage/Contacts data.
   - Deferred: sending replies, contact enrichment, broad relationship graph, Slack/LinkedIn/WhatsApp until those integrations are healthy.

3. `githubqueue`
   - Source basis: existing research ledger already promotes `githubqueue`; `gh pr list --json ...` is the first live data path and Raycast validates PR triage as a compact developer surface.
   - Built boundary: current-repo PR cards with swipe/arrow navigation, copy URL, copy checkout command, and open PR.
   - Deferred: issue queue, workflow runner, multi-repo config, review submission, comment authoring, and check polling.

## Implementation Rules Confirmed

- Each build is one native `BlockRuntime`.
- No second registry, provider layer, daemon, or marketplace path was added.
- Fixture data loads synchronously through `Block.Context.storageDirectory` for previews/tests.
- Live Coast, Cued, and GitHub reads are gated by `Block.Context.allowsLiveProcesses` and run in runtime-owned background tasks so launch and `Option-E` registration stay responsive.
- External actions are copy/open only and stay guarded by `Block.Context.allowsExternalWrites`.

## Validation

- `swift test` passes with 53 tests.
- `swift run block-preview all --output .build/block-previews` renders 12 fixture PNGs.
- Installed `/Applications/Surface.app` passes `./script/verify_alt_e.sh --idle-seconds 130` with the six-block layout.
