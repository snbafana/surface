# `calendarprep` Plugin Spec

## Why This Matters

Calendar is a high-frequency overlay use case: the user wants to know what is next, join quickly, and copy enough context to prepare without opening a full calendar app. Raycast validates this with its Calendar core feature, which surfaces the next meeting, schedule overview, join actions, attendee/email actions, and copy details.

For Surface, the narrow win is not a full calendar client. It is a small block that answers: what is my next meeting, what do I need to copy or open, and why is it blocked if Calendar access is unavailable?

## Existing Owner / Dedup Decision

- `permissionsdashboard` owns Calendar permission visibility and the explicit request action pattern.
- `script/build_and_run.sh` / bundle generation owns Info.plist purpose strings.
- `calendarprep` owns only read-only next-event display, fixture-backed previews, and local copy/open actions.

Do not add a second plugin registry, permission framework, Calendar daemon, or scheduler. Keep this as one `BlockRuntime` using `Block.Context.storageDirectory` and `Block.Context.now`.

## Product Boundary

It should:

- Show the next relevant event and a short lookahead list.
- Show blocked/setup states when Calendar full access is unavailable or the app bundle lacks the purpose string.
- Let the user copy event details, copy a meeting URL, open the event/calendar URL when available, and open a location URL when the event has one.
- Use fixtures for block previews and tests without touching EventKit.

It should not:

- Create, edit, delete, or RSVP to events in v1.
- Auto-join meetings or run actions without confirmation.
- Email attendees, invite people, or read Contacts.
- Parse all calendar history or sync state beyond a short future date range.
- Implement scheduling/focus-time creation; that belongs to a later write-capable plugin.

## First Version

### Data Modes

Fixture mode:

1. If `Block.Context.storageDirectory` contains `calendarprep-events.json`, load that file.
2. Use `Block.Context.now` as the fixed clock.
3. Do not initialize `EKEventStore` in previews/tests.

Live mode:

1. Check `EKEventStore.authorizationStatus(for: .event)`.
2. If status is not full access, render a blocked state with a handoff to `permissionsdashboard`.
3. If full access is available, query only a short future range.
4. Sort returned events by start date for deterministic UI and tests.

### Calendar Access

Surface targets macOS 14+, so the live path should use the modern EventKit access model:

- `NSCalendarsFullAccessUsageDescription` in the app bundle before requesting or fetching events.
- `EKEventStore.requestFullAccessToEvents` only from an explicit user action, ideally inside `permissionsdashboard`.
- `EKEventStore.authorizationStatus(for: .event)` for status checks.

Full access is required because `calendarprep` reads existing events. Write-only access is not sufficient: it can add events, but cannot read calendars or existing events.

### Event Query

Default range:

- Start: `context.now`.
- End: `context.now + 36 hours`.
- Calendars: all calendars in v1 unless the fixture/config supplies enabled calendar identifiers.

Use:

- `predicateForEvents(withStart:end:calendars:)`
- `events(matching:)`

Then:

- Exclude ended events.
- Prefer non-all-day events for the "next meeting" slot.
- Keep all-day events in a secondary row only when there are no timed events.
- Sort by `startDate`, then by `endDate`, then by title.
- Limit the visible list to 3-5 rows.

### Row Model

```swift
struct CalendarPrepEvent: Codable, Equatable {
    var id: String
    var title: String
    var startDate: Date
    var endDate: Date
    var isAllDay: Bool
    var calendarTitle: String?
    var calendarColorHex: String?
    var location: String?
    var url: URL?
    var notesPreview: String?
    var attendeeCount: Int?
}
```

The live adapter can map from `EKEvent` fields such as title, start/end date, location, URL, notes, attendees, and calendar title/color. The block should store only a display snapshot, not raw EventKit objects.

### Actions

- Open event URL or Calendar app if an `EKEvent.url` is available.
- Copy event title.
- Copy details as:

```text
<title>
<start> - <end>
<location or url if present>
```

- Copy meeting URL when `url` is present or when a later explicit parser extracts one from notes/location.
- Copy prep note skeleton:

```text
## <title>
When: <start> - <end>
Where: <location>

Prep:
- 

Follow-up:
- 
```

Meeting-link extraction from arbitrary notes/location text should be conservative in v1. Prefer direct `EKEvent.url` and exact URL matches; avoid provider-specific Zoom/Meet parsing until tested.

## UI Shape

Header:

- `Calendar`
- status pill: `Next in 18m`, `No meetings`, or `Needs access`
- small refresh/copy buttons following existing block chrome patterns

Primary row:

- Event title.
- Relative start time and duration.
- Calendar color swatch and calendar title.
- Location or meeting URL host.
- Icon actions: open, copy details, copy meeting URL, copy prep note.

Secondary rows:

- The next 2-4 events in the lookahead window.
- Compact time, title, and one action button.

Blocked state:

- Title: `Calendar access needed`
- Copy: one short sentence saying Surface needs full Calendar access to read upcoming events.
- Actions: open permissions dashboard / copy setup instructions.

## Runtime Shape

Target: `plugins/calendarprep/source/Plugin.swift`

Runtime:

1. `start()`: load fixture or check Calendar status.
2. `refresh()`: reload fixture or fetch the short future range.
3. `stop()`: release/ignore the event store.
4. `makeView()`: render snapshot rows and blocked states.

Keep the EventKit adapter plugin-local until at least one more plugin needs Calendar data.

## Fixture Plan

Fixtures:

- `empty-day`: no events in the lookahead range.
- `next-meeting`: one meeting in 18 minutes with URL, location, and notes preview.
- `busy-day`: multiple timed events and one all-day event.
- `blocked-permission`: status row for not-determined/denied access.

Example fixture:

```json
{
  "now": "2026-06-21T18:54:51Z",
  "authorization": "fullAccess",
  "events": [
    {
      "id": "standup-1",
      "title": "Surface plugin check-in",
      "startDate": "2026-06-21T19:15:00Z",
      "endDate": "2026-06-21T19:45:00Z",
      "isAllDay": false,
      "calendarTitle": "Work",
      "calendarColorHex": "#0A84FF",
      "location": "Zoom",
      "url": "https://example.com/meeting",
      "notesPreview": "Review plugin registry and preview fixtures.",
      "attendeeCount": 3
    }
  ]
}
```

## Test Plan

- Fixture decode and row mapping.
- Sort unsorted EventKit/fixture rows by start time.
- Prefer timed events over all-day events in the primary slot.
- `notDetermined`, `denied`, `restricted`, and `writeOnly` statuses render blocked/setup states, not empty calendars.
- Missing `NSCalendarsFullAccessUsageDescription` renders an implementation warning in debug/dev builds.
- Preview fixtures render nonblank PNGs through `Blocks.registry`.

## Recommendation

Implement after `permissionsdashboard` or alongside it only if the first release stays fixture-only. Live EventKit support should not ship until the run script/app bundle includes `NSCalendarsFullAccessUsageDescription` and the permission request path is explicit.
