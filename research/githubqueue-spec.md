# `githubqueue` Plugin Spec

## Why This Should Be Next

`githubqueue` is a good first new plugin because it is useful without private browser state, can be fixture-first, and reuses existing developer tooling. It should be a native Surface block, not a new GitHub integration framework.

The first implementation should read from GitHub CLI when live processes are allowed and from fixture JSON when `Block.Context.storageDirectory` is set.

## User Job

Show pull requests that need attention and make the next action one click:

- Open PR in browser.
- Copy PR URL.
- Copy checkout command.
- Show check status.
- Show review/requested-review state.

## First Version

### Runtime

Target: `plugins/githubqueue/source/Plugin.swift`

Runtime behavior:

1. `start()`: load fixture or run `gh pr list`.
2. `refresh()`: reload the list; optionally enrich visible rows with checks.
3. `stop()`: cancel any refresh task.
4. `makeView()`: render the queue.

Do not start a daemon. If polling is needed later, use one `Task` owned by the runtime like Copy History and Codex Log do.

### Live Command

Use a command runner injectable through the runtime for tests.

Initial list command:

```bash
gh pr list --json number,title,url,headRefName,baseRefName,author,isDraft,reviewDecision,updatedAt
```

Optional per-row check command:

```bash
gh pr checks <number> --json name,state,bucket,startedAt,completedAt,link
```

The live runtime should tolerate missing `gh`, unauthenticated `gh`, or non-git directories by rendering a blocked state rather than failing the whole overlay.

### Fixture

Path:

```text
plugins/githubqueue/tests/
tools/block-preview/support/BlockPreviewSupport.swift
```

Fixture file:

```text
github-prs.json
```

Representative rows:

- PR needing review.
- PR with failing checks.
- Draft PR.
- Empty queue.

### UI

Use the same visual language as Codex Log and Copy History:

- Header status pill: `3 PRs`
- Optional issue pill: `1 failing`
- Row title with repo/branch metadata.
- Icon buttons: open, copy URL, copy checkout command.
- Check badge: pass/fail/pending/draft.

Rows should not resize when status changes. Keep fixed icon button dimensions.

## Data Model Sketch

```swift
struct GitHubPullRequest: Identifiable, Decodable, Sendable {
    var id: Int { number }
    var number: Int
    var title: String
    var url: URL
    var headRefName: String
    var baseRefName: String
    var author: GitHubUser
    var isDraft: Bool
    var reviewDecision: String?
    var updatedAt: Date?
    var checks: [GitHubCheck] = []
}

struct GitHubCheck: Decodable, Sendable {
    var name: String
    var state: String
    var bucket: String?
    var link: URL?
}
```

Keep the model private to the plugin until another plugin needs it.

## Test Plan

- `blockCreatesRuntimeAndView`
- Loads fixture JSON.
- Empty fixture renders empty state.
- Missing `gh` or command failure renders blocked state.
- Check buckets map to pass/fail/pending labels.
- Preview coverage: `empty`, `mixed-prs`.

## Open Questions

- Should the first command query only the current repo or a configured list of repos?
- Is `review-requested:@me` the best default, or should it show all open PRs in the current repo?
- Should check enrichment happen automatically or only when a row is selected?

## Recommendation

Start current-repo only. It is easiest to test, avoids config, and matches the local-first Surface pattern. Add multi-repo support only after the single-repo block is useful.
