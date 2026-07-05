# `diagnosticbundleredactionkeys` Spec

## Decision

Do not build `diagnosticbundleredactionkeys` as a Surface plugin, generic scrubber, telemetry sanitizer, or second redaction registry. Implement it as the first fixed redaction map and summary/report format inside the existing `diagnosticbundle` exporter.

Use the existing `Block` / `BlockRuntime` / `Block.Context` path through `diagnosticbundle`. Redaction applies only to artifacts already listed in `diagnosticbundle-manifest.json` and only during an explicit local export.

## Existing Owner / Dedup Decision

- `diagnosticbundle` owns export selection, redaction modes, generated bundle folders, `summary.md`, and `redaction-report.json`.
- `crashattachmentpolicy` owns the strictest artifact class defaults for crash, dSYM, archive, binary, and symbolication artifacts.
- Source plugins own safer summary artifacts. `diagnosticbundle` should prefer those summaries over parsing raw logs or crash files.
- `diagnosticbundleredactionkeys` owns only fixed key names, fixed path display rules, replacement tokens, and exact summary/report formatting.

Do not introduce per-plugin redaction DSLs, a sanitizer service, regex packs, AI scrubbing, or upload-time scrubbing. If an artifact cannot be safely redacted with the fixed map, classify it as `manual-review` or `summary-only`.

## Product Boundary

It should:

- Define a policy version: `diagnosticbundle-redaction-v1`.
- Apply `redact-known-keys` to JSON and JSONL artifacts only.
- Replace known values with deterministic tokens rather than deleting fields.
- Home-relativize and repo-relativize path values in exported summaries.
- Record redaction counts and key paths in `redaction-report.json`.
- Keep the exported `summary.md` useful without raw private paths, tokens, environment values, crash registers, or full local context.
- Use `Block.Context.now` for deterministic generated timestamps in previews/tests.

It should not:

- Add a `diagnosticbundleredactionkeys` `BlockRuntime`, registry entry, daemon, service, second manifest, second registry, or standalone sanitizer package.
- Try to redact arbitrary unstructured text logs, crash reports, SQLite databases, binary files, images, PDFs, app bundles, dSYM bundles, or archives.
- Recursively scan artifact directories or source plugin stores.
- Parse `.ips` / `.crash` internals in `diagnosticbundle`; use `crashreports` summaries instead.
- Use broad regular expressions over whole artifacts in v1.
- Store original redacted values in reports, logs, previews, or export metadata.
- Upload, attach, compress, or transmit the bundle.

## First Version

### Redaction Mode Behavior

- `passthrough`: copy the artifact exactly after size/path checks.
- `summary-only`: do not copy the artifact; include only manifest metadata in `summary.md`.
- `redact-known-keys`: parse JSON or JSONL, replace known values, write the redacted copy, and report counts.
- `manual-review`: show as selectable but excluded by default.
- `exclude`: never include; report the policy reason.

If `redact-known-keys` is requested for a non-JSON/JSONL file, skip the artifact with reason `redaction-unsupported-format`. Do not fall back to raw passthrough.

### Exact Key Map

Match exact object keys case-insensitively after trimming surrounding whitespace. Do not substring-match, stem, fuzzy-match, or scan arbitrary value text.

Secret keys use replacement token `[redacted:secret]`:

- `accessToken`
- `apiKey`
- `authToken`
- `authorization`
- `bearerToken`
- `clientSecret`
- `cookie`
- `credentials`
- `password`
- `passwd`
- `privateKey`
- `refreshToken`
- `secret`
- `sessionCookie`
- `signingKey`
- `token`
- `webhookSecret`

Identity keys use replacement token `[redacted:identity]`:

- `crashReporterKey`
- `deviceIdentifier`
- `email`
- `hostname`
- `incidentIdentifier`
- `ipAddress`
- `phone`
- `user`
- `userEmail`
- `userID`
- `username`

Path keys use path-display normalization first, then replacement token `[redacted:path]` only when the path is outside known safe roots:

- `archivePath`
- `appBundlePath`
- `cwd`
- `dSYMPath`
- `executablePath`
- `homePath`
- `path`
- `repoRoot`
- `rollout_path`
- `source_note_path`
- `sourcePath`
- `target_path`

Local-context keys use replacement token `[redacted:local-context]`:

- `arguments`
- `env`
- `environment`
- `launchArguments`
- `metadata`
- `processInfo`
- `userInfo`

Crash-detail keys use replacement token `[redacted:crash-detail]`:

- `binaryImages`
- `frames`
- `memory`
- `registers`
- `threadState`
- `threads`

For object or array values, replace the whole value with the category token. For scalar values, replace the scalar value with the token string. Preserve the containing key so exported JSON remains inspectable.

### Exact Dotted Paths

Also match these exact dotted paths, case-sensitive, before generic key matching:

- `detail.metadata.accessToken`
- `detail.metadata.authToken`
- `detail.metadata.apiKey`
- `detail.metadata.email`
- `detail.metadata.user`
- `metadata.accessToken`
- `metadata.authToken`
- `metadata.apiKey`
- `metadata.email`
- `metadata.user`
- `user.email`
- `user.name`

Dotted path rules use the same replacement categories as the terminal key. Do not support wildcards in v1.

### Path Display Rules

For `summary.md`, copied issue summaries, and redacted JSON path values:

1. If a path is under `repoRoot`, display `${repoRoot}/relative/path`.
2. Else if a path is under the current user's home directory, display `~/relative/path`.
3. Else if a path is under the fixture storage directory, display `${fixture}/relative/path`.
4. Else if a path is relative and does not contain `..`, keep it as-is.
5. Else replace it with `[redacted:path]`.

Do not expand `~`, environment variables, globs, or symlinks while redacting. Path normalization is for display only.

### URL Display Rules

For URL-like string values under path or metadata keys:

- Strip query and fragment by default.
- If the URL contains username/password credentials, replace the authority credentials with `[redacted:secret]`.
- Keep scheme, host, and path when they are useful for support.
- Replace unsupported or malformed URLs with `[redacted:url]`.

Do not fetch URLs.

## `summary.md` Format

Generate sections in this order:

```markdown
# Surface Diagnostic Bundle

- Generated: 2026-06-28T18:22:16Z
- Policy: diagnosticbundle-redaction-v1
- Title: Surface Support Bundle
- Repo: ${repoRoot}
- Included: 2
- Redacted: 1
- Skipped: 3

## Included Artifacts

| ID | Source | Kind | Redaction | Path |
| --- | --- | --- | --- | --- |
| registry-health | registryhealth | status-json | passthrough | ${repoRoot}/.build/surface-status/registryhealth.json |
| notification-events | notificationdigest | event-jsonl | redact-known-keys | ${repoRoot}/.build/surface-status/notification-events.jsonl |

## Skipped Artifacts

| ID | Source | Kind | Reason |
| --- | --- | --- | --- |
| raw-crash | crashreports | crash-report | manual-review |
| archive | dsymcatalog | xcode-archive | excluded-by-policy |

## Redactions

| ID | Mode | Count | Keys |
| --- | --- | --- | --- |
| notification-events | redact-known-keys | 4 | detail.metadata.accessToken, email, path |
```

Rules:

- Preserve manifest order inside each table.
- Never include original redacted values.
- Use normalized display paths only.
- If no rows exist for a section, write `None`.
- Keep summary text deterministic for tests.

## `redaction-report.json` Format

```json
{
  "version": 1,
  "policy": "diagnosticbundle-redaction-v1",
  "generatedAt": "2026-06-28T18:22:16Z",
  "included": [
    {
      "id": "notification-events",
      "mode": "redact-known-keys",
      "path": "artifacts/notificationdigest/notification-events.jsonl"
    }
  ],
  "excluded": [
    {
      "id": "raw-crash",
      "kind": "crash-report",
      "reason": "manual-review"
    }
  ],
  "redacted": [
    {
      "id": "notification-events",
      "mode": "redact-known-keys",
      "count": 4,
      "keys": [
        "detail.metadata.accessToken",
        "email",
        "path"
      ],
      "tokens": [
        "[redacted:secret]",
        "[redacted:identity]",
        "[redacted:path]"
      ]
    }
  ]
}
```

Report rows must not include original values, raw path values, stack frames, registers, token prefixes, or value hashes.

## Source Evidence

- `diagnosticbundle-spec.md` already defines the export owner, redaction modes, `summary.md`, `manifest.json`, and `redaction-report.json`.
- `crashattachmentpolicy-spec.md` defines the strictest artifact classes and says raw crash/symbol artifacts should be manual-review or excluded by default.
- OWASP logging guidance identifies sensitive data classes that should be excluded or handled carefully, including session identifiers, access tokens, passwords, and personal data.
- Sentry sensitive-data guidance recommends filtering or scrubbing sensitive data before it is sent or stored and highlights PII, credentials, and confidential data.
- Apple OSLog privacy guidance reinforces marking potentially sensitive logged values as private rather than treating logs as freely shareable.
- Apple privacy manifests reinforce that collection/transmission of diagnostic data would need explicit privacy review, so v1 stays local-export only.

## Fixtures

Use `Block.Context.storageDirectory` through `diagnosticbundle` fixtures.

- `redacted-json`: JSON artifact with secret, identity, path, local-context, and crash-detail keys.
- `redacted-jsonl`: JSONL artifact with one clean row and one row requiring multiple redactions.
- `summary-only`: artifact listed as summary-only and omitted from exported artifacts.
- `unsupported-redaction-format`: text log with `redact-known-keys` skipped as unsupported.
- `path-display`: repo-root, home, fixture, relative, and unsafe absolute path examples.
- `url-display`: URL with query, fragment, and credentials.
- `empty-redaction`: JSON artifact with no matching keys.

## Tests

- Apply exact key redactions case-insensitively.
- Apply exact dotted path redactions before terminal-key redactions.
- Do not redact substring matches or arbitrary value text.
- Replace scalar, object, and array values with deterministic category tokens.
- Normalize repo-root, home, fixture, and safe relative paths.
- Replace unsafe absolute paths with `[redacted:path]`.
- Strip URL query/fragment and redact URL credentials.
- Skip non-JSON/JSONL `redact-known-keys` artifacts with `redaction-unsupported-format`.
- Generate deterministic `summary.md` section order and row order.
- Generate `redaction-report.json` without original values or value hashes.
- Verify raw crash/symbol artifacts still follow `crashattachmentpolicy`.
- Verify no action scans directories, mutates source stores, uploads, compresses, shells out, or adds a second registry.

## Implementation Notes

- Keep the redaction map as local constants beside the future `diagnosticbundle` manifest/report models.
- Prefer `JSONSerialization` or Codable-compatible JSON traversal over string replacement.
- For JSONL, redact each valid JSON object line independently; skip malformed lines with `redaction-parse-failed` rather than copying them raw.
- Treat this as a minimum viable safety layer, not proof that an artifact is safe to publish broadly.
