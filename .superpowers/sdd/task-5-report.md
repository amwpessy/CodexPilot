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

---

## Task 5 Final Re-review Fix

### What I fixed

- Serialized CPU sample acquisition and CPU baseline mutation together inside `LockedCPUTickHistory.sampleDelta(using:)`, so `SystemMonitor.snapshot(previousIO:)` can no longer fetch ticks in one order and swap baselines in another.
- Simplified the CPU concurrency regression test to verify the synchronized helper behavior through `SystemMonitor`: concurrent snapshot callers now prove the injected `cpuTicksProvider` never overlaps and still produce the expected sequential delta percentages.
- Moved refresh result construction out of `@MainActor AppState` into a private file-level helper, removing the background call to the actor-isolated `AppState.buildRefreshResult(...)` method.

### Tests run and results, including exact commands/output and whether warnings remain

- Ran:
  - `/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild build-for-testing -project /Users/laosuer/Xcode/60714SeeS/MacStatusCodexMonitor.xcodeproj -scheme MacStatusCodexMonitor -destination 'platform=macOS' -derivedDataPath /private/tmp/MacStatusCodexMonitor-task5-finalfix-bft`
- Result:
  - `** TEST BUILD SUCCEEDED **`
  - The prior actor-isolation warning about `AppState.buildRefreshResult(...)` did not appear.
  - Remaining warnings were unrelated to the requested fix:
    - `MacStatusCodexMonitorTests: ld: warning: building for macOS-13.0, but linking with dylib '@rpath/XCTest.framework/Versions/A/XCTest' which was built for newer version 14.0`
    - `MacStatusCodexMonitorTests: ld: warning: building for macOS-13.0, but linking with dylib '@rpath/libXCTestSwiftSupport.dylib' which was built for newer version 14.0`

- Ran:
  - `/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild build -project /Users/laosuer/Xcode/60714SeeS/MacStatusCodexMonitor.xcodeproj -scheme MacStatusCodexMonitor -destination 'platform=macOS' -derivedDataPath /private/tmp/MacStatusCodexMonitor-task5-finalfix-build`
- Result:
  - `** BUILD SUCCEEDED **`
  - The prior actor-isolation warning about `AppState.buildRefreshResult(...)` did not appear.

- Ran:
  - `/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild test -project /Users/laosuer/Xcode/60714SeeS/MacStatusCodexMonitor.xcodeproj -scheme MacStatusCodexMonitor -destination 'platform=macOS' -derivedDataPath /private/tmp/MacStatusCodexMonitor-task5-finalfix-test`
- Result:
  - `Testing failed:`
  - `MacStatusCodexMonitor encountered an error (Failed to establish communication with the test runner. (Underlying Error: Couldn’t communicate with a helper application. Try your operation again. If that fails, quit and relaunch the application and try again. The connection to service named com.apple.testmanagerd.control was invalidated: Connection init failed at lookup with error 159 - Sandbox restriction.))`
  - `IDETestOperationsObserverDebug: Failure collecting logarchive: Error Domain=NSCocoaErrorDomain Code=4099 "The connection to service named com.apple.testmanagerd.control was invalidated: Connection init failed at lookup with error 159 - Sandbox restriction."`

### Files changed

- `MacStatusCodexMonitor/App/AppState.swift`
- `MacStatusCodexMonitor/Monitors/SystemMonitor.swift`
- `MacStatusCodexMonitorTests/SystemMonitorTests.swift`

---

## Task 5 Sendability Gate Fix

### What I fixed

- Removed the remaining production `@unchecked Sendable` annotations from:
  - `MacStatusCodexMonitor/Monitors/SystemMonitor.swift`
  - `MacStatusCodexMonitor/Monitors/CacheAnalyzer.swift`
  - `MacStatusCodexMonitor/Monitors/DiskGrowthStore.swift`
  - `MacStatusCodexMonitor/Monitors/CodexQuotaReader.swift`
- Replaced the unsafe CPU-history wrapper with `OSAllocatedUnfairLock` state in `LockedCPUTickHistory`, keeping CPU sample acquisition and baseline mutation serialized together.
- Converted `CacheAnalyzer`, `DiskGrowthStore`, and `CodexQuotaReader` into Sendable value types that keep only configuration in stored state and create `FileManager.default` at use sites, so no non-Sendable reference state crosses the refresh queue boundary.
- Updated the sendability-sensitive test doubles in `AppStateTests` and the CPU sample source in `SystemMonitorTests` so the remaining test/build output reflects environment issues rather than Swift 6 sendability warnings.

### Tests/builds run and results, including whether any production `@unchecked Sendable` remains

- Ran:
  - `rg -n "@unchecked Sendable" /Users/laosuer/Xcode/60714SeeS/MacStatusCodexMonitor /Users/laosuer/Xcode/60714SeeS/MacStatusCodexMonitorTests`
- Result:
  - Only test helper `MacStatusCodexMonitorTests/SystemMonitorTests.swift:115` still contains `@unchecked Sendable`.
  - No production `@unchecked Sendable` remains under `MacStatusCodexMonitor/`.

- Ran:
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build -project /Users/laosuer/Xcode/60714SeeS/MacStatusCodexMonitor.xcodeproj -scheme MacStatusCodexMonitor -destination 'platform=macOS' -derivedDataPath /private/tmp/task5-derived-data-build`
- Result:
  - `** BUILD SUCCEEDED **`
  - No Swift sendability warnings were emitted from project sources.

- Ran:
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build-for-testing -project /Users/laosuer/Xcode/60714SeeS/MacStatusCodexMonitor.xcodeproj -scheme MacStatusCodexMonitor -destination 'platform=macOS' -derivedDataPath /private/tmp/task5-derived-data-bft-2`
- Result:
  - `** TEST BUILD SUCCEEDED **`
  - Test-only Swift sendability warnings were cleared.
  - Remaining warnings were environment/toolchain warnings:
    - `MacStatusCodexMonitorTests: ld: warning: building for macOS-13.0, but linking with dylib '@rpath/XCTest.framework/Versions/A/XCTest' which was built for newer version 14.0`
    - `MacStatusCodexMonitorTests: ld: warning: building for macOS-13.0, but linking with dylib '@rpath/libXCTestSwiftSupport.dylib' which was built for newer version 14.0`
    - `warning: Metadata extraction skipped. No AppIntents.framework dependency found.`

- Ran:
  - `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project /Users/laosuer/Xcode/60714SeeS/MacStatusCodexMonitor.xcodeproj -scheme MacStatusCodexMonitor -destination 'platform=macOS' -derivedDataPath /private/tmp/task5-derived-data-test`
- Result:
  - `** TEST FAILED **`
  - Failure is the expected sandboxed runner issue, not a build/source failure:
    - `The connection to service named com.apple.testmanagerd.control was invalidated: Connection init failed at lookup with error 159 - Sandbox restriction.`
    - `attempt to post distributed notification 'IDETestProgressNotification' thwarted by sandboxing.`

### Files changed

- `MacStatusCodexMonitor/Monitors/CacheAnalyzer.swift`
- `MacStatusCodexMonitor/Monitors/CodexQuotaReader.swift`
- `MacStatusCodexMonitor/Monitors/DiskGrowthStore.swift`
- `MacStatusCodexMonitor/Monitors/SystemMonitor.swift`
- `MacStatusCodexMonitorTests/AppStateTests.swift`
- `MacStatusCodexMonitorTests/SystemMonitorTests.swift`
