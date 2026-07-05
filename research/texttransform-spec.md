# `texttransform` Plugin Spec

## Why This Matters

Text transforms are high-frequency: clean copied text, turn a title into a slug, encode/decode a URL, escape a JSON string, wrap a Markdown link, or normalize whitespace. Raycast-style transform extensions validate the workflow, but they often read selection and paste back into the active app. That would pull Surface into Accessibility, keyboard automation, and another command runner.

The useful Surface version is explicit and deterministic: take fixture text, pasted text, or an explicit clipboard read; run a small built-in transform; show the output; copy the result. It should not mutate the active app or run user scripts.

## Existing Owner / Dedup Decision

- Copy History owns passive clipboard history and clipboard capture.
- `snippetprompt` owns reusable templates, placeholders, argument fields, and template libraries.
- `scriptoutput` owns custom scripts, shell commands, stdout/stderr, intervals, and arbitrary executable output.
- `contextcard` owns selected/front-app context and any future active-app selected text capture.
- `aicommandscratchpad` owns AI prompt assembly and model/provider output.
- `permissionsdashboard` owns Accessibility/Input Monitoring permission surfaces.
- `texttransform` owns only built-in deterministic text transforms over explicit input, preview fixtures, and copy/open output actions.

Do not add global hotkeys, input monitoring, selected-text scraping, active-app paste/replace, AI rewriting, custom JavaScript/Python/shell transforms, regex editor, template library, clipboard history, or second plugin registry. Implement as one `BlockRuntime` using `Block.Context.storageDirectory` and `Block.Context.now`.

## Product Boundary

It should:

- Read fixture/default input from `texttransform-state.json`.
- Allow a user to paste/type text into the block.
- Optionally read the current pasteboard string only from an explicit button.
- Run a curated built-in transform list.
- Show input length, output length, and warnings/errors.
- Copy output, copy Markdown-wrapped output, or clear local input.
- Persist only lightweight last-input/last-operation state if needed.

It should not:

- Watch clipboard changes passively.
- Store a separate clipboard history.
- Read selected text from other apps in v1.
- Paste/replace text in the active app.
- Run shell commands, scripts, JavaScript, AppleScript, Shortcuts, or Automator services.
- Call AI APIs or on-device model APIs.
- Fetch network metadata.
- Add user-defined regex or programmable transform pipelines in v1.
- Duplicate `snippetprompt` templates or `scriptoutput` runners.

## First Version

### Data Modes

Fixture mode:

1. Read `Block.Context.storageDirectory/texttransform-state.json`.
2. Use built-in deterministic transforms only.
3. Do not read or write the real pasteboard.
4. Copy actions are preview no-ops.

Live mode:

1. Load optional state from `~/Library/Application Support/Surface/TextTransform/texttransform-state.json`.
2. Read the pasteboard only when the user selects `Use clipboard`.
3. Write to pasteboard only when the user selects `Copy output`.
4. Keep active-app insertion out of v1.

### State File

```json
{
  "version": 1,
  "updatedAt": "2026-06-22T01:52:23Z",
  "input": "Example Title: Surface Plugin Ideas",
  "selectedTransform": "slugify",
  "recentTransforms": ["plainText", "trimWhitespace", "slugify", "urlEncode", "jsonString"]
}
```

### Built-In Transform Set

Start with deterministic local transforms:

- `plainText`: normalize to plain UTF-8 string.
- `trimWhitespace`: trim leading/trailing whitespace and newlines.
- `collapseWhitespace`: collapse consecutive whitespace to one space.
- `lowercase`
- `uppercase`
- `titleCase`
- `slugify`: strip diacritics, lowercase, replace non-alphanumeric runs with `-`, trim `-`.
- `urlEncode`
- `urlDecode`
- `base64Encode`
- `base64DecodeUtf8`
- `jsonString`: JSON-escape the input as a single string.
- `markdownQuote`
- `markdownCodeFence`
- `markdownLinkFromClipboardUrl`: later, only when a URL is explicitly supplied.

Deferred:

- Custom regex find/replace.
- Multi-step pipelines.
- HTML sanitization.
- Shell/API transforms.
- AI rewrite/summarize.
- Active-app replacement.

### Local Data Model

```swift
struct TextTransformState: Codable, Equatable {
    var version: Int
    var updatedAt: Date
    var input: String
    var selectedTransform: TextTransformID
    var recentTransforms: [TextTransformID]
}

enum TextTransformID: String, Codable, CaseIterable {
    case plainText
    case trimWhitespace
    case collapseWhitespace
    case lowercase
    case uppercase
    case titleCase
    case slugify
    case urlEncode
    case urlDecode
    case base64Encode
    case base64DecodeUtf8
    case jsonString
    case markdownQuote
    case markdownCodeFence
}

struct TextTransformResult: Equatable {
    var output: String
    var warning: String?
    var error: String?
}
```

## Implementation Notes

Use Foundation and Swift APIs rather than ad hoc string handling where possible:

- `String` / Unicode-aware operations for length and case basics.
- `StringTransform` for diacritic stripping and transliteration where useful.
- `addingPercentEncoding(withAllowedCharacters:)` and `removingPercentEncoding` for URL encode/decode.
- `Data.base64EncodedString()` and `Data(base64Encoded:)` for Base64.
- `JSONSerialization` or `JSONEncoder` for JSON string escaping.
- `NSRegularExpression` only for fixed internal cleanup patterns such as whitespace collapse.

Do not expose arbitrary regular expressions until there is a separate spec for validation, preview safety, and non-catastrophic matching.

## Display Rules

Header:

- `Transform`
- input/output character counts
- selected transform name
- warning/error pill if applicable

Controls:

- segmented transform group: Clean, Case, Encode, Markdown
- compact input preview or text field
- output preview with mono style for encoded/code results
- icon actions: use clipboard, copy output, swap input/output, clear

Sort transforms:

1. recent transforms from state
2. clean/case transforms
3. encode/decode transforms
4. Markdown transforms

Validation:

- Empty input shows an empty state, not an error.
- Base64 decode invalid input returns a visible row error.
- URL decode with no percent escapes returns the original text and a low-severity note.
- JSON escaping output is always deterministic.

## Actions

- Use clipboard as input.
- Copy output to pasteboard.
- Copy output as Markdown code block.
- Replace input with output inside the block only.
- Clear input.

No action should paste into the active app, read selected text, run scripts, run AI, or update Copy History directly. Copy History may observe the pasteboard write through its existing owner path.

## UI Shape

Top region:

- transform selector
- input/output counts
- copy button

Main region:

- input area
- output area
- warning/error row

Empty state:

- `No input`
- show paste/type/use-clipboard actions

Blocked state:

- `Clipboard unavailable` only after an explicit pasteboard read/write action fails.
- Do not ask for Accessibility or Input Monitoring.

## Runtime Shape

Target: `plugins/texttransform/source/Plugin.swift`

Runtime:

1. `start()`: load fixture/live state.
2. `refresh()`: reload state if file-backed.
3. `transform(input:id:)`: pure function with deterministic output.
4. `copyOutput()`: explicit pasteboard write adapter.
5. `stop()`: no-op.
6. `makeView()`: render input/output/actions.

Keep transform functions pure and unit-tested. Reuse/factor pasteboard writing with Copy History or `snippetprompt` only after inspecting both call sites during implementation.

## Fixture Plan

Fixtures:

- `empty`: no input.
- `clean-whitespace`: whitespace collapse/trim.
- `case-and-slug`: case and slug examples with punctuation/diacritics.
- `url-json`: URL encode/decode and JSON escaping examples.
- `base64-error`: invalid Base64 with visible error.
- `markdown`: quote and code fence outputs.

## Test Plan

- Every built-in transform is deterministic.
- Empty input produces empty output with no crash.
- Whitespace collapse handles spaces, tabs, and newlines.
- Slugify strips diacritics and trims separators.
- URL encode/decode use Foundation APIs and report decode notes/errors deterministically.
- Base64 decode invalid data reports an error instead of crashing.
- JSON string escaping round-trips through JSON parsing.
- Fixture mode never reads or writes the real pasteboard.
- No test path reads selected text, uses Accessibility, runs scripts, calls AI APIs, or shells out.
- Preview fixtures render nonblank PNGs through `Blocks.registry`.

## Recommendation

Implement `texttransform` as a small local text utility. It should complement Copy History and `snippetprompt`: explicit input, deterministic transform, explicit copy. Anything programmable belongs in `scriptoutput`; anything AI-generated belongs in `aicommandscratchpad`; anything selected-text/active-app related waits for `contextcard` and permission-gated follow-up work.
