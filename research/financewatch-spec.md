# `financewatch` Plugin Spec

## Why This Matters

Finance watchlists are a proven ambient-status pattern: menu-bar stock tickers, Raycast stock extensions, and cached market-data dashboards all show a small set of symbols, prices, percent moves, and links. The useful Surface version is a local watchlist that makes stale/cached data visible and gives quick open/copy actions.

This block must stay informational. It is not a broker, portfolio tracker, trading tool, or advice surface.

## Existing Owner / Dedup Decision

- `scriptoutput` owns scheduled command/API polling if the user wants live external data.
- Link Inbox owns generic URL capture and URL queues.
- Package Watch owns external delivery-status ledgers, not market data.
- System Health owns local machine status, not market status.
- `financewatch` owns only local watchlist records, externally cached quote snapshots, stale-data labels, and open/copy actions.

Do not add broker credentials, account balances, trading actions, financial advice, alert-driven buy/sell prompts, API-key storage, or a second plugin registry. Implement as one `BlockRuntime` using `Block.Context.storageDirectory` and `Block.Context.now`.

## Product Boundary

It should:

- Show a local watchlist grouped by tags or asset class.
- Show cached/manual price, day change, percent change, currency, and quote age.
- Show stale/missing data clearly.
- Open a stored source URL, SEC filing page, or search URL on explicit action.
- Copy symbol, quote summary, or watchlist Markdown.
- Let the user manually add/remove/archive symbols and edit notes.

It should not:

- Fetch live quotes in `start()` or `refresh()`.
- Store API keys or broker credentials.
- Connect to brokerage, bank, retirement, or crypto exchange accounts.
- Place trades or deep-link to trade tickets.
- Show account balances, cost basis, gains/losses, or allocation in v1.
- Generate recommendations, price targets, or buy/sell signals.
- Treat cached prices as real-time or authoritative.

## First Version

### Data Modes

Fixture mode:

1. Read `Block.Context.storageDirectory/financewatch-watchlist.json`.
2. Use `Block.Context.now` for quote-age and market-staleness labels.
3. Do not fetch network data.
4. Mutating actions can be preview no-ops or write only to fixture storage.

Live mode:

1. Read `~/Library/Application Support/Surface/FinanceWatch/financewatch-watchlist.json`.
2. Write manual add/edit/archive changes only when `Block.Context.allowsExternalWrites` is true.
3. Read cached quotes from the same file or from `financewatch-quotes.json`.
4. Do not run market-data requests from the block runtime.

External writers:

- `scriptoutput`, a user cron, or a one-off script may write cached quote snapshots.
- Later API-backed integrations may write the same JSON shape.
- The block should display `source` and `asOf`, not hide how old or unofficial the data is.

### Local Data Model

```swift
struct FinanceWatchFile: Codable {
    var version: Int
    var instruments: [InstrumentRecord]
    var quotes: [QuoteSnapshot]
    var updatedAt: Date?
}

struct InstrumentRecord: Codable, Identifiable, Equatable {
    var id: String
    var symbol: String
    var displayName: String?
    var assetClass: AssetClass
    var exchange: String?
    var currency: String?
    var tags: [String]
    var note: String?
    var sourceURL: URL?
    var archivedAt: Date?
    var createdAt: Date
    var updatedAt: Date
}

enum AssetClass: String, Codable {
    case equity
    case etf
    case index
    case crypto
    case fx
    case fund
    case other
}

struct QuoteSnapshot: Codable, Identifiable, Equatable {
    var id: String
    var symbol: String
    var price: Decimal?
    var currency: String?
    var change: Decimal?
    var changePercent: Decimal?
    var previousClose: Decimal?
    var marketState: MarketState?
    var asOf: Date
    var source: QuoteSource
    var delayMinutes: Int?
}

enum MarketState: String, Codable {
    case premarket
    case open
    case closed
    case afterHours
    case unknown
}

enum QuoteSource: String, Codable {
    case manual
    case cachedApi
    case importedCsv
    case fixture
}
```

`cachedApi` means an external writer fetched the quote. It does not mean the block can fetch the quote itself.

### Display Rules

Rows should show:

- symbol
- display name or exchange
- price and currency
- day change and percent when present
- source and age, such as `cached 18m ago`
- stale warning when quote age exceeds a configurable threshold, default 30 minutes for market hours and 24 hours outside market hours
- note badge when a note exists

Group rows by:

- pinned/manual order first
- tag
- asset class

Sort rows within groups by:

1. pinned/manual order
2. absolute percent move, if present
3. symbol

### Actions

- Open source URL.
- Open symbol search URL if no source URL exists.
- Copy symbol.
- Copy quote summary.
- Copy watchlist Markdown.
- Edit note.
- Archive/unarchive instrument.
- Reveal/open backing JSON file.

No action should fetch a quote or place a trade.

## UI Shape

Header:

- `Watchlist`
- status pill: `8 symbols`, `2 stale`, or `No quotes`
- source-age pill: newest quote age

Rows:

- symbol and display name
- price/change with stable numeric width
- stale/source badge
- icon actions: open, copy, note/archive

Empty state:

- add symbol manually
- open backing JSON
- short `No live data configured` status

Risk copy:

- Keep it terse and factual: `Cached data only`.
- Do not display in-app investing advice disclaimers as a content panel; use source/staleness labels directly in the UI.

## Runtime Shape

Target: `plugins/financewatch/source/Plugin.swift`

Runtime:

1. `start()`: load watchlist and quotes.
2. `refresh()`: reload files and recompute quote age/staleness against `Block.Context.now`.
3. `stop()`: no-op.
4. `makeView()`: render groups, stale states, and explicit actions.

Use plugin-local JSON read/write helpers first. If package-style ledgers duplicate enough code later, factor a small local ledger helper after implementation.

## Fixture Plan

Fixtures:

- `empty`: no watchlist or quotes.
- `mixed-watchlist`: equities, ETFs, index, crypto, and notes.
- `stale-data`: old quotes and missing quote rows.
- `external-cache`: quotes with `cachedApi` source and source URLs.

Example file:

```json
{
  "version": 1,
  "updatedAt": "2026-06-21T20:57:52Z",
  "instruments": [
    {
      "id": "aapl",
      "symbol": "AAPL",
      "displayName": "Apple",
      "assetClass": "equity",
      "exchange": "NASDAQ",
      "currency": "USD",
      "tags": ["mega-cap"],
      "note": "Watch WWDC/platform cycle.",
      "sourceURL": "https://www.sec.gov/edgar/browse/?CIK=320193",
      "archivedAt": null,
      "createdAt": "2026-06-21T20:00:00Z",
      "updatedAt": "2026-06-21T20:00:00Z"
    }
  ],
  "quotes": [
    {
      "id": "aapl-quote",
      "symbol": "AAPL",
      "price": 214.35,
      "currency": "USD",
      "change": 1.24,
      "changePercent": 0.58,
      "previousClose": 213.11,
      "marketState": "closed",
      "asOf": "2026-06-21T20:30:00Z",
      "source": "fixture",
      "delayMinutes": 15
    }
  ]
}
```

## Test Plan

- Decode watchlist and quote fixtures.
- Missing file renders empty state.
- Quote matching is case-insensitive by symbol.
- Stale detection uses `Block.Context.now`.
- Percent/change formatting handles positive, negative, zero, and missing values.
- Decimal values round for display without mutating stored precision.
- Open/copy actions use testable adapters and never fetch network data.
- Manual archive/edit writes only when external writes or fixture storage allows it.
- Preview fixtures render nonblank PNGs through `Blocks.registry`.

## Recommendation

Implement after one local file-backed plugin. Keep v1 read/copy/manual. If live prices matter, add an external writer first, likely through `scriptoutput`, and have `financewatch` read the resulting cache rather than becoming a market-data client.
