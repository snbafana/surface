# `snippetprompt` Plugin Spec

## Why This Matters

Snippets and repeated prompts are high-frequency overlay work: support replies, meeting-note templates, bug-report skeletons, review prompts, rewrite prompts, and small code/text templates. Raycast validates this with Snippets, Dynamic Placeholders, Clipboard History handoff, and AI Commands.

Surface should not clone a global text expander. The useful Surface shape is a small local library that renders the right template, resolves safe context, and copies the result so the user can paste it into Codex, Obsidian, email, chat, or a browser.

## Existing Owner / Dedup Decision

- Copy History owns passive clipboard watching and old clipboard entries.
- Link Inbox owns URL-specific capture and link triage.
- Quicksave owns durable capture into files/Obsidian.
- Context Card owns live app/window/selection context.
- Script Output owns command execution and script output parsing.
- `snippetprompt` owns only a local snippet/prompt library, placeholder resolution, and copy/open actions.

Do not add auto-expansion, global keyboard monitoring, an AI runner, script execution, a snippet marketplace, or a second plugin registry. Implement as one `BlockRuntime` using `Block.Context.storageDirectory` for fixtures and local files.

## Product Boundary

It should:

- Read local JSON snippets/prompts.
- Search/filter by title, tags, and kind.
- Resolve a small safe placeholder subset.
- Let the user fill up to three explicit arguments.
- Copy resolved text, copy raw template text, or open/reveal the backing library file.
- Show missing-context states instead of scraping private app state.

It should not:

- Watch all keystrokes or auto-expand typed abbreviations.
- Paste into the frontmost app automatically in v1.
- Read selected text with Accessibility.
- Read browser tabs or page content.
- Run prompts against an AI API.
- Execute shell commands from placeholders.
- Save arbitrary clipboard history as snippets; that remains a Copy History action/later handoff.

## First Version

### Data Sources

Fixture mode:

1. Read `Block.Context.storageDirectory/snippetprompt-library.json`.
2. Optionally read `Block.Context.storageDirectory/snippetprompt-context.json`.
3. Use `Block.Context.now` for date/time placeholders.

Live mode:

1. Read `~/Library/Application Support/Surface/SnippetPrompt/snippetprompt-library.json`.
2. Optionally read `~/Library/Application Support/Surface/SnippetPrompt/snippetprompt-context.json`.
3. Resolve clipboard text only when the user selects a copy action.
4. Do not read live Accessibility, browser, or app-selection state.

The optional context file is an explicit safe bridge for future Context Card work. Until a real shared context owner exists, missing context placeholders should render as `Needs context` rather than triggering live scraping.

### Library Schema

```json
{
  "version": 1,
  "items": [
    {
      "id": "code-review",
      "title": "Code Review",
      "kind": "prompt",
      "tags": ["code", "review"],
      "body": "Review this change for bugs first. Context: {context.title}\\n\\n{clipboard | trim}",
      "arguments": [
        {
          "name": "focus",
          "label": "Focus",
          "defaultValue": "bugs and tests",
          "options": ["bugs and tests", "maintainability", "security"]
        }
      ]
    }
  ]
}
```

Model:

```swift
struct SnippetPromptLibrary: Codable {
    var version: Int
    var items: [SnippetPromptItem]
}

struct SnippetPromptItem: Codable, Identifiable, Equatable {
    var id: String
    var title: String
    var kind: Kind
    var tags: [String]
    var body: String
    var arguments: [SnippetPromptArgument]
}

enum Kind: String, Codable {
    case snippet
    case prompt
}
```

### Placeholder Grammar

Support this safe subset first:

| Placeholder | Source | Notes |
| --- | --- | --- |
| `{date}` | `Block.Context.now` / `Date()` | Localized short date. |
| `{time}` | `Block.Context.now` / `Date()` | Localized short time. |
| `{datetime}` | `Block.Context.now` / `Date()` | Localized date and time. |
| `{iso_datetime}` | `ISO8601DateFormatter` | Stable machine-friendly stamp. |
| `{clipboard}` | `NSPasteboard.general.string(forType: .string)` | Resolve only on explicit copy action. |
| `{argument name="..."}` | block UI field | Max three distinct arguments in v1. |
| `{context.title}` | optional context JSON | Missing value becomes a visible warning. |
| `{context.app}` | optional context JSON | Future Context Card handoff. |
| `{context.url}` | optional context JSON | Future Link Inbox/browser-safe handoff. |

Modifiers:

- `trim`
- `uppercase`
- `lowercase`
- `json-stringify`

Reject or leave unresolved:

- `{selection}`
- `{browser-tab}`
- nested snippets
- shell/script placeholders
- arbitrary expressions
- external network/AI placeholders

This keeps placeholders useful without copying Raycast's global app-control and AI-command surface.

### Context File

Optional fixture/context file:

```json
{
  "title": "Surface plugin research",
  "app": "Codex",
  "url": "file:///Users/snbafana/Documents/personal/Scratch/projects/surface/research/queue.md"
}
```

The file is explicit input. The block should not write it in v1.

### Actions

- Copy resolved text.
- Copy raw template.
- Copy title.
- Open/reveal library file.
- Pin/filter in memory only for v1; persistent reordering can come later.

Paste-to-frontmost-app and in-place replacement require Accessibility and should stay out of v1. If added later, route through `permissionsdashboard`.

## UI Shape

Header:

- `Snippets`
- status pill: `<n> items`, `Needs setup`, or `Needs context`
- small search/filter control

Rows:

- icon for snippet vs prompt
- title
- tag chips
- one-line preview after placeholder validation
- icon actions: copy resolved, copy raw, reveal file

Argument state:

- When a selected item has arguments, show compact text fields or segmented options above actions.
- Keep the selected item's height stable; do not resize rows while typing.

Missing context:

- Show the unresolved placeholder list, such as `context.title`.
- Copy raw template remains available.
- Copy resolved is disabled unless unresolved placeholders have safe defaults.

## Runtime Shape

Target: `plugins/snippetprompt/source/Plugin.swift`

Runtime:

1. `start()`: load library and context fixture/file.
2. `refresh()`: reload files and recompute validation.
3. `stop()`: no-op.
4. `makeView()`: render library, search/filter state, arguments, and copy actions.

Use plugin-local parsing/resolution first. If implementation needs shared pasteboard writing with Copy History, factor a small helper only after inspecting both call sites.

## Fixture Plan

Fixtures:

- `empty`: missing or empty library.
- `mixed-library`: snippets and prompts with tags, date, argument, and clipboard placeholders.
- `needs-context`: prompt with `{context.title}` and no context file.
- `context-ready`: same prompt with `snippetprompt-context.json`.

Example files:

- `snippetprompt-library.json`
- `snippetprompt-context.json`
- `clipboard.txt` for preview-only clipboard placeholder text

Preview rendering should never read the real clipboard. In fixture mode, `{clipboard}` resolves from `clipboard.txt` when present, otherwise it is a visible missing value.

## Test Plan

- Library JSON decode and validation.
- Empty/missing library renders setup state.
- Placeholder parser handles allowed placeholders and flags rejected placeholders.
- Argument placeholders dedupe by name and cap at three.
- Date/time placeholders use `Block.Context.now`.
- Fixture clipboard text is used in preview mode; real pasteboard is not read.
- Copy action writes resolved text through a plugin-local pasteboard abstraction in unit tests.
- Preview fixtures render nonblank PNGs through `Blocks.registry`.

## Recommendation

Implement after one more local-first block or as a small usability plugin before permission-heavy work. The first release should be read/copy only. Context-aware prompts become genuinely useful once `contextcard` has a safe snapshot owner, but `snippetprompt` should not create that owner itself.
