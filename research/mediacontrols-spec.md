# `mediacontrols` Plugin Spec

## Why This Matters

Media controls are tempting because launcher tools can show current tracks, play/pause buttons, and audio-route switches. The supported API boundary is narrower than the product idea: Apple's Now Playing APIs are for apps that publish and control their own playback sessions, not for a utility app to read or control whatever another app is playing. Audio device routing is the safer useful slice because Core Audio exposes system audio devices and default output/input choices.

The useful Surface version is an audio route card with optional externally cached now-playing context. It should not become a generic system media controller.

## Existing Owner / Dedup Decision

- `permissionsdashboard` owns Apple Events, Accessibility, notification, and future media-control permission status/request flow.
- `scriptoutput` owns user-provided scripts that control Spotify, Music, browser tabs, or other players.
- `browsersessioncards` should own browser-tab media state if browser automation becomes viable.
- `contextcard` owns frontmost app/window context and should not grow media-specific logic.
- `notificationdigest` owns media/focus completion event summaries, not playback controls.
- `mediacontrols` owns only audio route/device state, explicit route switching, local route presets, and optional read-only now-playing snapshots written by an external owner.

Do not add private MediaRemote usage, system-wide Now Playing scraping, audio capture/taps, AppleScript playback control in v1, Spotify OAuth/Web API clients, browser media automation, hidden route enforcement loops, AirPlay/Bluetooth pairing, or a second plugin registry. Implement as one `BlockRuntime` using `Block.Context.storageDirectory` and `Block.Context.now`.

## Product Boundary

It should:

- Show default output, input, and sound-effects devices.
- Show connected/available audio devices with output/input capabilities.
- Show whether software volume/mute appears supported when the adapter can report it.
- Apply explicit route presets, such as `Desk`, `Headphones`, or `Meeting`.
- Set output/input/sound-effects defaults only from explicit user actions.
- Copy the current audio route summary.
- Open Sound settings or reveal the backing preset file.
- Display optional cached now-playing text from `mediacontrols-nowplaying.json` as read-only context.

It should not:

- Read or control the system-wide Now Playing item.
- Use private frameworks such as MediaRemote.
- Capture audio, inspect audio samples, or detect active sound.
- Use AppleScript/Apple Events to control Music, Spotify, or browsers in v1.
- Connect/disconnect Bluetooth devices or AirPlay speakers.
- Run a background watchdog that reverts device choices.
- Manage per-app audio routing, effects, equalizers, aggregate devices, or virtual drivers.
- Poll Spotify, MusicKit, YouTube, browser tabs, or web APIs.
- Alter volume automatically or enforce pinned volume/device state.

## First Version

### Data Modes

Fixture mode:

1. Read `Block.Context.storageDirectory/mediacontrols-audio.json`.
2. Read optional `Block.Context.storageDirectory/mediacontrols-presets.json`.
3. Read optional `Block.Context.storageDirectory/mediacontrols-nowplaying.json`.
4. Use `Block.Context.now` for cache age labels.
5. Mutating actions are preview no-ops or write only to fixture storage.

Live mode:

1. Use a small adapter around public Core Audio APIs to read current devices and defaults.
2. Prefer `AudioHardwareSystem` on macOS 15+ for default output/input/sound-effects devices and available devices.
3. If supporting older macOS later, isolate legacy `AudioObject*` code behind the same adapter.
4. Write preset changes only when `Block.Context.allowsExternalWrites` is true.
5. Set default output/input/sound-effects devices only from explicit row or preset actions.
6. Treat now-playing JSON as externally written cache and do not refresh it inside the block.

External writers:

- `scriptoutput` may write `mediacontrols-nowplaying.json` from a user script.
- Browser/media source plugins may later write the same cache shape.
- App-specific Apple Events controls should live in a separate source owner or explicit script, not inside `mediacontrols`.

### Local Data Model

```swift
struct MediaControlsSnapshot: Codable, Equatable {
    var capturedAt: Date
    var defaultOutputDeviceID: String?
    var defaultInputDeviceID: String?
    var defaultSoundEffectsDeviceID: String?
    var devices: [AudioRouteDevice]
}

struct AudioRouteDevice: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var transportType: String?
    var isOutput: Bool
    var isInput: Bool
    var canBeDefaultOutput: Bool
    var canBeDefaultInput: Bool
    var canBeDefaultSoundEffects: Bool
    var supportsVolume: Bool?
    var volumePercent: Int?
    var isMuted: Bool?
    var isConnected: Bool
}

struct AudioRoutePreset: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var outputDeviceID: String?
    var inputDeviceID: String?
    var soundEffectsDeviceID: String?
    var note: String?
    var createdAt: Date
    var updatedAt: Date
}

struct MediaNowPlayingSnapshot: Codable, Equatable {
    var sourceID: String
    var sourceName: String
    var title: String?
    var artist: String?
    var album: String?
    var playbackState: PlaybackState
    var url: URL?
    var capturedAt: Date
    var sourceKind: NowPlayingSourceKind
}

enum PlaybackState: String, Codable {
    case playing
    case paused
    case stopped
    case unknown
}

enum NowPlayingSourceKind: String, Codable {
    case externalCache
    case fixture
}
```

The now-playing snapshot is context only. No row action should infer that Surface can control that source.

### Display Rules

Header:

- `Audio`
- status pill: current output, such as `AirPods`
- route mismatch pill if default output and sound-effects device differ

Device rows should show:

- device name
- output/input badges
- default role badges: output, input, effects
- connected/unavailable state
- optional volume/mute label when reported

Preset rows should show:

- preset name
- output/input/effects target labels
- missing target warning when a device is unavailable
- apply button only when at least one target exists

Now-playing context should show:

- title/artist/source if cache exists
- source age, such as `cached 2m ago`
- `external cache only` label

Sort rows:

1. current default output/input devices
2. connected output devices
3. connected input-only devices
4. unavailable preset targets
5. other devices by name

### Actions

- Set as output.
- Set as input.
- Set as sound effects.
- Apply route preset.
- Save current route as preset.
- Delete preset.
- Copy route summary.
- Open Sound settings.
- Reveal/open preset JSON.

No action should play/pause, skip, scrub, like, change Spotify/Music/browser state, connect Bluetooth, start AirPlay, or run scripts.

## UI Shape

Top region:

- current output/input/effects summary
- route preset buttons for the top three presets
- stale fixture/cache badge if the snapshot is not live

Main list:

- devices and presets in compact rows
- icon buttons for output/input/effects actions
- disabled states with terse reasons: `missing`, `not output`, `not input`, `fixture`

Optional bottom row:

- now-playing cache, if present
- copy/open URL only; no playback buttons in v1

## Runtime Shape

Target: `plugins/mediacontrols/source/Plugin.swift`

Runtime:

1. `start()`: load fixtures or query the audio route adapter; load presets and optional now-playing cache.
2. `refresh()`: reload preset/cache files and re-query audio devices in live mode.
3. `stop()`: no-op.
4. `makeView()`: render route summary, device rows, preset rows, and optional now-playing context.

Use plugin-local JSON helpers first. If multiple plugins later need a generic cached snapshot reader, factor it after implementation.

## Fixture Plan

Fixtures:

- `simple-output`: built-in speakers and microphone.
- `desk-setup`: monitor output, USB microphone, headphones, and presets.
- `missing-preset-target`: preset points to unavailable AirPods.
- `cached-nowplaying`: externally cached browser/Spotify track with no playback actions.
- `unsupported-live`: live adapter unavailable or macOS version below the supported route API.

Example audio fixture:

```json
{
  "capturedAt": "2026-06-21T22:03:22Z",
  "defaultOutputDeviceID": "airpods-pro",
  "defaultInputDeviceID": "studio-mic",
  "defaultSoundEffectsDeviceID": "built-in-speakers",
  "devices": [
    {
      "id": "airpods-pro",
      "name": "AirPods Pro",
      "transportType": "Bluetooth",
      "isOutput": true,
      "isInput": true,
      "canBeDefaultOutput": true,
      "canBeDefaultInput": true,
      "canBeDefaultSoundEffects": true,
      "supportsVolume": true,
      "volumePercent": 42,
      "isMuted": false,
      "isConnected": true
    }
  ]
}
```

## Test Plan

- Missing fixture renders unsupported/empty state without crashing.
- Device fixture decodes output/input/effects roles.
- Current defaults sort to the top.
- Preset with missing device renders disabled target warning.
- `Block.Context.now` drives cache-age labels.
- Live adapter can be replaced by a fake in tests.
- Explicit set-output/input/effects actions call only the adapter method under test.
- No playback actions are present in v1 fixtures.
- Mutations write only when fixture storage or external writes allow it.
- Preview fixtures render nonblank PNGs through `Blocks.registry`.

## Recommendation

Implement only if an audio-route switcher is useful enough on its own. Do not implement a generic media controller until there is a supported public way to read/control system Now Playing, or until a source-specific owner such as browser session cards, Spotify, or Apple Music is deliberately added with its own permissions and credentials.
