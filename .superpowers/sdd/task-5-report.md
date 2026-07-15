# Task 5 Report: System Monitor and Scheduler

## What I implemented

- Added `MonitoringScheduler` in `MacStatusCodexMonitor/App/MonitoringScheduler.swift` with `start(interval:refresh:)` and `stop()` exactly as specified.
- Added `SystemMonitor` in `MacStatusCodexMonitor/Monitors/SystemMonitor.swift` with `snapshot(previousIO:)` and the requested collectors for CPU, memory, battery, disk capacity, placeholder disk I/O metadata, and unavailable GPU status.
- Added `AppState` in `MacStatusCodexMonitor/App/AppState.swift` as an `@MainActor` `ObservableObject` that owns published system, disk growth, cache estimate, and Codex quota state, plus `refresh()` to update and persist snapshots.
- Updated `MacStatusCodexMonitor.xcodeproj/project.pbxproj` to include the three new source files in the app target and group structure.

## What I tested and test results

- Ran:
  - `/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild build -project /Users/laosuer/Xcode/60714SeeS/MacStatusCodexMonitor.xcodeproj -scheme MacStatusCodexMonitor -destination 'platform=macOS' -derivedDataPath /private/tmp/MacStatusCodexMonitor-task5-deriveddata`
- Result:
  - `BUILD SUCCEEDED`

Notes:
- The default `xcodebuild` on PATH failed because the active developer directory was `/Library/Developer/CommandLineTools`, not full Xcode.
- A direct `swiftc -typecheck` fallback was not usable in this environment because the CLI toolchain and SDK versions were mismatched and the default module cache path was not writable.
- Using the full Xcode binary directly with a writable derived data path provided successful compile/build verification.

## Files changed

- `MacStatusCodexMonitor/App/AppState.swift`
- `MacStatusCodexMonitor/App/MonitoringScheduler.swift`
- `MacStatusCodexMonitor/Monitors/SystemMonitor.swift`
- `MacStatusCodexMonitor.xcodeproj/project.pbxproj`

## Self-review findings

- No blocking issues found in the implemented scope.
- I added `import Combine` to `AppState.swift` so `ObservableObject` and `@Published` resolve cleanly under compilation; this is a compile-focused adjustment to the brief’s snippet, not a behavioral change.

## Issues or concerns

- `SystemMonitor.snapshot(previousIO:)` accepts the prior I/O snapshot per the required interface, but v1 still returns the brief’s placeholder “unavailable” disk I/O estimate and does not yet compute deltas from `previousIO`.
- Build verification required the explicit Xcode binary path because the shell environment is currently pointed at Command Line Tools instead of full Xcode.

---

## Task 5 Fix After Review

### What I fixed

- Updated `SystemMonitor` to compute CPU usage from successive CPU tick deltas instead of a single boot-lifetime sample. The first sample now returns `nil`; subsequent samples return live usage percentage from the delta window.
- Collapsed memory collection into a single sampled `MemorySample` per snapshot so `memoryUsedBytes` and `memoryUsedPercent` are derived from one read.
- Changed `AppState.refresh()` into a main-actor entrypoint that schedules filesystem-heavy work onto a utility queue, then publishes the finished snapshot back on the main actor.
- Prevented overlapping refresh work in `AppState` with an in-flight guard so scheduler/UI calls do not stack concurrent disk/cache/quota scans.
- Added focused Task 5 tests covering CPU delta semantics, single memory sampling, off-main refresh work, and overlapping-refresh suppression.
- Added narrow sendability annotations for the Task 5 monitor/store types used across the background refresh boundary.

### Tests run and results

- Ran:
  - `/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild test -project /Users/laosuer/Xcode/60714SeeS/MacStatusCodexMonitor.xcodeproj -scheme MacStatusCodexMonitor -destination 'platform=macOS' -derivedDataPath /private/tmp/MacStatusCodexMonitor-task5-fix-deriveddata`
- Result:
  - Build and test bundle compilation completed, but XCTest execution was blocked by the sandbox:
  - `MacStatusCodexMonitor encountered an error (Failed to establish communication with the test runner. (Underlying Error: Couldn’t communicate with a helper application... com.apple.testmanagerd.control ... Sandbox restriction.))`

- Ran:
  - `/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild build-for-testing -project /Users/laosuer/Xcode/60714SeeS/MacStatusCodexMonitor.xcodeproj -scheme MacStatusCodexMonitor -destination 'platform=macOS' -derivedDataPath /private/tmp/MacStatusCodexMonitor-task5-fix-deriveddata`
- Result:
  - `TEST BUILD SUCCEEDED`

- Ran:
  - `/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild build -project /Users/laosuer/Xcode/60714SeeS/MacStatusCodexMonitor.xcodeproj -scheme MacStatusCodexMonitor -destination 'platform=macOS' -derivedDataPath /private/tmp/MacStatusCodexMonitor-task5-fix-deriveddata-build`
- Result:
  - `BUILD SUCCEEDED`

### Files changed

- `MacStatusCodexMonitor/App/AppState.swift`
- `MacStatusCodexMonitor/Monitors/SystemMonitor.swift`
- `MacStatusCodexMonitor/Monitors/DiskGrowthStore.swift`
- `MacStatusCodexMonitor/Monitors/CacheAnalyzer.swift`
- `MacStatusCodexMonitor/Monitors/CodexQuotaReader.swift`
- `MacStatusCodexMonitorTests/AppStateTests.swift`
- `MacStatusCodexMonitorTests/SystemMonitorTests.swift`
- `MacStatusCodexMonitor.xcodeproj/project.pbxproj`

---

## Task 5 Re-review Fix

### What I fixed

- Removed `@unchecked Sendable` from `SystemMonitor`.
- Moved mutable CPU history into a private lock-backed `LockedCPUTickHistory` so shared `snapshot()` calls update/read `previousCPUTicks` under synchronization instead of unsafely mutating class state across executors.
- Kept the `SystemMonitor` surface area unchanged and limited the test changes to `SystemMonitor` coverage for the synchronized CPU-history path.
- Added a concurrent `snapshot()` regression test that coordinates two simultaneous callers and verifies they observe sequential CPU deltas rather than racing over the same baseline sample.

### Tests run and results

- Ran:
  - `/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild test -project /Users/laosuer/Xcode/60714SeeS/MacStatusCodexMonitor.xcodeproj -scheme MacStatusCodexMonitor -destination 'platform=macOS' -derivedDataPath /private/tmp/MacStatusCodexMonitor-task5-rereview-test`
- Result:
  - `Testing failed:`
  - `MacStatusCodexMonitor encountered an error (Failed to establish communication with the test runner. (Underlying Error: Couldn’t communicate with a helper application... com.apple.testmanagerd.control ... Sandbox restriction.))`
  - `IDETestOperationsObserverDebug: Failure collecting logarchive: Error Domain=NSCocoaErrorDomain Code=4099 "The connection to service named com.apple.testmanagerd.control was invalidated: Connection init failed at lookup with error 159 - Sandbox restriction."`

- Ran:
  - `/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild build-for-testing -project /Users/laosuer/Xcode/60714SeeS/MacStatusCodexMonitor.xcodeproj -scheme MacStatusCodexMonitor -destination 'platform=macOS' -derivedDataPath /private/tmp/MacStatusCodexMonitor-task5-rereview-bft2`
- Result:
  - `** TEST BUILD SUCCEEDED **`

- Ran:
  - `/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild build -project /Users/laosuer/Xcode/60714SeeS/MacStatusCodexMonitor.xcodeproj -scheme MacStatusCodexMonitor -destination 'platform=macOS' -derivedDataPath /private/tmp/MacStatusCodexMonitor-task5-rereview-build2`
- Result:
  - `** BUILD SUCCEEDED **`

### Files changed

- `MacStatusCodexMonitor/Monitors/SystemMonitor.swift`
- `MacStatusCodexMonitorTests/SystemMonitorTests.swift`

### Concerns

- The requested Task 5 fix is in place, but the project still emits a pre-existing `AppState.buildRefreshResult(...)` actor-isolation warning during Xcode builds. I left that untouched because this re-review was scoped to the `SystemMonitor` CPU-history sendability issue only.
