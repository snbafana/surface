# `crashreports` Plugin Spec

## Decision

Build `crashreports` as one explicit-file `BlockRuntime` that surfaces user-selected crash report pointers and a small parsed summary. It should help a developer notice, open, and summarize local crash artifacts without reading crash directories broadly, collecting telemetry, symbolication, or exporting support bundles.

Use the existing `Block` / `BlockRuntime` / `Block.Context` path. The block may read a manifest of explicit files, load bounded crash-report text/JSON, parse small metadata, and copy/open/reveal those explicit files. It must not scan system crash folders, tail logs, install a crash reporter, upload reports, run symbolication tools, or create a second diagnostics registry.

## Existing Owner / Dedup Decision

- Console and Finder own browsing system diagnostic-report directories.
- Xcode owns deep crash analysis, organizer crash reports, and symbolication workflows.
- MetricKit owns app-integrated crash diagnostic delivery for apps that deliberately adopt it.
- `diagnosticbundle` owns explicit support export and redaction reports.
- `notificationdigest` owns Surface/plugin-owned event summaries.
- `fileinbox` owns broad recent-file triage.
- `scriptoutput` owns command execution and external crash-report producers.
- `permissionsdashboard` owns permission explanation if a future file picker or crash reporter requires extra platform permissions.
- `crashreports` owns only a curated manifest of explicit crash report files, bounded metadata parsing, visible stale/missing states, and copy/open/reveal actions.

If implementation needs to find new crash files, route that to Console/Finder, a future explicit file picker, `fileinbox`, or an external writer that updates `crashreports-index.json`. Do not make `crashreports` scan `~/Library/Logs/DiagnosticReports`, `/Library/Logs/DiagnosticReports`, unified logs, or app containers.

## Product Boundary

It should:

- Read `crashreports-index.json` from `Block.Context.storageDirectory` in previews/tests or Application Support in live mode.
- Accept only manifest-listed files or files under the fixture storage directory.
- Support `.ips` and `.crash` files in v1.
- Parse bounded metadata: process/app name, bundle id, report type, incident id, date, OS version, app version, exception type, termination reason, triggered thread, architecture, and file size/age.
- Show missing, unreadable, unsupported, stale, and parse-warning states without failing the whole block.
- Open or reveal an explicit file on user action.
- Copy absolute path, repo/home-relative path, a terse Markdown crash summary, and a redacted issue-summary snippet.
- Use `Block.Context.now` for relative age and stale labels.

It should not:

- Scan, watch, enumerate, or index system crash report directories.
- Read global unified logs, Console databases, DiagnosticReports folders, app containers, sysdiagnose archives, or arbitrary home-directory paths.
- Install or embed a crash reporter SDK.
- Adopt MetricKit in v1.
- Symbolicate, deobfuscate, demangle, run `atos`, run `symbolicatecrash`, run `xcrun`, run `log`, or invoke Xcode.
- Upload reports, email reports, AirDrop reports, create tickets, or export bundles.
- Mutate, delete, move, redact in place, compress, or archive crash files.
- Parse full thread frames by default or show large binary image lists inline.
- Infer root cause, blame commits, classify security impact, or generate fixes.
- Duplicate `diagnosticbundle` export/redaction, `notificationdigest` events, `fileinbox` broad file triage, or `scriptoutput` command execution.
- Add a second plugin registry or diagnostics bus.

## First Version

### Data Modes

Fixture mode:

1. Read `Block.Context.storageDirectory/crashreports-index.json`.
2. Resolve paths only under `Block.Context.storageDirectory`.
3. Read sample `.ips` and `.crash` files from the fixture tree with a small byte cap.
4. Do not open files, scan live paths, read Application Support, or use Console/Xcode.

Live mode:

1. Read `~/Library/Application Support/Surface/CrashReports/crashreports-index.json` if present.
2. Resolve only manifest entries with absolute paths or paths relative to an explicit repo/support root.
3. Do not enumerate parent directories. Every displayed row must come from the manifest or an explicit handoff from another Surface owner.
4. Treat disallowed, missing, oversized, or unsupported files as visible skipped rows.
5. Open/reveal only from explicit user actions and only when external actions are allowed.

### Index File

```json
{
  "version": 1,
  "title": "Surface Crash Reports",
  "staleAfterHours": 168,
  "maxBytesToParse": 262144,
  "entries": [
    {
      "id": "surface-2026-06-24",
      "title": "Surface crash after Option-E",
      "path": "/Users/example/Library/Logs/DiagnosticReports/Surface-2026-06-24-014252.ips",
      "source": "user-selected",
      "notes": "Opened from Console, kept for local debugging.",
      "tags": ["surface", "option-e"]
    }
  ]
}
```

Allowed `source` values:

- `user-selected`
- `fileinbox`
- `diagnosticbundle`
- `scriptoutput`
- `manual`
- `unknown`

The index is required in v1. Without it, the block renders an empty state with copyable setup instructions rather than scanning for files.

### Parsed Summary

```swift
struct CrashReportSummary: Codable, Equatable, Identifiable {
    var id: String
    var title: String
    var path: String
    var source: String
    var format: CrashReportFormat
    var processName: String?
    var bundleID: String?
    var reportType: String?
    var incidentID: String?
    var reportDate: Date?
    var osVersion: String?
    var appVersion: String?
    var architecture: String?
    var exceptionType: String?
    var terminationReason: String?
    var triggeredThread: String?
    var byteCount: Int?
    var modifiedAt: Date?
    var status: CrashReportStatus
    var warnings: [String]
}
```

Allowed formats:

- `ipsJSON`
- `legacyCrashText`
- `unsupported`

Allowed statuses:

- `ready`
- `stale`
- `missing`
- `unreadable`
- `oversized`
- `unsupported`
- `parseWarning`

### Parsing Rules

- For `.ips`, parse JSON when possible and extract only top-level metadata and known diagnostic sections.
- For `.crash`, parse stable header lines such as process, identifier, version, code type, date/time, OS version, exception type, termination reason, and triggered thread.
- Cap bytes read using `maxBytesToParse`; large files should still show file metadata and an `oversized` warning.
- Never include full stack frames or binary image lists in the default row. Show counts or a collapsed `has frames` signal only if parsed cheaply.
- Prefer lossy metadata over brittle whole-file parsing. A parse warning should not hide the file.
- Treat crash text as sensitive. Copy summaries should omit device identifiers, paths inside other users' home directories, thread registers, and raw memory addresses by default.

## Display

Header:

- `Crashes`
- ready count
- warning count
- latest report age

Rows:

- process/app name or title
- report date and modified age
- exception type
- termination reason
- OS/app version if present
- source chip
- status chip
- fixed icon buttons: open, reveal, copy path, copy summary, copy issue snippet

Sections:

- Recent Reports
- Warnings
- Missing or Unsupported

Keep rows compact. The block should answer "what crash files did I keep, and what are the top fields?" It should not become a crash-log reader.

## Actions

- Open explicit crash report file.
- Reveal explicit crash report file.
- Copy absolute path.
- Copy home-relative path.
- Copy single Markdown summary.
- Copy visible crash report summaries as Markdown.
- Copy a redacted issue-summary snippet.
- Open Diagnostic Bundle when export is needed, if that plugin is available.

No action should scan for reports, run commands, symbolicate, mutate files, export bundles, upload, or request telemetry permissions.

## Source Evidence

- Apple Xcode documentation describes crash reports as detailed logs of an app's state at crash time and positions them as inputs for diagnosing crashes.
- Apple crash-report field documentation identifies stable sections such as process details, threads, exception data, termination data, and binary images. `crashreports` should expose only the small summary fields, not replicate Xcode.
- Apple's JSON crash-report documentation confirms modern crash reports have structured objects for OS version, bundle, exception, termination, threads, frames, and binary images.
- Apple Console documentation lists Crash Reports as system and user reports, with `.ips` report names. This supports file pointers, but Console should remain the directory browser.
- Apple acquiring-crash-reports documentation supports crash reports as explicit artifacts developers obtain from device/user workflows. Surface should consume explicit artifacts, not silently collect.
- MetricKit exposes app-owned crash diagnostics for apps that intentionally adopt it. That is a separate integration path and not v1.
- `diagnosticbundle` already owns support export and redaction reports.
- `notificationdigest` already excludes global unified-log mining and macOS-wide notification scraping.
- `fileinbox` already owns recent-file triage. `crashreports` should not become a second file inbox over DiagnosticReports.

## Preview Fixtures

Use `Block.Context.storageDirectory`.

- `empty`: no index file.
- `mixed-reports`: one `.ips`, one `.crash`, one missing path.
- `parse-warning`: malformed but readable report.
- `stale-reports`: old modified dates beyond `staleAfterHours`.
- `oversized`: file larger than `maxBytesToParse`.
- `unsupported`: `.spin` or `.log` entry shown as unsupported.
- `external-actions-disabled`: valid rows with open/reveal disabled.

## Tests

- Decode a valid index.
- Reject path traversal and ignore non-manifest files.
- Parse representative `.ips` metadata.
- Parse representative legacy `.crash` header metadata.
- Classify missing, unreadable, oversized, unsupported, stale, and parse-warning rows.
- Copy summaries omit raw stack frames, registers, memory addresses, and full binary image lists.
- Open/reveal actions stay disabled when external actions are not allowed.
- Verify the runtime never enumerates DiagnosticReports directories, runs shell commands, touches unified logs, calls MetricKit, mutates crash files, or exports bundles.
- Add preview coverage for every fixture and include `crashreports` in `BlockPreviewTests`.

## Implementation Notes

- Start with a plugin-local Codable index model and small parser functions.
- Keep file reads bounded and non-recursive.
- Treat all crash report contents as sensitive local diagnostics.
- If symbolication becomes important, spec it as an explicit external tool or Xcode handoff first.
- If app-integrated crash collection becomes important, spec MetricKit separately and route summarized events into `notificationdigest`.
