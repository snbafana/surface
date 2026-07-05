# `diagnosticbundle` Plugin Spec

## Decision

Build `diagnosticbundle` as one explicit-export `BlockRuntime` that assembles a local support folder from already-written Surface diagnostic artifacts. It should make it easy to share the current repo/app/plugin state without adding telemetry, a background daemon, broad log collection, or a second plugin registry.

Use the existing `Block` / `BlockRuntime` / `Block.Context` path. The block may copy allowlisted files into a new local bundle folder only from an explicit user action and only when external writes are allowed.

## Existing Owner / Dedup Decision

- `localbuildstatus` owns git/build/test/preview status and runner-written `.build/surface-status` result files.
- `registryhealth` owns generated registry/package/test/fixture health reports.
- `readmehub` owns docs indexes and command/checklist extraction.
- `notificationdigest` owns Surface/plugin-owned event summaries.
- `scriptoutput` owns command execution and external status writers.
- `codexlog` owns Codex thread/action state and local Codex databases; those are sensitive and should not be included by default.
- `block-preview` owns preview PNG generation.
- `diagnosticbundle` owns only an allowlisted export manifest, artifact selection UI, local copy/export folder, redaction report, and copyable summary text.

If implementation needs fresh status files, route that to `scriptoutput`, `localbuildstatus`, `registryhealth`, or an explicit verification script. Do not make `diagnosticbundle` run those producers.

## Product Boundary

It should:

- Read `diagnosticbundle-manifest.json` from `Block.Context.storageDirectory` in previews/tests or Application Support in live mode.
- Show configured artifacts with source plugin, path, kind, size, age, redaction mode, and missing/stale status.
- Export selected artifacts into a new local folder under Application Support or a user-configured destination when the user explicitly clicks export.
- Generate a `summary.md`, `manifest.json`, and `redaction-report.json` inside the bundle folder.
- Copy a Markdown issue/support summary with artifact names, versions, and omitted/redacted counts.
- Reveal the generated folder in Finder.
- Use `Block.Context.now` for stale labels and bundle naming in previews/tests.

It should not:

- Upload, email, AirDrop, or otherwise transmit the bundle.
- Run `swift`, `git`, `log`, `sysdiagnose`, `zip`, shell scripts, package managers, or external CLIs.
- Start a file watcher, log tailer, OpenTelemetry collector, Fluent Bit agent, or background daemon.
- Read unified logs, private Notification Center stores, Keychain, environment variables, browser profiles/history, Contacts, Calendar, clipboard history, or arbitrary home-directory files.
- Include `.codex` session databases/logs by default.
- Recursively scan directories outside explicitly configured artifact roots.
- Compress archives in v1. A folder is the shareable bundle; compression can be a future explicit helper.
- Mutate source plugin stores or mark events read/archived while exporting.
- Create a second registry, diagnostics bus, telemetry pipeline, or crash-reporting service.

## First Version

### Data Modes

Fixture mode:

1. Read `Block.Context.storageDirectory/diagnosticbundle-manifest.json`.
2. Treat all artifact paths as relative to the fixture root.
3. Export only to `Block.Context.storageDirectory/generated-bundles` if writes are allowed.
4. Do not open files, run commands, scan live paths, or read real Application Support.

Live mode:

1. Read `~/Library/Application Support/Surface/DiagnosticBundle/diagnosticbundle-manifest.json` if present.
2. Offer a plugin-local default manifest that points at known Surface status locations only when a repo root is configured.
3. Copy only files listed by the manifest and only when `Block.Context.allowsExternalWrites` is true.
4. Treat missing, oversized, or disallowed files as visible skipped rows.
5. Reveal the generated folder only from explicit user action.

### Manifest File

```json
{
  "version": 1,
  "title": "Surface Support Bundle",
  "repoRoot": "/Users/example/projects/surface",
  "outputDirectory": "~/Library/Application Support/Surface/DiagnosticBundle/Exports",
  "maxArtifactBytes": 5000000,
  "staleAfterHours": 24,
  "artifacts": [
    {
      "id": "last-test",
      "title": "Last Swift test result",
      "source": "localbuildstatus",
      "kind": "status-json",
      "path": ".build/surface-status/last-test.json",
      "redaction": "passthrough",
      "required": false
    },
    {
      "id": "registry-health",
      "title": "Registry health report",
      "source": "registryhealth",
      "kind": "status-json",
      "path": ".build/surface-status/registryhealth.json",
      "redaction": "passthrough",
      "required": false
    },
    {
      "id": "preview-quicksave",
      "title": "Quicksave preview",
      "source": "block-preview",
      "kind": "preview-png",
      "path": ".build/block-previews/quicksave-notes-and-captures.png",
      "redaction": "manual-review",
      "required": false
    }
  ]
}
```

Allowed `kind` values:

- `status-json`
- `event-jsonl`
- `summary-markdown`
- `preview-png`
- `text-log`
- `config-summary`
- `other`

Allowed `redaction` values:

- `passthrough`: include exactly as-is after size/path checks.
- `summary-only`: include only metadata in `summary.md`.
- `redact-known-keys`: parse JSON/JSONL and remove configured sensitive keys.
- `manual-review`: show as selectable but excluded by default.
- `exclude`: never include; show why it was skipped.

### Bundle Folder

Generated folder name:

```text
Surface-Diagnostic-2026-06-24T04-09-52Z/
```

Generated files:

```text
summary.md
manifest.json
redaction-report.json
artifacts/localbuildstatus/last-test.json
artifacts/registryhealth/registryhealth.json
artifacts/previews/quicksave-notes-and-captures.png
```

### Redaction Report

```json
{
  "version": 1,
  "generatedAt": "2026-06-24T04:09:52Z",
  "included": ["last-test", "registry-health"],
  "excluded": [
    {
      "id": "preview-quicksave",
      "reason": "manual-review",
      "path": ".build/block-previews/quicksave-notes-and-captures.png"
    }
  ],
  "redacted": [
    {
      "id": "notification-events",
      "mode": "redact-known-keys",
      "keys": ["detail", "metadata.accessToken"]
    }
  ]
}
```

## Display

Header:

- `Diagnostics`
- artifact count
- included/skipped count
- last export age

Rows:

- title
- source plugin
- kind
- relative path
- file size
- modified age from `Block.Context.now`
- redaction mode
- status: ready, stale, missing, oversized, excluded, manual review
- fixed icon buttons: include/exclude toggle, copy path, open/reveal source file, reveal exported bundle

Sections:

- Ready
- Needs Review
- Missing or Stale
- Last Export

Keep the view compact and explicit. A user should know exactly what will be copied before export.

## Actions

- Toggle include/exclude for optional artifacts locally.
- Export selected artifacts to a local folder.
- Reveal exported folder.
- Copy exported folder path.
- Copy `summary.md` contents.
- Copy a GitHub issue-form-friendly Markdown summary.
- Open/reveal one source artifact.

No action should upload, run commands, collect fresh logs, tail files, compress archives, or mutate source plugin stores.

## Source Evidence

- Surface `localbuildstatus` already defines `.build/surface-status` as the external-runner-owned status directory for build/test/preview JSON and logs.
- Surface `registryhealth` already defines a generated status report for registry/package/test/fixture health. `diagnosticbundle` should include that report rather than recompute health.
- Surface `notificationdigest` already owns local Surface/plugin event summaries and explicitly excludes macOS-wide notification scraping and unified-log mining.
- Surface's run script can stream logs with `log stream`, but that is an interactive command path; `diagnosticbundle` should not run it.
- GitHub issue forms show that structured, required diagnostic fields improve issue intake; the bundle should copy issue-summary Markdown rather than submit anything.
- Sentry's data-scrubbing guidance reinforces redacting sensitive data before data leaves the local process or storage boundary.
- Apple OSLog privacy docs reinforce that logs may contain sensitive values and should use privacy controls; Surface should not collect private unified logs by default.
- Apple privacy manifests document app data collection categories and purposes; any future upload/telemetry path would need separate privacy review and is out of v1.
- OpenTelemetry log collection supports file tailing, directory watching, and collectors; that is exactly the pipeline `diagnosticbundle` should avoid.
- Apple sysdiagnose is a broad system diagnostic archive; Surface should not trigger or include sysdiagnose output in v1.

## Preview Fixtures

Use `Block.Context.storageDirectory`.

- `empty`: no manifest.
- `ready-artifacts`: status JSON, registry report, and docs summary ready to export.
- `stale-and-missing`: stale test result and missing registry report.
- `manual-review`: preview PNG and text log excluded by default.
- `redacted-events`: notification JSONL with known keys redacted in the report.
- `oversized`: artifact larger than `maxArtifactBytes`.
- `export-disabled`: ready artifacts but external writes disabled.

## Tests

- Decode a valid manifest.
- Fall back to disabled/empty state when no manifest exists.
- Resolve relative paths under configured repo root and reject path traversal.
- Classify missing, stale, oversized, excluded, and manual-review artifacts.
- Export selected files only when external writes are allowed.
- Write `summary.md`, `manifest.json`, and `redaction-report.json` deterministically with `Block.Context.now`.
- Redact configured JSON/JSONL keys and report redaction counts.
- Never run shell commands, `log`, `sysdiagnose`, `git`, `swift`, or compression tools.
- Add preview coverage for every fixture and include `diagnosticbundle` in `BlockPreviewTests`.

## Implementation Notes

- Start with plain Codable manifest/report models local to the plugin.
- Use `FileManager` copy operations only.
- Keep unknown files summary-only or manual-review by default.
- Prefer source-plugin summaries over raw logs whenever possible.
- If compression becomes necessary later, route it through an explicit helper or Finder action rather than hidden shell execution.
