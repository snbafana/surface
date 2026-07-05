# `crashsymbolication` Spec

## Decision

Do not build `crashsymbolication` as a separate plugin, daemon, or command runner. Implement it as a copy-only handoff extension to `crashreports`: show whether the report has enough explicit symbols context, expose the relevant paths/UUID clues, and copy Xcode or command-line instructions for the developer to run outside Surface.

Use the existing `Block` / `BlockRuntime` / `Block.Context` architecture through `crashreports`. The runtime may parse crash-report metadata and read explicit manifest fields. It must not run `atos`, `symbolicatecrash`, `xcrun`, `dwarfdump`, `xcodebuild`, Xcode, Spotlight searches, or any shell command.

## Existing Owner / Dedup Decision

- Xcode owns preferred crash report symbolication and organizer/archive workflows.
- Apple's command-line tools such as `atos` and `dwarfdump` own specialized manual symbolication when a developer chooses to run them.
- `crashreports` owns explicit crash report pointers, bounded metadata parsing, and copy/open/reveal actions.
- `scriptoutput` owns any future explicit command execution with direct executable paths, timeouts, and output caps.
- `diagnosticbundle` owns exporting selected artifacts and redaction reports.
- `fileinbox` owns broad recent-file triage.
- `crashsymbolication` owns only optional manifest fields, readiness/status display, copied handoff commands, copied Xcode steps, and redacted symbolication notes.

If implementation needs real symbolication output, route it to Xcode or a separate user-configured `scriptoutput` producer that writes a result file. Do not make `crashreports` or a new block execute symbolication tools.

## Product Boundary

It should:

- Extend `crashreports-index.json` with optional symbolication metadata.
- Parse binary image UUIDs and architecture clues from the explicit crash report when already loaded by `crashreports`.
- Show whether required handoff inputs are present: crash file, app bundle or executable, matching dSYM/archive path, architecture, load address, and failing frame address when available.
- Copy Xcode handoff instructions.
- Copy conservative `atos` command templates using explicit manifest fields and parsed addresses.
- Copy a Markdown symbolication checklist.
- Show `unknown`, `readyForXcode`, `readyForAtos`, `missingDSYM`, `missingExecutable`, `missingAddress`, and `alreadySymbolicated` states.
- Keep all actions copy/open/reveal only.

It should not:

- Add a `crashsymbolication` `BlockRuntime`, registry entry, overlay panel, approval queue, daemon, or diagnostics bus.
- Execute `atos`, `symbolicatecrash`, `dwarfdump`, `xcrun`, `xcodebuild`, `mdfind`, `find`, `log`, shell scripts, or external apps.
- Search DerivedData, Archives, DiagnosticReports, Spotlight, Time Machine, build folders, or arbitrary directories for matching dSYMs.
- Download dSYMs from App Store Connect, Xcode Cloud, Sentry, Crashlytics, Firebase, or any service.
- Upload crash reports or dSYMs.
- Mutate, rewrite, redact, move, compress, or symbolicate crash report files in place.
- Store dSYM contents, parse DWARF data, or inspect Mach-O binaries in v1.
- Infer root cause, blame source lines, generate fixes, or classify crash severity.
- Duplicate `scriptoutput` command execution, `diagnosticbundle` export, or `fileinbox` scanning.
- Add a second plugin registry.

## First Version

### Index Extension

Extend each `crashreports-index.json` entry with optional symbolication fields:

```json
{
  "id": "surface-2026-06-24",
  "title": "Surface crash after Option-E",
  "path": "/Users/example/Library/Logs/DiagnosticReports/Surface-2026-06-24-014252.ips",
  "source": "user-selected",
  "symbolication": {
    "appBundlePath": "/Users/example/Library/Developer/Xcode/Archives/2026-06-24/Surface.xcarchive/Products/Applications/Surface.app",
    "executablePath": "/Users/example/Library/Developer/Xcode/Archives/2026-06-24/Surface.xcarchive/Products/Applications/Surface.app/Contents/MacOS/Surface",
    "dSYMPath": "/Users/example/Library/Developer/Xcode/Archives/2026-06-24/Surface.xcarchive/dSYMs/Surface.app.dSYM",
    "archivePath": "/Users/example/Library/Developer/Xcode/Archives/2026-06-24/Surface.xcarchive",
    "architecture": "arm64",
    "binaryImageUUID": "01234567-89AB-CDEF-0123-456789ABCDEF",
    "loadAddress": "0x100000000",
    "frameAddresses": ["0x1000abcde"],
    "notes": "Paths were selected manually from the matching archive."
  }
}
```

Every path must be explicit. No path field should cause directory enumeration.

### Status Rules

- `alreadySymbolicated`: top frames already include function names or source locations.
- `readyForXcode`: crash file plus archive/app/dSYM path exists in the manifest.
- `readyForAtos`: executable or dSYM path, architecture, load address, and at least one frame address are present.
- `missingDSYM`: crash report is unsymbolicated and no dSYM/archive path is explicit.
- `missingExecutable`: `atos` handoff lacks an executable/app path.
- `missingAddress`: `atos` handoff lacks load address or frame addresses.
- `unknown`: report cannot be classified from bounded metadata.

These states are handoff quality labels, not proof that symbols match. Matching dSYMs requires tool execution or deeper binary inspection, which is out of scope.

### Copied Xcode Handoff

The copied Xcode handoff should be plain Markdown:

```markdown
## Symbolicate in Xcode

- Crash report: `/path/to/Surface.ips`
- Archive: `/path/to/Surface.xcarchive`
- dSYM: `/path/to/Surface.app.dSYM`
- App: `/path/to/Surface.app`
- Binary UUID from crash: `01234567-89AB-CDEF-0123-456789ABCDEF`

Open the crash report in Xcode and make sure the matching archive/dSYM is available locally.
```

### Copied `atos` Template

Copy only a template, never execute it:

```bash
xcrun atos -arch arm64 -o "/path/to/Surface.app.dSYM/Contents/Resources/DWARF/Surface" -l 0x100000000 0x1000abcde
```

When fields are missing, copy a checklist instead of a partial command.

### Display

In `crashreports` rows, add a compact symbolication chip:

- `symbolicated`
- `ready for Xcode`
- `ready for atos`
- `needs dSYM`
- `needs executable`
- `needs address`
- `unknown`

Expanded detail:

- binary UUID
- architecture
- app version/build if parsed
- explicit dSYM/archive/app path labels
- copy buttons: Xcode steps, `atos` template, checklist
- reveal buttons for explicit manifest files

## Source Evidence

- Apple says Xcode is the preferred way to symbolicate crash reports because it can use available dSYM files on the Mac.
- Apple documents command-line symbolication as a specialized path and points to `atos` for manual address-to-symbol lookup.
- Apple documents building distribution apps with `DWARF with dSYM File` so the necessary debug symbols are generated.
- Apple crash report field documentation uses binary image UUIDs and crash fields to connect reports to matching symbols.
- `crashreports-spec.md` explicitly excludes running `atos`, `symbolicatecrash`, `xcrun`, `log`, or Xcode from the block runtime.
- `scriptoutput-spec.md` already defines the safe owner for future command execution: direct executable path, argument array, timeouts, and byte caps.
- `diagnosticbundle-spec.md` owns export/redaction if the user later needs to share crash reports, dSYMs, or symbolication outputs.

## Tests

- Decode optional symbolication fields from `crashreports-index.json`.
- Reject path traversal and non-explicit path expansion.
- Classify already-symbolicated reports.
- Classify ready/missing states from manifest fields and parsed crash metadata.
- Copy Xcode handoff Markdown with explicit paths only.
- Copy an `atos` command template only when architecture, binary path, load address, and frame address are present.
- Copy a checklist instead of a broken command when required fields are missing.
- Verify no action executes commands, searches directories, opens Xcode automatically, inspects dSYM contents, mutates files, or exports artifacts.
- Add preview coverage through `crashreports` fixtures rather than a new plugin fixture set.

## Implementation Notes

- Keep this inside the future `crashreports` implementation.
- Prefer display DTOs and copied text builders over a generalized command model.
- If the user later wants one-click symbolication, require a separate explicit `scriptoutput` configuration or external producer first.
- If matching dSYM discovery matters, spec a manifest-producing helper outside Surface before adding any scanning behavior.
