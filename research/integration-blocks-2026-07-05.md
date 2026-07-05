# Integration Blocks Research - 2026-07-05

Goal: turn Browserbase, integrations.sh, and Steipete-style agent tooling into better Surface blocks without adding a second registry, credential store, or automation runner.

## Source Facts

- Browserbase docs now describe `browse` as the current unified CLI for browser automation, cloud APIs, Functions, skills, and templates. It supports commands like `browse open`, `snapshot`, `click`, `fill`, `screenshot`, `browse cloud ...`, `browse functions ...`, and `browse skills ...`; remote Browserbase commands require `BROWSERBASE_API_KEY`. Source: https://docs.browserbase.com/integrations/skills/browse-cli
- Browserbase session observability includes dashboard session inspector, live view, automatic video recordings, network/console logs, status metadata, and session log APIs. Source: https://docs.browserbase.com/platform/browser/observability/observability
- Browserbase session recordings are automatically available after sessions, video remains supported, and rrweb DOM replay is being deprecated. Source: https://docs.browserbase.com/platform/browser/observability/session-recording
- The older `@browserbasehq/cli` npm package exposes the `bb` binary and describes itself as Browserbase CLI for platform APIs, functions, and browse passthrough. Treat `bb` as legacy/optional beside `browse`. Source: https://www.npmjs.com/package/@browserbasehq/cli
- integrations.sh is a public catalog of agent-ready service surfaces across MCP, OpenAPI, GraphQL, and CLI, with `/api/search`, `/api/{domain}/detect`, and `/api/{domain}/discover` in its OpenAPI document. Source: https://integrations.sh/openapi.json
- The attached Steipete profile/repo list highlights useful block patterns: Peekaboo for macOS screenshots/GUI automation, CodexBar/RepoBar for menu-bar status, mcporter for MCP-as-CLI packaging, oracle for higher-power review handoff, browser cookie plumbing, and local-first crawler archives.

## Implemented Now: `integrationhub`

`integrationhub` is a read-only readiness block:

- Checks local executable availability for `browse`, `bb`, `coast`, `cued`, `gh`, and a small Steipete-inspired toolbelt probe.
- Separates Browserbase CLI installation from `BROWSERBASE_API_KEY` availability.
- Includes integrations.sh as a catalog/API source with a copyable search command.
- Uses fixture JSON for previews/tests.
- Allows only explicit copy/open actions.
- Does not run Browserbase automation, call integrations.sh, store credentials, install tools, or create a second registry.

## Top Three Next Blocks

| Rank | Block | Why It Matters | V1 Boundary |
| --- | --- | --- | --- |
| 1 | Browserbase Session Cards | Browserbase recordings/live view/logs are directly useful when testing agents or browser tasks. Surface can show session IDs, status, started/duration, recording URL, and copy/open actions. | Read cached/fixture `browserbase-sessions.json` or explicit external writer output. Do not create sessions, run `browse`, fetch logs, or store `BROWSERBASE_API_KEY` in Surface. |
| 2 | Integration Catalog Finder | integrations.sh can answer "what can this service expose to agents?" across MCP/API/GraphQL/CLI. This is valuable while designing blocks. | Fixture/cache-backed search result cards with copy/open links. Optional later explicit refresh via external writer. Do not make Surface a network discovery daemon or credential catalog. |
| 3 | Agent Toolbelt Cards | Steipete-style local tools are strong block seeds: Peekaboo status, CodexBar-style usage status, RepoBar-style CI/PR freshness, mcporter MCP packages, oracle review handoffs. | Show installed/missing/local status and copyable commands. Each concrete tool graduates into its own block only after a real workflow exists. Do not add a generic command launcher. |

## UI Pattern Notes

- Prefer compact rows with status icon, source kind, state label, and copy/open icon buttons.
- Treat credentials as missing/available state only. Surface should not collect or persist API keys for these blocks.
- Browser/session blocks should show recordings and debug URLs as handoff cards, not embedded automation controls.
- integration catalog rows should expose source provenance and stable links; the Block Registry remains `Blocks.registry`.
- If a block needs a live producer, route it through an explicit external writer or a future tightly scoped block. Avoid generic "run anything" actions.

## Queue Updates

- Promote `browserbasesessioncards` after `integrationhub` if there is a stable external session JSON source.
- Promote `integrationcatalogfinder` if integrations.sh search results become part of the regular plugin-design loop.
- Keep Steipete-inspired tools as candidates until a specific local binary or app is installed and useful on this machine.
