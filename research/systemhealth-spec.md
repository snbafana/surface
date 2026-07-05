# `systemhealth` Plugin Spec

## Decision

Build `systemhealth` as one small actionable health `BlockRuntime`. It should surface only conditions that change what the user should do now: low disk, degraded thermal state, Low Power Mode, constrained/offline network, and battery/power source issues.

Do not build a passive widget pile of CPU, memory, uptime, fan, sensor, and per-process meters. Push custom metrics and shell-driven monitoring to `scriptoutput`.

## Dedupe Boundary

- `scriptoutput` owns arbitrary command output and custom system scripts.
- `permissionsdashboard` owns permission/status surfaces for privacy-gated APIs.
- `localbuildstatus` owns repo/build/test health, not machine health.
- `systemhealth` should use direct, low-risk macOS APIs and fixture JSON through `Block.Context.storageDirectory`; no second monitor daemon, no privileged helper, and no polling shell commands.

## Product Shape

The block should show one overall state plus the top 3 actionable rows:

- `OK`: no action needed
- `Watch`: one mild condition, such as low power mode or constrained network
- `Attention`: low disk, serious/critical thermal state, offline network, or very low battery

Rows should be action-shaped:

- Disk: free important capacity, threshold, reveal/open storage settings copy
- Thermal: nominal/fair/serious/critical plus "pause heavy work" guidance
- Power: Low Power Mode and battery level/charging/source
- Network: satisfied/unsatisfied, constrained, expensive

The block should prefer decisions over dashboards. It can hide nominal rows behind a compact detail section.

## Live Data Sources

1. Preview/test fixture:
   - `Block.Context.storageDirectory/systemhealth-snapshot.json`
2. Live APIs:
   - `ProcessInfo.processInfo.thermalState`
   - `ProcessInfo.processInfo.isLowPowerModeEnabled`
   - `ProcessInfo.thermalStateDidChangeNotification`
   - `NSNotification.Name.NSProcessInfoPowerStateDidChange`
   - `URLResourceValues.volumeAvailableCapacityForImportantUsage` on the user's home directory and optional configured paths
   - `NWPathMonitor` and `NWPath.status/isExpensive/isConstrained`
   - IOKit power source APIs for attached/internal battery state

No live command execution is needed in v1.

## Snapshot Schema

```json
{
  "version": 1,
  "generatedAt": "2026-06-21T17:45:00Z",
  "thermal": {
    "state": "nominal"
  },
  "power": {
    "lowPowerMode": false,
    "batteryPercent": 82,
    "isCharging": true,
    "powerSource": "AC Power"
  },
  "disk": [
    {
      "path": "/Users/example",
      "availableImportantBytes": 104857600000,
      "thresholdBytes": 21474836480
    }
  ],
  "network": {
    "status": "satisfied",
    "isExpensive": false,
    "isConstrained": false,
    "interfaceTypes": ["wifi"]
  }
}
```

## Runtime Behavior

- `start()`: load fixture or live snapshot, register low-cost notification/monitor observers, and start a slow refresh loop.
- `refresh()`: reread live state or fixture state. No shelling out.
- `stop()`: cancel refresh task, stop `NWPathMonitor`, and remove observers.
- Use `Block.Context.now` for age labels and deterministic previews.
- Use `Block.Context.allowsLiveProcesses` to decide whether to attach live monitors. In fixture mode, read only `systemhealth-snapshot.json`.
- Default refresh interval: 30 seconds. Network/path notifications and power/thermal notifications can trigger immediate refresh.
- Disk threshold defaults:
  - `attention`: under 20 GB or under 10 percent available, whichever is easier to implement first
  - `watch`: under 50 GB

## Source Evidence

- Apple documents `ProcessInfo.thermalState` and thermal-state notifications for apps that need to reduce resource use under higher thermal states.
- Apple documents `ProcessInfo.isLowPowerModeEnabled` and power-state change notifications so apps can adapt when Low Power Mode is active.
- Apple documents `URLResourceValues.volumeAvailableCapacityForImportantUsage` for checking available capacity on the volume backing a file URL.
- Apple documents `NWPathMonitor` as an observer for network changes, and `NWPath.isConstrained` for Low Data Mode / constrained path state.
- Apple documents `IOPowerSources` as uniform access to attached power-source state.
- SwiftBar and Ubersicht validate ambient system status, but their script/widget model is already covered by `scriptoutput`; `systemhealth` should be API-backed and action-filtered.

## Preview Fixtures

Use `Block.Context.storageDirectory`.

Fixture `healthy`:

- nominal thermal
- low power off
- AC/charging or no battery issue
- disk above thresholds
- network satisfied/unconstrained

Fixture `attention`:

- thermal serious
- low disk
- network constrained
- battery under 10 percent and discharging

Fixture `offline-desktop`:

- no battery
- network unsatisfied
- disk healthy
- thermal nominal

## Tests

- Missing fixture renders an unknown/setup state in preview context.
- Snapshot severity rolls up to OK/Watch/Attention.
- Disk thresholds classify healthy/watch/attention.
- Thermal serious/critical produces Attention and guidance to pause heavy work.
- Low Power Mode produces Watch unless combined with low battery.
- Offline network produces Attention; constrained/expensive produces Watch.
- Battery low and discharging produces Attention.
- In fixture context, no live monitors are started.
- Preview fixture coverage is added to `BlockPreviewTests`.
- Rendered PNGs are nonblank for `healthy`, `attention`, and `offline-desktop`.

## Explicit Non-Goals

- No fan, temperature sensor, or per-core graphs.
- No per-process CPU/memory lists.
- No network speed tests or external pings.
- No shell commands, `powermetrics`, `top`, `vm_stat`, or `pmset` in v1.
- No privileged helper or LaunchDaemon.
- No historical charting beyond latest snapshot age.
