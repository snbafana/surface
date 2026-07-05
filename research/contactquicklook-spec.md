# `contactquicklook` Plugin Spec

## Why This Matters

Contacts are useful when Surface is already holding a person-shaped hint: an email address in the clipboard, a phone number in selected text, a meeting attendee, or a curated local contact card. The useful block is a quick card for one or a few explicit people, not a searchable address book.

Contacts data is sensitive. Surface should not start by enumerating the user's address book, building its own people database, or silently prompting for Contacts access. The first version should be fixture-first, permission-aware, and lookup-only.

## Existing Owner / Dedup Decision

- `permissionsdashboard` owns Contacts permission status, request copy, and blocked/request states.
- Copy History owns passive clipboard history.
- `contextcard` owns selected/front-app context and any future active-app selected text.
- `calendarprep` owns meeting attendees/events.
- `linkinbox` owns URL capture and URL triage.
- `cued` or other external tools own broader relationship/message intelligence outside Surface.
- `contactquicklook` owns only explicit contact-card rendering, exact lookup by identifier/email/phone, copy/open actions, and stale/blocked state.

Do not add a broad contact search, relationship graph, CRM, duplicate address book, background sync, contact dedupe tool, write/edit/create flow, birthday/reminder system, import/export tool, or second plugin registry. Implement as one `BlockRuntime` using `Block.Context.storageDirectory` and `Block.Context.now`.

## Product Boundary

It should:

- Read fixture/cached contact cards from `contactquicklook-contacts.json`.
- Show compact person cards with name, organization/title, phones, emails, URLs, notes, and source/stale state.
- Resolve one explicit lookup query at a time: contact identifier, email address, or phone number.
- Use minimal `keysToFetch` for live Contacts lookups.
- Use `CNContactFormatter` for localized full names.
- Copy email, phone, address, URL, or contact summary Markdown.
- Open `mailto:` or URL rows only from explicit actions.
- Show clear blocked states for missing Contacts permission or missing `NSContactsUsageDescription`.

It should not:

- Enumerate all contacts in v1.
- Build a general contact search UI.
- Store a copy of the whole Contacts database.
- Create, edit, delete, merge, or dedupe contacts.
- Read birthdays, notes, images, postal addresses, or URLs unless explicitly requested in fixture/live key sets.
- Infer relationships from Messages, Mail, Calendar, or browser history.
- Auto-match every clipboard item or selected text in the background.
- Request Contacts access on startup or refresh.
- Ask for Contacts permission outside `permissionsdashboard`.

## First Version

### Data Modes

Fixture mode:

1. Read `Block.Context.storageDirectory/contactquicklook-contacts.json`.
2. Use `Block.Context.now` for stale labels.
3. Do not call `CNContactStore` or show system pickers.
4. Open/copy actions are preview no-ops except deterministic pasteboard adapter tests.

Live cached mode:

1. Read `~/Library/Application Support/Surface/ContactQuickLook/contactquicklook-contacts.json`.
2. Treat cached rows as user/exported cards, not a synced address book.
3. Allow a cached row to include a Contacts identifier for explicit refresh later.

Live lookup mode:

1. Check Contacts authorization status through the same pattern used by `permissionsdashboard`.
2. Require `NSContactsUsageDescription` before any live Contacts request ships.
3. Only query Contacts after an explicit user action, such as `Lookup copied email` or `Lookup phone`.
4. Fetch by exact identifier/email/phone predicate.
5. Fetch only required keys for the displayed fields.
6. Do not enumerate all contacts or poll for changes in v1.

### Contact Card File

```json
{
  "version": 1,
  "exportedAt": "2026-06-22T00:46:53Z",
  "cards": [
    {
      "id": "fixture-ada",
      "displayName": "Ada Lovelace",
      "organization": "Analytical Engines",
      "jobTitle": "Research collaborator",
      "emails": [
        { "label": "work", "value": "ada@example.com" }
      ],
      "phones": [
        { "label": "mobile", "value": "+1 415 555 0100" }
      ],
      "urls": [
        { "label": "profile", "value": "https://example.com/ada" }
      ],
      "note": "Fixture card",
      "source": "fixture",
      "updatedAt": "2026-06-22T00:45:00Z"
    }
  ]
}
```

### Local Data Model

```swift
struct ContactQuickLookState: Codable, Equatable {
    var version: Int
    var exportedAt: Date
    var cards: [ContactCard]
}

struct ContactCard: Codable, Identifiable, Equatable {
    var id: String
    var displayName: String
    var organization: String?
    var department: String?
    var jobTitle: String?
    var emails: [ContactValue]
    var phones: [ContactValue]
    var urls: [ContactValue]
    var postalAddresses: [ContactValue]
    var note: String?
    var source: ContactCardSource
    var updatedAt: Date?
}

struct ContactValue: Codable, Identifiable, Equatable {
    var id: String { "\(label):\(value)" }
    var label: String
    var value: String
}

enum ContactCardSource: String, Codable {
    case fixture
    case cached
    case contacts
    case picked
}
```

### Live Contacts Key Set

Start with a minimal display key set:

- `CNContactFormatter.descriptorForRequiredKeys(for: .fullName)`
- `CNContactOrganizationNameKey`
- `CNContactDepartmentNameKey`
- `CNContactJobTitleKey`
- `CNContactEmailAddressesKey`
- `CNContactPhoneNumbersKey`
- optional later: `CNContactUrlAddressesKey`, `CNContactPostalAddressesKey`, `CNContactThumbnailImageDataKey`

Do not fetch note, image data, birthday, social profiles, relations, or full postal addresses unless a later UI explicitly needs them.

### Lookup Sources

Allowed v1 lookups:

- Contact identifiers from a cached row or future picker result.
- Email address from explicit paste/copy action.
- Phone number from explicit paste/copy action.
- Fixture query strings in previews/tests.

Deferred:

- Name search.
- Whole address-book enumeration.
- App-wide clipboard scanning.
- Meeting attendee enrichment from `calendarprep`.
- Selected-text enrichment from `contextcard`.
- Contact picker / limited-access management.

## Display Rules

Header:

- `Contacts`
- status pill: `cached`, `ready`, `blocked`, `missing`, or `stale`
- card count and source label

Card rows:

- display name
- organization/job title
- primary email
- primary phone
- source and updated age
- icon actions: copy email, copy phone, copy summary, open mailto, open URL

Sort rows:

1. exact lookup result
2. cached pinned cards
3. recently updated cards
4. stale cards

Stale policy:

- If `exportedAt` is older than 24 hours, mark the cached file stale.
- If a card `updatedAt` is older than 30 days, mark the card stale but still render it.
- Use `Block.Context.now` for all age labels.

## Actions

- Copy primary email.
- Copy primary phone.
- Copy all visible contact fields as Markdown.
- Open `mailto:` for selected email.
- Open stored URL.
- Reveal cached JSON.
- Request Contacts access by routing to `permissionsdashboard`.

No action should create/edit/delete contacts, enumerate all contacts, start background sync, scrape messages/mail, or request Contacts access implicitly.

## UI Shape

Top region:

- source/permission status
- stale age
- exact lookup query if one is active

Main list:

- up to five compact contact cards
- each row uses icon buttons for copy/open/reveal
- hide empty field groups instead of rendering placeholders

Empty state:

- `No contact cards`
- show expected JSON filename
- show blocked permission row only if live lookup was requested

Blocked state:

- `Contacts access not granted`
- show permission status and route to `permissionsdashboard`
- keep cached/fixture cards visible where available

## Runtime Shape

Target: `plugins/contactquicklook/source/Plugin.swift`

Runtime:

1. `start()`: load cached/fixture cards.
2. `refresh()`: reload cache and recompute stale labels.
3. explicit `lookup(query:)`: exact identifier/email/phone lookup only when permission and bundle support are present.
4. `stop()`: no-op.
5. `makeView()`: render cached cards, lookup result, blocked state, and copy/open actions.

Use plugin-local Contacts adapter first. If Contacts permission checks repeat across multiple plugins, factor only after `permissionsdashboard` and `contactquicklook` both exist.

## Fixture Plan

Fixtures:

- `empty`: no card file.
- `cached-cards`: three cards with email/phone/url variety.
- `blocked-permission`: lookup requested but Contacts permission unavailable.
- `exact-email-match`: one live-style result from an email query.
- `stale-cache`: old export and stale card timestamps.
- `partial-fields`: name-only and email-only cards.

## Test Plan

- Missing file renders empty state.
- Cached cards decode and sort deterministically.
- Stale cache and stale cards use `Block.Context.now`.
- Exact lookup parser accepts identifiers, email addresses, and phone numbers.
- Fixture/preview mode never calls `CNContactStore`.
- Live lookup refuses to run without Contacts authorization and bundle purpose-string support.
- Live lookup uses exact predicates only; no test path enumerates all contacts.
- Copy Markdown is deterministic.
- Mailto/URL open actions only open decoded fields from visible rows.
- Preview fixtures render nonblank PNGs through `Blocks.registry`.

## Recommendation

Implement `contactquicklook` as a privacy-first quick card block. It should be most useful when another owner supplies an explicit person hint, and it should stay small until the permission dashboard, bundle purpose strings, and exact lookup path are implemented.
