# `permissionsdashboard` Plugin Spec

## Why This Matters

Several attractive Surface plugins touch macOS privacy boundaries:

- `contextcard` v2: Accessibility for focused window/selected text.
- `windowlayouts`: Accessibility for controlling windows.
- `browsercards`: Automation or browser-specific permissions.
- `calendar`: Calendar/EventKit.
- `contacts`: Contacts.
- `screencap` or visual context: Screen Recording.
- future global keyboard/mouse blocks: Input Monitoring.

If those permissions stay hidden, Surface will feel broken. A small dashboard block can make permission state visible and turn permission-heavy plugins into explicit user choices.

## Product Boundary

This block is not a generic TCC manager and should not try to bypass macOS prompts.

It should:

- Show which Surface plugins need which permissions.
- Show current status when there is a public API to check it.
- Offer explicit request buttons only where the platform provides request APIs.
- Link/open System Settings where manual approval is required.
- Explain which plugin is blocked by which permission.

It should not:

- Request permissions on app launch.
- Use MDM/PPPC.
- Promise it can grant permissions itself.
- Hide permission errors inside individual plugins.

## First Version

### Permission Rows

| Permission | Check | Request | Needed By |
| --- | --- | --- | --- |
| Accessibility | `AXIsProcessTrustedWithOptions(nil)` | `AXIsProcessTrustedWithOptions` with prompt option from an explicit button | `contextcard` v2, `windowlayouts` |
| Screen Recording | `CGPreflightScreenCaptureAccess()` | `CGRequestScreenCaptureAccess()` from explicit button | screenshot/visual-context ideas |
| Calendar | `EKEventStore.authorizationStatus(for:)` | `requestFullAccessToEvents` from explicit button | calendar/meeting block |
| Contacts | `CNContactStore.authorizationStatus(for:)` | `requestAccess(for:)` from explicit button | contacts/networking blocks |
| Apple Events / Automation | no simple universal status for all targets | Info.plist purpose string plus per-target system prompt | browser/app-control blocks |
| Input Monitoring | user-managed in System Settings; avoid v1 request path | manual instructions only | global input/event-tap ideas |

### UI

Header:

- `Permissions`
- status pill: `2 needed`
- issue pill: `1 blocked`

Rows:

- Permission name.
- Status: `Ready`, `Not needed`, `Needs approval`, `Unavailable`, `Manual`.
- A short list of blocked plugins.
- One fixed icon button: request/open settings/copy instructions.

The row model should support fixture-only statuses so previews never need real privacy checks.

## Runtime Shape

Target: `plugins/permissionsdashboard/source/Plugin.swift`

Runtime:

1. `start()`: read configured permission requirements and check statuses.
2. `refresh()`: re-check statuses.
3. `stop()`: no-op.
4. `makeView()`: render rows and action buttons.

Use a plugin-local checker abstraction:

```swift
struct PermissionChecker {
    var accessibility: @MainActor () -> PermissionState
    var screenRecording: @MainActor () -> PermissionState
    var calendar: @MainActor () -> PermissionState
    var contacts: @MainActor () -> PermissionState
}
```

Do not put this in `Core` until at least two plugins need to consume the same permission state directly.

## Bundle / Info.plist Implication

The current `script/build_and_run.sh` generates a minimal `Info.plist`. Before Calendar, Contacts, or Apple Events plugins ship, the script needs purpose-string support.

Likely future keys:

- Calendar full-access purpose string.
- Contacts purpose string.
- Apple Events purpose string.

Keep this in the run script/app bundle owner, not inside individual plugin folders.

## Fixture Plan

Fixtures:

- `all-clear`
- `mixed-blocked`
- `manual-only`

Example fixture row:

```json
{
  "permission": "Accessibility",
  "state": "needsApproval",
  "blockedPlugins": ["contextcard v2", "windowlayouts"],
  "action": "openSettings"
}
```

## Test Plan

- Fixture rows decode and render.
- Status aggregation counts `needsApproval` and `blocked` rows.
- Request buttons are hidden for manual-only permissions.
- Missing purpose-string configuration can render as a separate warning state.
- Preview fixtures render nonblank.

## Recommendation

Implement after one permission-light plugin (`githubqueue` or `fileinbox`) and before any AX/EventKit/Contacts/ScreenCaptureKit plugin. This keeps permission work from blocking local-first progress while preventing future silent failures.
