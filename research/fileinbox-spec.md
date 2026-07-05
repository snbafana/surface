# `fileinbox` Plugin Spec

## Why This Should Be Next

`fileinbox` is local-first and immediately useful for a Surface overlay. The user already works with screenshots, markdown files, PDFs, generated previews, and Scratch project artifacts. A small inbox block can reduce Finder switching without becoming a generic file manager.

## Product Boundary

This is not Hazel and not Dropzone:

- Not Hazel: no rule engine in v1.
- Not Dropzone: no arbitrary action scripting in v1.
- Not Raycast File Search: no global search palette in v1.

It is a scoped recent-file triage block.

## First Version

### Watched Locations

Start with explicit directories:

- Desktop
- Downloads
- Current repo `.build/block-previews`
- Current repo root, filtered to recent Markdown/docs artifacts

Later: configurable directories.

### Row Model

```swift
struct FileInboxItem: Identifiable, Sendable {
    var id: URL { url }
    var url: URL
    var displayName: String
    var kind: FileInboxKind
    var modifiedAt: Date
    var byteCount: Int?
}

enum FileInboxKind: String, Sendable {
    case image
    case pdf
    case markdown
    case text
    case folder
    case other
}
```

### Actions

Use fixed-size icon buttons:

- Reveal in Finder.
- Open.
- Copy path.
- Copy Markdown link.
- Archive to a configured local folder.

The archive action should be disabled until a destination exists. Avoid deletes in v1.

### Runtime

Runtime owner: `plugins/fileinbox/source/Plugin.swift`.

Behavior:

1. `start()`: scan directories.
2. `refresh()`: rescan.
3. `makeView()`: show top N recent files grouped lightly by source/kind.
4. `stop()`: cancel any pending scan task.

Use `Block.Context.storageDirectory` for previews and tests. If storage is set, scan only that fixture directory.

### Preview Fixtures

Fixtures:

- `empty`
- `mixed-files`

Fixture directory contents:

```text
Desktop/Screenshot 2026-06-20 19.15.00.png
Downloads/research-paper.pdf
repo/research/plugin-ideas.md
repo/.build/block-previews/copyhistory-mixed-clipboard.png
```

### UI Shape

Header:

- `File Inbox`
- `8 recent`
- Optional `2 screenshots`

Rows:

- File icon/kind swatch.
- Filename.
- Short parent path.
- Relative modified time.
- Action icons on the right.

## Test Plan

- Fixture scan returns newest files first.
- Hidden/build noise is filtered unless explicitly included.
- Copy Markdown link formats image and non-image links correctly.
- Missing watched directory is ignored.
- Preview fixtures render nonblank.

## Risks

- It can become a broad cleanup automation. Keep v1 to triage actions only.
- It can become too noisy. Cap rows and filter obvious junk.
- It can overlap with Finder/Raycast. Surface's advantage is recent workflow context plus one-click actions.

## Recommendation

Implement after `githubqueue`, or before it if the goal is a credentials-free plugin with immediate visible payoff.
