# `dsymcatalog` Spec

## Decision

Do not build `dsymcatalog` as a Surface plugin, symbol store, dSYM scanner, uploader, or downloader. Implement it as an optional explicit manifest that `crashreports` and its `crashsymbolication` extension can read to improve handoff readiness.

Use the existing `Block` / `BlockRuntime` / `Block.Context` path through `crashreports`. The runtime may read a catalog JSON file, match explicit catalog rows against parsed crash-report fields, and show/copy/reveal those explicit paths. It must not scan DerivedData, Xcode Archives, Spotlight, App Store Connect, Sentry, Crashlytics, file systems, or symbol servers.

## Existing Owner / Dedup Decision

- Xcode owns archives, Organizer workflows, preferred crash report symbolication, and any local symbol lookup behavior.
- App Store Connect and Xcode own any hosted/downloaded debug-symbol workflows.
- Apple's command-line tools such as `dwarfdump` and `atos` own manual UUID verification and address lookup when a developer chooses to run them.
- `crashreports` owns explicit crash report pointers and bounded metadata parsing.
- `crashsymbolication` owns readiness chips and copied Xcode/CLI handoff instructions.
- `diagnosticbundle` owns explicit export/redaction of selected crash/symbol artifacts.
- `fileinbox` owns broad file triage.
- `scriptoutput` owns any future explicit command execution or manifest-producing helper.
- `dsymcatalog` owns only an explicit JSON catalog shape, row matching by already-known metadata, reveal/copy actions for explicit paths, and stale/missing status.

If implementation needs to discover dSYMs, route discovery to Xcode, Finder, App Store Connect, a developer-run command, or a `scriptoutput`/external producer that writes the catalog. Do not add discovery inside a block runtime.

## Product Boundary

It should:

- Read `dsymcatalog.json` from `Block.Context.storageDirectory` in previews/tests or Application Support in live mode.
- Let `crashreports` also accept an optional `symbolCatalogPath` in `crashreports-index.json`.
- Match catalog entries to crash reports using explicit fields: bundle id, app version/build, architecture, binary image UUID, executable name, and platform.
- Show `matched`, `possibleMatch`, `missing`, `stale`, `unreadable`, and `pathMissing` states.
- Show explicit app bundle, executable, dSYM, archive, and source fields.
- Copy Xcode handoff Markdown and `atos` command templates using the matched catalog row.
- Reveal explicit paths when external actions are allowed.
- Preserve uncertainty: a UUID match is stronger than version/build text, and text-only matches should render as possible matches.

It should not:

- Add a `dsymcatalog` `BlockRuntime`, registry entry, overlay panel, daemon, watcher, cache service, or symbol registry.
- Scan `~/Library/Developer/Xcode/Archives`, DerivedData, `.build`, `~/Downloads`, Desktop, Spotlight, Time Machine, mounted volumes, or arbitrary folders.
- Run `dwarfdump`, `atos`, `symbolicatecrash`, `xcrun`, `xcodebuild`, `mdfind`, `find`, `log`, shell scripts, or external apps.
- Download dSYMs from App Store Connect, Xcode Cloud, Sentry, Crashlytics, Firebase, or any service.
- Upload dSYMs or crash reports anywhere.
- Parse DWARF, Mach-O, UUID maps, BCSymbolMaps, or archive internals in v1.
- Mutate, move, copy, delete, compress, rename, or rewrite symbol files.
- Treat catalog matches as proof of correct symbolication unless a UUID match is present.
- Duplicate `fileinbox` broad scanning, `scriptoutput` command execution, `diagnosticbundle` export, or `crashsymbolication` handoff text.
- Add a second registry.

## First Version

### Data Modes

Fixture mode:

1. Read `Block.Context.storageDirectory/dsymcatalog.json` if present.
2. Resolve paths only under the fixture storage directory unless the fixture marks them as display-only strings.
3. Do not inspect real app bundles, archives, or dSYM contents.

Live mode:

1. Read `~/Library/Application Support/Surface/CrashReports/dsymcatalog.json` by default.
2. Optionally read a `symbolCatalogPath` referenced by `crashreports-index.json`.
3. Resolve only catalog rows. Never enumerate parent directories.
4. Check only file existence, size, and modification date for explicit paths.
5. Reveal explicit paths only from user actions.

### Catalog File

```json
{
  "version": 1,
  "title": "Surface dSYM Catalog",
  "generatedAt": "2026-06-25T19:54:30Z",
  "source": "manual",
  "entries": [
    {
      "id": "surface-2026-06-24-142",
      "appName": "Surface",
      "bundleID": "com.example.surface",
      "platform": "macOS",
      "appVersion": "1.4.0",
      "buildNumber": "142",
      "architecture": "arm64",
      "executableName": "Surface",
      "binaryImageUUIDs": ["01234567-89AB-CDEF-0123-456789ABCDEF"],
      "archivePath": "/Users/example/Library/Developer/Xcode/Archives/2026-06-24/Surface.xcarchive",
      "appBundlePath": "/Users/example/Library/Developer/Xcode/Archives/2026-06-24/Surface.xcarchive/Products/Applications/Surface.app",
      "executablePath": "/Users/example/Library/Developer/Xcode/Archives/2026-06-24/Surface.xcarchive/Products/Applications/Surface.app/Contents/MacOS/Surface",
      "dSYMPath": "/Users/example/Library/Developer/Xcode/Archives/2026-06-24/Surface.xcarchive/dSYMs/Surface.app.dSYM",
      "notes": "Added manually from the matching Xcode archive."
    }
  ]
}
```

Allowed catalog `source` values:

- `manual`
- `xcode-archive`
- `app-store-connect`
- `scriptoutput`
- `diagnosticbundle`
- `unknown`

All path values are optional but, when present, must be explicit strings. No globbing, tilde expansion, environment expansion, directory recursion, or search syntax.

### Matching Rules

Strong match:

- crash binary image UUID equals one catalog `binaryImageUUIDs` value
- architecture matches if both sides have architecture

Possible match:

- bundle id, app version/build, and executable name match, but no UUID is present
- archive/app/dSYM path exists but UUID is missing from the catalog

No match:

- UUID conflicts
- bundle id conflicts
- architecture conflicts
- catalog entry paths are missing and no metadata matches

Do not guess across apps or products. Ambiguous matches should render as a warning and copy a checklist, not an `atos` command.

### Display

In `crashreports` expanded symbolication detail, add a `Symbols` section:

- match state
- matched catalog row title
- UUIDs
- architecture
- app version/build
- dSYM/archive/app path chips
- stale/missing path warnings
- copy buttons: Xcode handoff, `atos` template, dSYM checklist, catalog row JSON
- reveal buttons for explicit paths

No standalone Surface block is needed.

### Handoff Text

Copied checklist:

```markdown
## Symbol files

- Crash report: `/path/to/Surface.ips`
- Matched catalog row: `surface-2026-06-24-142`
- Bundle ID: `com.example.surface`
- Version/build: `1.4.0 (142)`
- Architecture: `arm64`
- Binary UUID: `01234567-89AB-CDEF-0123-456789ABCDEF`
- Archive: `/path/to/Surface.xcarchive`
- dSYM: `/path/to/Surface.app.dSYM`
- App: `/path/to/Surface.app`

Open the crash report in Xcode with the matching archive or dSYM available.
```

If no strong match exists, copied text should say what is missing instead of producing a command.

## Source Evidence

- Apple crash-report field documentation says binary image UUIDs are used to locate corresponding dSYM files during symbolication.
- Apple symbolication documentation says developers can verify whether a binary or dSYM matches a crash report by comparing build UUIDs with `dwarfdump`.
- Apple documents building apps with `DWARF with dSYM File` to generate the debug information needed for crash reports.
- Apple App Store Connect build metadata documentation includes dSYM download workflows for eligible builds and notes that dSYM availability changed after Xcode 14/bitcode changes.
- Xcode help documents downloading debug symbols through the Archives organizer and inserting dSYM files into the selected archive for bitcode-era workflows.
- `crashsymbolication-spec.md` keeps command execution and symbol lookup outside the runtime and allows copied Xcode/CLI handoffs only.
- `scriptoutput-spec.md` is the existing owner for future explicit command producers.
- `diagnosticbundle-spec.md` is the existing owner for exporting selected symbol/crash artifacts.

## Fixtures

Use `Block.Context.storageDirectory`.

- `empty-catalog`: no `dsymcatalog.json`.
- `uuid-match`: one crash report with a matching UUID catalog row.
- `possible-match`: version/build match without UUID.
- `conflict`: UUID or architecture mismatch.
- `missing-paths`: catalog row points at missing dSYM/archive paths.
- `stale-catalog`: old `generatedAt` and old file modification dates.
- `ambiguous`: two possible rows match the same crash report.
- `external-actions-disabled`: paths render but reveal actions are disabled.

These fixtures belong under `crashreports`; do not add a separate plugin fixture set.

## Tests

- Decode a valid catalog.
- Reject path traversal, glob patterns, tilde expansion, and environment expansion.
- Match by UUID and architecture.
- Classify possible text-only matches.
- Detect UUID, bundle id, and architecture conflicts.
- Classify missing explicit paths.
- Copy Xcode handoff text only from explicit fields.
- Copy `atos` command templates only when a single strong match and required addresses exist through `crashsymbolication`.
- Copy a checklist instead of a command for ambiguous or possible matches.
- Verify no action scans directories, runs commands, downloads dSYMs, uploads symbols, parses DWARF/Mach-O, mutates files, or exports artifacts.

## Implementation Notes

- Keep catalog parsing inside the future `crashreports` implementation.
- Treat the catalog as a helper index, not a source of truth.
- Add only display DTOs and matching functions; do not build a symbol database.
- If catalog generation becomes useful, spec a separate external producer that writes JSON before adding any helper script.
