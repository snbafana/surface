# `worktreecards` Plugin Spec

## Decision

Build `worktreecards` as one read-only repo/worktree dashboard `BlockRuntime`. It should show the user's active linked worktrees, branch/dirty state, PR/build summaries, and one-at-a-time open/reveal/copy actions.

Use the existing `Block` / `BlockRuntime` / `Block.Context` path and generated registry. Do not add a git client, build runner, project registry, worktree manager, daemon, or second plugin registry.

## Existing Owner / Dedup Decision

- `githubqueue` owns PR list/check/review data and GitHub CLI interaction.
- `localbuildstatus` owns read-only git status parsing and runner-written build/test/preview result files.
- `fileinbox` owns recent-file scanning and artifact triage.
- `appquicklaunch` owns app/folder/file/URL open/focus/reveal/copy actions.
- `workspacepins` owns curated project cards and workspace refs.
- `scriptoutput` owns command execution.
- `worktreecards` owns only worktree list parsing, local card composition, and explicit row actions over configured worktree refs.

If implementation wants to reuse parsers from `localbuildstatus`, factor the parser only after reading both call sites. Do not create a general Git service.

## Product Boundary

It should:

- Read fixture/config data from `Block.Context.storageDirectory`.
- In live mode, run only read-only git discovery commands when `Block.Context.allowsLiveProcesses` is true.
- Parse `git worktree list --porcelain -z` for linked worktree records.
- Optionally read per-worktree status/result/cache files explicitly configured in the state file.
- Show path, branch, HEAD, locked/prunable/missing state, dirty counts, PR/check summary, build/test/preview summary, and recent file count.
- Support explicit actions: open worktree folder, reveal folder, copy path, copy branch name, copy summary, open PR URL.

It should not:

- Create, add, move, lock, unlock, prune, repair, or remove worktrees.
- Checkout branches, switch branches, merge, rebase, cherry-pick, pull, push, fetch, stage, commit, stash, or resolve conflicts.
- Run builds, tests, previews, package managers, or arbitrary commands.
- Poll continuously or run a background daemon.
- Scan every worktree for recent files.
- Read GitHub directly if `githubqueue` can provide a cache/handoff.
- Mutate `githubqueue`, `localbuildstatus`, `fileinbox`, `appquicklaunch`, or `workspacepins` stores.
- Launch groups of apps or restore sessions.

## First Version

### Data Modes

Fixture mode:

1. Read `Block.Context.storageDirectory/worktreecards-worktrees.json`.
2. Read optional `worktreecards-prs.json`, `worktreecards-builds.json`, and `worktreecards-recent-files.json`.
3. Do not shell out to `git`, `gh`, editors, or `NSWorkspace`.

Live mode:

1. Read `~/Library/Application Support/Surface/WorktreeCards/worktreecards-config.json`.
2. If allowed, run `git -C <repoPath> worktree list --porcelain -z`.
3. For each visible worktree, optionally run `git -C <worktreePath> status --porcelain=v2 --branch` using the same parser shape as `localbuildstatus`.
4. Read result files from explicitly configured relative paths such as `.build/surface-status/last-test.json`.
5. Read PR/recent-file cache files only when the config names them.
6. Use AppKit open/reveal only from explicit user actions and only when external actions are allowed.

### Config File

```json
{
  "version": 1,
  "title": "Surface Worktrees",
  "repoPath": "/Users/example/projects/surface",
  "maxCards": 8,
  "statusMode": "readOnlyGit",
  "resultDirectory": ".build/surface-status",
  "githubQueueCacheURL": "file:///Users/example/Library/Application%20Support/Surface/GitHubQueue/githubqueue-prs.json",
  "recentFilesCacheURL": "file:///Users/example/Library/Application%20Support/Surface/FileInbox/surface-worktree-recent-files.json",
  "preferredAppBundleIdentifier": "com.microsoft.VSCode"
}
```

Allowed `statusMode` values:

- `fixtureOnly`
- `readOnlyGit`
- `cacheOnly`

### Fixture Worktree File

```json
{
  "version": 1,
  "generatedAt": "2026-06-23T04:43:16Z",
  "worktrees": [
    {
      "id": "surface-main",
      "path": "/Users/example/projects/surface",
      "branch": "main",
      "head": "1111111111111111111111111111111111111111",
      "isMain": true,
      "isBare": false,
      "isDetached": false,
      "isLocked": false,
      "lockReason": null,
      "isPrunable": false,
      "prunableReason": null,
      "upstream": "origin/main",
      "ahead": 0,
      "behind": 0,
      "dirty": { "modified": 1, "staged": 0, "untracked": 2, "conflicted": 0 },
      "pr": null,
      "build": { "status": "passed", "summary": "44 tests passed", "finishedAt": "2026-06-23T04:30:00Z" },
      "recentFileCount": 4
    },
    {
      "id": "surface-copy-history",
      "path": "/Users/example/projects/surface-copy-history",
      "branch": "codex/copy-history-rules",
      "head": "2222222222222222222222222222222222222222",
      "isMain": false,
      "isBare": false,
      "isDetached": false,
      "isLocked": true,
      "lockReason": "active review",
      "isPrunable": false,
      "prunableReason": null,
      "upstream": "origin/codex/copy-history-rules",
      "ahead": 2,
      "behind": 0,
      "dirty": { "modified": 0, "staged": 0, "untracked": 0, "conflicted": 0 },
      "pr": { "number": 42, "title": "Copy History Rules", "url": "https://github.com/example/surface/pull/42", "status": "reviewRequested", "checks": "passing" },
      "build": { "status": "failed", "summary": "BlockPreviewTests failed", "finishedAt": "2026-06-23T04:20:00Z" },
      "recentFileCount": 1
    }
  ]
}
```

### Git Parsing

Use `git worktree list --porcelain -z` because Git documents the porcelain format as easy to parse, stable across Git versions/configuration, and safer with `-z` for unusual paths.

Map fields:

- `worktree <path>` -> worktree path
- `HEAD <oid>` -> head
- `branch refs/heads/<name>` -> branch
- `bare` -> bare
- `detached` -> detached
- `locked [reason]` -> locked and optional reason
- `prunable [reason]` -> prunable and optional reason

For per-worktree dirty state, reuse the `localbuildstatus` porcelain v2 parser shape:

- `# branch.head`
- `# branch.upstream`
- `# branch.ab`
- changed rows
- untracked rows
- unmerged/conflict rows

Do not parse human `git status` output.

## Display

Header:

- `Worktrees`
- worktree count
- dirty count
- failing/check attention count

Cards:

- branch name and short path tail
- HEAD short SHA
- main/linked/detached/locked/prunable badges
- dirty summary
- PR number/check/review summary when cache exists
- build/test/preview summary when cache exists
- recent-file count when cache exists
- stale/missing warning rows
- fixed-size icon buttons: open, reveal, copy path, copy branch, copy summary, open PR

Sort:

1. dirty/conflicted/failing worktrees
2. branch with review/requested PR
3. main worktree
4. recently updated cache/build time
5. path title

Keep the card count capped. This is a status surface, not a full git UI.

## Actions

- Open folder through `NSWorkspace.open(_:)` or the eventual `appquicklaunch` opener.
- Reveal folder through `NSWorkspace.activateFileViewerSelecting(_:)`.
- Open PR URL through `NSWorkspace.open(_:)`.
- Copy path.
- Copy branch.
- Copy markdown summary.
- Copy suggested terminal commands only as text, for example `git -C <path> status --short`; never execute them.

No action should mutate git, run a build/test/preview, launch a terminal, or call GitHub write APIs.

## Source Evidence

- Git `worktree list --porcelain -z` is explicitly stable and script-friendly, and exposes locked/prunable/detached/bare state.
- Git worktree mutation commands (`add`, `move`, `remove`, `prune`, `repair`, `lock`, `unlock`) have safety caveats around missing, dirty, locked, portable, and moved worktrees; Surface should not own those mutations in v1.
- Git status porcelain v2 with branch headers already supports the dirty/ahead/behind slice owned by `localbuildstatus`.
- GitHub CLI `gh pr status` summarizes relevant PRs with checks/reviews, while `githubqueue` already owns the narrower PR list/check data path.
- VS Code's CLI can open folders and supports `--reuse-window`, but `worktreecards` should rely on `appquicklaunch`/AppKit open actions rather than running editor CLIs.

## Preview Fixtures

Use `Block.Context.storageDirectory`.

- `empty`: no config/worktrees.
- `multi-worktrees`: main plus two linked worktrees.
- `dirty-failing`: dirty worktree with failing build cache.
- `locked-prunable`: locked and prunable worktree states.
- `pr-linked`: PR/cache rows joined by branch name.
- `read-only`: open/mutation actions disabled where context blocks external actions.

## Tests

- Porcelain worktree parser handles NUL-delimited records.
- Locked/prunable/detached/bare fields map correctly.
- Dirty parser reuses or matches `localbuildstatus` behavior for modified/staged/untracked/conflicted counts.
- Missing worktree path renders warning without crashing.
- PR cache joins only by explicit branch/head fields.
- Build cache joins only from configured result directories.
- Recent-file cache is rendered only when explicitly configured.
- Fixture mode runs no `git`, `gh`, editor, shell, or workspace commands.
- Live mode runs only read-only git commands.
- Actions copy/open/reveal one configured target and never execute git/build commands.
- Preview fixtures render nonblank PNGs and are covered by `BlockPreviewTests`.

## Recommendation

Implement `worktreecards` after `localbuildstatus` and `githubqueue` if reuse matters, or as a fixture-first dashboard if the immediate need is visibility across parallel worktrees. Keep the first version read-only and cache-backed; git mutations stay in the terminal or future explicit specs.
