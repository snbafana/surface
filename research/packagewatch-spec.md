# `packagewatch` Plugin Spec

## Why This Matters

Package tracking is a natural ambient-plus-action block: the user wants to know what is arriving today, what is stuck, and where to click for the authoritative carrier page. Raycast delivery extensions validate the shape: active deliveries, carrier, tracking number, status, notes, archive, and quick copy/open actions.

For Surface, the v1 value is a local delivery ledger, not a carrier integration service.

## Existing Owner / Dedup Decision

- Link Inbox owns generic URL capture and URL queues.
- Copy History owns passive clipboard history.
- Script Output owns scheduled command/API polling when the user explicitly configures scripts.
- System Health owns local machine status, not external shipment status.
- `packagewatch` owns only package records, local/cached delivery status, and carrier tracking links.

Do not add carrier credentials, email scraping, Apple Wallet scraping, API polling, webhook receivers, push notifications, or a second plugin registry. Implement as one `BlockRuntime` using `Block.Context.storageDirectory` and `Block.Context.now`.

## Product Boundary

It should:

- Show active packages grouped by urgency/status.
- Store title, carrier, tracking number, status, ETA, notes, and tracking URL.
- Open the carrier or universal tracking page on explicit action.
- Copy tracking number or package summary.
- Let the user manually add, mark delivered, archive, or unarchive records.
- Read preview fixtures without network access.

It should not:

- Poll FedEx/UPS/USPS/DHL/17TRACK/AfterShip APIs in v1.
- Require API keys, shipper accounts, OAuth, or carrier credentials.
- Scrape email, shopping accounts, browser history, Apple Wallet, or merchant sites.
- Infer delivery status from tracking pages.
- Run a background webhook server or notification daemon.
- Replace a dedicated package app such as Parcel.

## First Version

### Data Modes

Fixture mode:

1. Read `Block.Context.storageDirectory/packagewatch-packages.json`.
2. Use `Block.Context.now` for ETA/staleness labels.
3. All mutating actions write only when fixture storage allows it; previews can show no-op result states.
4. Do not fetch network status or metadata.

Live mode:

1. Read `~/Library/Application Support/Surface/PackageWatch/packagewatch-packages.json`.
2. Write manual add/mark/archive changes only when `Block.Context.allowsExternalWrites` is true.
3. Open tracking URLs with `NSWorkspace.open(_:)` on explicit action.
4. Do not run network refresh during `start()` or `refresh()`.

### Local Data Model

```swift
struct PackageWatchFile: Codable {
    var version: Int
    var packages: [PackageRecord]
    var carriers: [CarrierTemplate]
}

struct CarrierTemplate: Codable, Identifiable, Equatable {
    var id: String
    var title: String
    var urlTemplate: String
}

struct PackageRecord: Codable, Identifiable, Equatable {
    var id: String
    var title: String
    var carrier: String?
    var trackingNumber: String?
    var trackingURL: URL?
    var status: PackageStatus
    var etaStart: Date?
    var etaEnd: Date?
    var lastStatusAt: Date?
    var note: String?
    var source: PackageSource
    var archivedAt: Date?
    var createdAt: Date
    var updatedAt: Date
}

enum PackageStatus: String, Codable {
    case pending
    case infoReceived
    case inTransit
    case outForDelivery
    case delivered
    case exception
    case unknown
}

enum PackageSource: String, Codable {
    case manual
    case imported
    case cachedApi
}
```

Status is local/cached. `cachedApi` is allowed only for externally written files, not for `packagewatch` network fetches.

### Tracking URLs

Prefer stored `trackingURL` when present. Otherwise build a universal tracking URL:

```text
https://t.17track.net/en#nums=<percent-encoded tracking number>
```

Carrier-specific templates can be user-supplied in the JSON file later, but v1 should not maintain a brittle carrier URL catalog in code.

Tracking numbers are personal-ish data. The UI should show carrier plus last 4-6 characters by default and expose a copy-full action.

### Grouping

Visible groups:

- `Arriving today`: ETA overlaps `context.now` day or status is `outForDelivery`.
- `Needs attention`: status is `exception` or ETA is stale.
- `In transit`: active packages with future ETA or in-transit status.
- `Delivered`: recent delivered records, capped.
- `Archived`: hidden by default.

Sort active rows by:

1. attention first
2. ETA start/end
3. status priority
4. updated time

### Actions

- Open tracking page.
- Copy tracking number.
- Copy package summary.
- Mark delivered.
- Archive/unarchive.
- Add manual package.
- Reveal/open the backing JSON file.

No action should trigger a carrier network fetch. `Open tracking page` hands off to the user's browser.

## UI Shape

Header:

- `Packages`
- status pill: `2 arriving`, `1 issue`, or `No active`
- refresh/reveal buttons

Rows:

- title
- carrier and masked tracking number
- ETA/status pill
- stale badge when `lastStatusAt` is old
- icon actions: open, copy, mark delivered, archive

Manual add:

- compact form with title, carrier, tracking number, ETA, and note
- writes to local JSON only

Empty state:

- prompt to add a package manually or open the JSON file

## Runtime Shape

Target: `plugins/packagewatch/source/Plugin.swift`

Runtime:

1. `start()`: load package file and classify rows.
2. `refresh()`: reload package file and recompute labels against `Block.Context.now`.
3. `stop()`: no-op.
4. `makeView()`: render grouped rows, explicit actions, and manual add state.

Use plugin-local file read/write helpers at first. If several future blocks need JSON ledger writes, factor only after the duplication is real.

## Fixture Plan

Fixtures:

- `empty`: missing or empty package file.
- `active-deliveries`: in transit, out for delivery, and pending records.
- `attention`: stale ETA and exception records.
- `archived`: delivered plus archived records.

Example file:

```json
{
  "version": 1,
  "packages": [
    {
      "id": "pkg-1",
      "title": "Keyboard parts",
      "carrier": "DHL",
      "trackingNumber": "JD014600006789000000",
      "trackingURL": null,
      "status": "outForDelivery",
      "etaStart": "2026-06-21T17:00:00Z",
      "etaEnd": "2026-06-21T23:00:00Z",
      "lastStatusAt": "2026-06-21T14:12:00Z",
      "note": "Needs signature",
      "source": "manual",
      "archivedAt": null,
      "createdAt": "2026-06-20T16:00:00Z",
      "updatedAt": "2026-06-21T14:12:00Z"
    }
  ],
  "carriers": []
}
```

## Test Plan

- Decode package JSON fixtures.
- Missing package file renders empty state.
- ETA grouping uses `Block.Context.now`.
- Stale and exception rows render `Needs attention`.
- Tracking URL builder percent-encodes tracking numbers.
- Copy actions use a testable pasteboard adapter.
- Open action uses a testable opener and never fetches metadata.
- Archive/mark-delivered writes only when external writes or fixture storage allows it.
- Preview fixtures render nonblank PNGs through `Blocks.registry`.

## Recommendation

Implement after `linkinbox` or any local file-backed block. Keep v1 manual/fixture-backed. Live carrier status should be a separate later decision, probably via externally written cached JSON from `scriptoutput` or a dedicated integration, not inside the first `packagewatch` runtime.
