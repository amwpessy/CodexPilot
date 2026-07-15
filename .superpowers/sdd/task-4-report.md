# Task 4 Report: Disk History and Cache Estimation

## What I implemented

- Added [`DiskGrowthStore`](/Users/laosuer/Xcode/60714SeeS/MacStatusCodexMonitor/Monitors/DiskGrowthStore.swift) to persist `DiskSnapshot` history as JSON, keep 30 days of retained samples, reload sorted snapshots, and compute a `DiskGrowthSummary` with either:
  - `"24h history ready"` plus `growthBytes`, or
  - `"Learning: <hours>h history"` while the rolling history is still under 24 hours.
- Added [`CacheAnalyzer`](/Users/laosuer/Xcode/60714SeeS/MacStatusCodexMonitor/Monitors/CacheAnalyzer.swift) to estimate user-readable cache usage by scanning the default directories from the brief, summing regular-file sizes, sorting entries by size, and returning the top 8 in `CacheEstimate`.
- Added [`DiskGrowthStoreTests`](/Users/laosuer/Xcode/60714SeeS/MacStatusCodexMonitorTests/DiskGrowthStoreTests.swift) exactly as specified in the task brief.
- Updated [`project.pbxproj`](/Users/laosuer/Xcode/60714SeeS/MacStatusCodexMonitor.xcodeproj/project.pbxproj) to include the new monitor sources and the new test source in the correct targets/groups.

## What I tested and test results

- `plutil -lint /Users/laosuer/Xcode/60714SeeS/MacStatusCodexMonitor/Info.plist`
  - Result: `OK`
- `plutil -lint /Users/laosuer/Xcode/60714SeeS/MacStatusCodexMonitor.xcodeproj/project.pbxproj`
  - Result: `OK`
- `swift --version`
  - Result: `swift-driver version: 1.148.6 Apple Swift version 6.3.3`
- `git diff --check`
  - Result: no whitespace or patch-format issues
- `xcodebuild test -project /Users/laosuer/Xcode/60714SeeS/MacStatusCodexMonitor.xcodeproj -scheme MacStatusCodexMonitor -destination 'platform=macOS' -only-testing:MacStatusCodexMonitorTests/DiskGrowthStoreTests`
  - Result: failed before build/test execution because the active developer directory is Command Line Tools, not full Xcode:
    - `xcode-select: error: tool 'xcodebuild' requires Xcode, but active developer directory '/Library/Developer/CommandLineTools' is a command line tools instance`

## TDD Evidence

### RED

- Added the failing regression test file first: [`DiskGrowthStoreTests.swift`](/Users/laosuer/Xcode/60714SeeS/MacStatusCodexMonitorTests/DiskGrowthStoreTests.swift)
- Attempted the brief’s required RED command:
  - `xcodebuild test -project /Users/laosuer/Xcode/60714SeeS/MacStatusCodexMonitor.xcodeproj -scheme MacStatusCodexMonitor -destination 'platform=macOS' -only-testing:MacStatusCodexMonitorTests/DiskGrowthStoreTests`
  - Environment-limited result:
    - `xcode-select: error: tool 'xcodebuild' requires Xcode, but active developer directory '/Library/Developer/CommandLineTools' is a command line tools instance`
- Attempted a focused `swiftc` fallback harness to at least confirm missing-type compilation before implementation, but this environment also blocked that path due:
  - module-cache permission failure under `~/.cache/clang/ModuleCache`
  - local SDK/compiler mismatch between the installed Swift compiler and the selected Command Line Tools SDK

### GREEN

- Implemented [`DiskGrowthStore`](/Users/laosuer/Xcode/60714SeeS/MacStatusCodexMonitor/Monitors/DiskGrowthStore.swift) and [`CacheAnalyzer`](/Users/laosuer/Xcode/60714SeeS/MacStatusCodexMonitor/Monitors/CacheAnalyzer.swift)
- Updated [`project.pbxproj`](/Users/laosuer/Xcode/60714SeeS/MacStatusCodexMonitor.xcodeproj/project.pbxproj) to wire the files into the app/test targets
- Re-ran the available structural verification commands successfully:
  - `plutil -lint .../Info.plist` -> `OK`
  - `plutil -lint .../project.pbxproj` -> `OK`
  - `git diff --check` -> clean
- Re-ran the exact Xcode test command, but the environment still blocks runtime verification for the same `xcode-select` reason above.

## Files changed

- [`MacStatusCodexMonitor/Monitors/DiskGrowthStore.swift`](/Users/laosuer/Xcode/60714SeeS/MacStatusCodexMonitor/Monitors/DiskGrowthStore.swift)
- [`MacStatusCodexMonitor/Monitors/CacheAnalyzer.swift`](/Users/laosuer/Xcode/60714SeeS/MacStatusCodexMonitor/Monitors/CacheAnalyzer.swift)
- [`MacStatusCodexMonitorTests/DiskGrowthStoreTests.swift`](/Users/laosuer/Xcode/60714SeeS/MacStatusCodexMonitorTests/DiskGrowthStoreTests.swift)
- [`MacStatusCodexMonitor.xcodeproj/project.pbxproj`](/Users/laosuer/Xcode/60714SeeS/MacStatusCodexMonitor.xcodeproj/project.pbxproj)

## Self-review findings

- No logic issues found in the scoped self-review against the task brief.
- `DiskGrowthStore` matches the required interface and status strings.
- `CacheAnalyzer` stays within user-readable directories and does not attempt deletion or privileged access.

## Any issues or concerns

- Full RED/GREEN XCTest execution could not be completed in this environment because `xcodebuild` is unavailable without full Xcode selected.
- The fallback `swiftc` harness route is also impaired here by the Command Line Tools SDK/compiler mismatch, so the strongest available evidence is structural validation plus manual diff review.

---

## Review Fix Follow-up (2026-07-15)

### What I fixed

- Tightened [`DiskGrowthStore`](/Users/laosuer/Xcode/60714SeeS/MacStatusCodexMonitor/Monitors/DiskGrowthStore.swift) so 24-hour growth is only reported when a snapshot exists within a conservative 2-hour window around the 24-hour target. Sparse history now returns `growthBytes = nil` and `Learning: sparse 24h history`.
- Stopped silent history destruction on corrupt JSON by introducing an internal throwing load path for `record(_:)`. When decode fails, the unreadable store is moved aside to `disk.json.corrupt` before fresh history is written.
- Expanded [`DiskGrowthStoreTests.swift`](/Users/laosuer/Xcode/60714SeeS/MacStatusCodexMonitorTests/DiskGrowthStoreTests.swift) to cover:
  - stale-gap overcounting
  - corrupt-store preservation
  - 30-day retention trimming
  - `CacheAnalyzer` sizing/sorting across temporary directories and regular files

### Tests run and results

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project /Users/laosuer/Xcode/60714SeeS/MacStatusCodexMonitor.xcodeproj -scheme MacStatusCodexMonitor -destination 'platform=macOS' -derivedDataPath /Users/laosuer/Xcode/60714SeeS/.derivedData -only-testing:MacStatusCodexMonitorTests/DiskGrowthStoreTests`
  - Result: build started, but runtime was blocked by sandboxed test runner communication.
  - Key output:
    - `Testing failed:`
    - `Failed to establish communication with the test runner`
    - `The connection to service named com.apple.testmanagerd.control was invalidated: Connection init failed at lookup with error 159 - Sandbox restriction.`

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swiftc -module-cache-path /Users/laosuer/Xcode/60714SeeS/.swift-module-cache -module-name MacStatusCodexMonitor /Users/laosuer/Xcode/60714SeeS/MacStatusCodexMonitor/Models/DiskSnapshot.swift /Users/laosuer/Xcode/60714SeeS/MacStatusCodexMonitor/Monitors/DiskGrowthStore.swift /Users/laosuer/Xcode/60714SeeS/MacStatusCodexMonitor/Monitors/CacheAnalyzer.swift /Users/laosuer/Xcode/60714SeeS/.tmp-task4-red-harness.swift -o /private/tmp/task4-red-harness && /private/tmp/task4-red-harness`
  - RED result before the fix:
    - `Fatal error: Expected sparse history learning state, got growth=Optional(120) status=24h history ready`
  - GREEN result after the fix:
    - exit code `0`
    - no stderr/stdout output

- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build-for-testing -project /Users/laosuer/Xcode/60714SeeS/MacStatusCodexMonitor.xcodeproj -scheme MacStatusCodexMonitor -destination 'platform=macOS' -derivedDataPath /Users/laosuer/Xcode/60714SeeS/.derivedData -only-testing:MacStatusCodexMonitorTests/DiskGrowthStoreTests`
  - Result: passed compile/build verification.
  - Key output:
    - `** TEST BUILD SUCCEEDED **`

### Files changed

- [`MacStatusCodexMonitor/Monitors/DiskGrowthStore.swift`](/Users/laosuer/Xcode/60714SeeS/MacStatusCodexMonitor/Monitors/DiskGrowthStore.swift)
- [`MacStatusCodexMonitorTests/DiskGrowthStoreTests.swift`](/Users/laosuer/Xcode/60714SeeS/MacStatusCodexMonitorTests/DiskGrowthStoreTests.swift)
