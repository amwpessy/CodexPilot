# Mac Status and Codex Quota Monitor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS SwiftUI app, openable in Xcode, that monitors Mac status, disk growth/cache estimates, local disk I/O, local Codex quota signals, and Touch Bar summaries.

**Architecture:** Create a focused SwiftUI/AppKit macOS app with model, collector, parser, persistence, and UI files split by responsibility. Use local-only system APIs and local Codex JSONL logs; each unavailable or private metric reports a clear degraded state. Generate a minimal `.xcodeproj` by hand because full Xcode project generators are not installed in this environment.

**Tech Stack:** Swift 6.3-compatible source, SwiftUI, AppKit, IOKit, Mach host APIs, Foundation JSON decoding, XCTest.

## Global Constraints

- The app must be a pure Swift/SwiftUI macOS project.
- The app must be openable directly in Xcode.
- The app must provide a menu bar item, dashboard window, and Touch Bar indicators.
- macOS deployment target: macOS 13 or later unless implementation requires newer APIs.
- No third-party dependency in version 1 unless strongly justified.
- Version 1 should avoid privileged helpers and full-disk access requirements.
- No cloud sync.
- No network calls in version 1.
- Codex quota is parsed from local Codex logs and must be labeled as a "local Codex log signal".
- The Codex parser must not display or index user conversation text.
- Cache scanning is limited to user-readable folders.
- Automatic cache deletion is out of scope.
- Guaranteed GPU utilization percentage is out of scope.

---

## File Structure

Create:

- `MacStatusCodexMonitor.xcodeproj/project.pbxproj`: minimal Xcode project with one macOS app target and one XCTest target.
- `MacStatusCodexMonitor/Info.plist`: bundle metadata.
- `MacStatusCodexMonitor/MacStatusCodexMonitorApp.swift`: SwiftUI app entry, app delegate bridge, shared state injection.
- `MacStatusCodexMonitor/App/AppDelegate.swift`: owns `NSStatusItem`, dashboard window behavior, Touch Bar registration.
- `MacStatusCodexMonitor/App/AppState.swift`: observable state and refresh orchestration.
- `MacStatusCodexMonitor/App/MonitoringScheduler.swift`: timer-driven sampling.
- `MacStatusCodexMonitor/Models/SystemSnapshot.swift`: system metric model types.
- `MacStatusCodexMonitor/Models/DiskSnapshot.swift`: disk snapshot model types.
- `MacStatusCodexMonitor/Models/CodexQuotaSnapshot.swift`: Codex quota model types.
- `MacStatusCodexMonitor/Utilities/ByteFormatter.swift`: byte and rate formatting.
- `MacStatusCodexMonitor/Utilities/PercentFormatter.swift`: percentage formatting.
- `MacStatusCodexMonitor/Monitors/SystemMonitor.swift`: CPU, memory, battery, disk capacity, disk I/O, GPU availability collection.
- `MacStatusCodexMonitor/Monitors/DiskGrowthStore.swift`: local disk snapshot persistence and 24-hour delta calculation.
- `MacStatusCodexMonitor/Monitors/CacheAnalyzer.swift`: user-cache directory sizing.
- `MacStatusCodexMonitor/Monitors/CodexQuotaReader.swift`: local Codex `rate_limits` JSONL parser.
- `MacStatusCodexMonitor/Views/DashboardView.swift`: main dashboard.
- `MacStatusCodexMonitor/Views/MetricTile.swift`: reusable compact metric tile.
- `MacStatusCodexMonitor/Views/MenuBarPopoverView.swift`: menu bar popover contents.
- `MacStatusCodexMonitor/TouchBar/TouchBarController.swift`: `NSTouchBar` items bound to latest state.
- `MacStatusCodexMonitorTests/CodexQuotaReaderTests.swift`: parser tests.
- `MacStatusCodexMonitorTests/DiskGrowthStoreTests.swift`: disk history tests.
- `MacStatusCodexMonitorTests/FormattingTests.swift`: unavailable/null and byte formatting tests.

---

### Task 1: Xcode Project Scaffold

**Files:**
- Create: `MacStatusCodexMonitor.xcodeproj/project.pbxproj`
- Create: `MacStatusCodexMonitor/Info.plist`
- Create: `MacStatusCodexMonitor/MacStatusCodexMonitorApp.swift`
- Create: `MacStatusCodexMonitor/App/AppDelegate.swift`
- Create: `MacStatusCodexMonitorTests/PlaceholderTests.swift`

**Interfaces:**
- Produces: `MacStatusCodexMonitorApp`, `AppDelegate`, one app target named `MacStatusCodexMonitor`, one test target named `MacStatusCodexMonitorTests`.
- Consumes: none.

- [ ] **Step 1: Create the minimal app entry files**

Create `MacStatusCodexMonitor/MacStatusCodexMonitorApp.swift`:

```swift
import SwiftUI

@main
struct MacStatusCodexMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
```

Create `MacStatusCodexMonitor/App/AppDelegate.swift`:

```swift
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
```

Create `MacStatusCodexMonitor/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>$(DEVELOPMENT_LANGUAGE)</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$(PRODUCT_NAME)</string>
    <key>CFBundlePackageType</key>
    <string>$(PRODUCT_BUNDLE_PACKAGE_TYPE)</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
</dict>
</plist>
```

Create `MacStatusCodexMonitorTests/PlaceholderTests.swift`:

```swift
import XCTest

final class PlaceholderTests: XCTestCase {
    func testProjectLoads() {
        XCTAssertTrue(true)
    }
}
```

- [ ] **Step 2: Create `project.pbxproj`**

Create a minimal Xcode project with:

- `objectVersion = 56`
- app product type `com.apple.product-type.application`
- test product type `com.apple.product-type.bundle.unit-test`
- `MACOSX_DEPLOYMENT_TARGET = 13.0`
- `PRODUCT_BUNDLE_IDENTIFIER = local.MacStatusCodexMonitor`
- Swift source files from the app and test folders
- frameworks: `SwiftUI.framework`, `AppKit.framework`, `IOKit.framework`, `XCTest.framework`

Use stable UUIDs generated once during implementation. Do not reference files that do not exist yet except files listed in later tasks; add later task files to the project as they are created.

- [ ] **Step 3: Verify the project opens structurally**

Run: `plutil -lint MacStatusCodexMonitor/Info.plist`

Expected: `MacStatusCodexMonitor/Info.plist: OK`

Run: `swift --version`

Expected: prints Apple Swift version.

Run if full Xcode is selected: `xcodebuild -project MacStatusCodexMonitor.xcodeproj -scheme MacStatusCodexMonitor -list`

Expected with full Xcode: lists the `MacStatusCodexMonitor` scheme.

Expected in the current environment: may fail with `xcode-select: error: tool 'xcodebuild' requires Xcode` because the active developer directory is Command Line Tools.

- [ ] **Step 4: Commit**

```bash
git add MacStatusCodexMonitor.xcodeproj MacStatusCodexMonitor MacStatusCodexMonitorTests
git commit -m "feat: scaffold mac monitor app"
```

---

### Task 2: Models and Formatting

**Files:**
- Create: `MacStatusCodexMonitor/Models/SystemSnapshot.swift`
- Create: `MacStatusCodexMonitor/Models/DiskSnapshot.swift`
- Create: `MacStatusCodexMonitor/Models/CodexQuotaSnapshot.swift`
- Create: `MacStatusCodexMonitor/Utilities/ByteFormatter.swift`
- Create: `MacStatusCodexMonitor/Utilities/PercentFormatter.swift`
- Create: `MacStatusCodexMonitorTests/FormattingTests.swift`
- Modify: `MacStatusCodexMonitor.xcodeproj/project.pbxproj`

**Interfaces:**
- Produces:
  - `struct SystemSnapshot`
  - `struct DiskCapacity`
  - `struct DiskIOSnapshot`
  - `struct DiskSnapshot: Codable`
  - `struct CacheEstimate`
  - `struct CodexQuotaSnapshot`
  - `enum Availability<Value>`
  - `ByteFormatterUtility.string(bytes:)`
  - `ByteFormatterUtility.rate(bytesPerSecond:)`
  - `PercentFormatterUtility.string(_:)`
- Consumes: app target and test target from Task 1.

- [ ] **Step 1: Write formatting tests**

Create `MacStatusCodexMonitorTests/FormattingTests.swift`:

```swift
import XCTest
@testable import MacStatusCodexMonitor

final class FormattingTests: XCTestCase {
    func testByteFormatterUsesReadableUnits() {
        XCTAssertEqual(ByteFormatterUtility.string(bytes: 0), "0 B")
        XCTAssertEqual(ByteFormatterUtility.string(bytes: 1_536), "1.5 KB")
        XCTAssertEqual(ByteFormatterUtility.string(bytes: 1_073_741_824), "1 GB")
    }

    func testRateFormatterAddsPerSecond() {
        XCTAssertEqual(ByteFormatterUtility.rate(bytesPerSecond: 1_048_576), "1 MB/s")
    }

    func testPercentFormatterHandlesNil() {
        XCTAssertEqual(PercentFormatterUtility.string(nil), "Not reported")
        XCTAssertEqual(PercentFormatterUtility.string(42.4), "42%")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run if full Xcode is selected:

```bash
xcodebuild test -project MacStatusCodexMonitor.xcodeproj -scheme MacStatusCodexMonitor -destination 'platform=macOS'
```

Expected: FAIL because `ByteFormatterUtility` and `PercentFormatterUtility` are not defined.

- [ ] **Step 3: Create model and formatter implementations**

Create `MacStatusCodexMonitor/Models/SystemSnapshot.swift`:

```swift
import Foundation

enum Availability<Value> {
    case available(Value)
    case unavailable(String)

    var value: Value? {
        if case let .available(value) = self { return value }
        return nil
    }

    var message: String? {
        if case let .unavailable(message) = self { return message }
        return nil
    }
}

struct SystemSnapshot {
    var timestamp: Date
    var cpuUsage: Double?
    var memoryUsedPercent: Double?
    var memoryUsedBytes: UInt64?
    var memoryTotalBytes: UInt64?
    var battery: BatterySnapshot
    var diskCapacity: DiskCapacity
    var diskIO: DiskIOSnapshot
    var gpu: Availability<GPUSnapshot>
}

struct BatterySnapshot {
    var percent: Double?
    var isCharging: Bool?
    var timeRemainingMinutes: Int?
    var statusText: String
}

struct DiskCapacity {
    var totalBytes: UInt64
    var availableBytes: UInt64

    var usedBytes: UInt64 {
        totalBytes > availableBytes ? totalBytes - availableBytes : 0
    }

    var usedPercent: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes) * 100
    }
}

struct DiskIOSnapshot {
    var readBytesPerSecond: UInt64?
    var writeBytesPerSecond: UInt64?
    var readBytes24h: UInt64?
    var writeBytes24h: UInt64?
    var sourceDescription: String
}

struct GPUSnapshot {
    var name: String
    var utilizationPercent: Double?
}
```

Create `MacStatusCodexMonitor/Models/DiskSnapshot.swift`:

```swift
import Foundation

struct DiskSnapshot: Codable, Equatable {
    var timestamp: Date
    var availableBytes: UInt64
    var totalBytes: UInt64
}

struct DiskGrowthSummary: Equatable {
    var latest: DiskSnapshot?
    var baseline: DiskSnapshot?
    var growthBytes: Int64?
    var observedHours: Double
    var statusText: String
}

struct CacheEstimate: Equatable {
    struct Entry: Equatable, Identifiable {
        var id: String { path }
        var path: String
        var bytes: UInt64
    }

    var totalBytes: UInt64
    var entries: [Entry]
    var scannedAt: Date
    var statusText: String
}
```

Create `MacStatusCodexMonitor/Models/CodexQuotaSnapshot.swift`:

```swift
import Foundation

struct CodexQuotaSnapshot: Equatable {
    var sourceDescription: String
    var freshness: Date?
    var limitID: String?
    var usedPercent: Double?
    var remainingPercent: Double?
    var resetsAt: Date?
    var windowMinutes: Int?
    var planType: String?
    var creditsDescription: String
    var individualLimitDescription: String
    var rateLimitReachedType: String?

    static let unavailable = CodexQuotaSnapshot(
        sourceDescription: "local Codex log signal",
        freshness: nil,
        limitID: nil,
        usedPercent: nil,
        remainingPercent: nil,
        resetsAt: nil,
        windowMinutes: nil,
        planType: nil,
        creditsDescription: "Not reported",
        individualLimitDescription: "Not reported",
        rateLimitReachedType: nil
    )
}
```

Create `MacStatusCodexMonitor/Utilities/ByteFormatter.swift`:

```swift
import Foundation

enum ByteFormatterUtility {
    static func string(bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.includesCount = true
        return formatter.string(fromByteCount: Int64(bytes))
    }

    static func signedString(bytes: Int64) -> String {
        let sign = bytes > 0 ? "+" : ""
        return "\(sign)\(string(bytes: UInt64(abs(bytes))))"
    }

    static func rate(bytesPerSecond: UInt64) -> String {
        "\(string(bytes: bytesPerSecond))/s"
    }
}
```

Create `MacStatusCodexMonitor/Utilities/PercentFormatter.swift`:

```swift
import Foundation

enum PercentFormatterUtility {
    static func string(_ percent: Double?) -> String {
        guard let percent else { return "Not reported" }
        return "\(Int(percent.rounded()))%"
    }
}
```

- [ ] **Step 4: Add files to project and run tests**

Add all new Swift files to the app target. Add `FormattingTests.swift` to the test target.

Run if full Xcode is selected:

```bash
xcodebuild test -project MacStatusCodexMonitor.xcodeproj -scheme MacStatusCodexMonitor -destination 'platform=macOS'
```

Expected: PASS for `FormattingTests`.

- [ ] **Step 5: Commit**

```bash
git add MacStatusCodexMonitor MacStatusCodexMonitorTests MacStatusCodexMonitor.xcodeproj
git commit -m "feat: add monitor models and formatters"
```

---

### Task 3: Codex Quota Parser

**Files:**
- Create: `MacStatusCodexMonitor/Monitors/CodexQuotaReader.swift`
- Create: `MacStatusCodexMonitorTests/CodexQuotaReaderTests.swift`
- Modify: `MacStatusCodexMonitor.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: `CodexQuotaSnapshot` from Task 2.
- Produces:
  - `final class CodexQuotaReader`
  - `init(root: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex/sessions"))`
  - `func latestQuotaSnapshot() -> CodexQuotaSnapshot`
  - `func parseLine(_ line: String, fileModifiedAt: Date?) -> CodexQuotaSnapshot?`

- [ ] **Step 1: Write parser tests**

Create `MacStatusCodexMonitorTests/CodexQuotaReaderTests.swift`:

```swift
import XCTest
@testable import MacStatusCodexMonitor

final class CodexQuotaReaderTests: XCTestCase {
    func testParsesRateLimitEvent() {
        let line = """
        {"timestamp":"2026-07-15T07:55:30.701Z","type":"event_msg","payload":{"type":"token_count","rate_limits":{"limit_id":"codex","primary":{"used_percent":2.0,"window_minutes":10080,"resets_at":1784704630},"secondary":null,"credits":{"has_credits":false,"unlimited":false,"balance":null},"individual_limit":null,"plan_type":"team","rate_limit_reached_type":null}}}
        """

        let snapshot = CodexQuotaReader(root: URL(fileURLWithPath: "/tmp/none")).parseLine(line, fileModifiedAt: nil)

        XCTAssertEqual(snapshot?.limitID, "codex")
        XCTAssertEqual(snapshot?.usedPercent, 2.0)
        XCTAssertEqual(snapshot?.remainingPercent, 98.0)
        XCTAssertEqual(snapshot?.windowMinutes, 10080)
        XCTAssertEqual(snapshot?.planType, "team")
        XCTAssertEqual(snapshot?.creditsDescription, "No credits")
        XCTAssertEqual(snapshot?.sourceDescription, "local Codex log signal")
    }

    func testIgnoresConversationOnlyEvents() {
        let line = #"{"timestamp":"2026-07-15T07:55:30.701Z","type":"event_msg","payload":{"type":"agent_message","text":"hello"}}"#
        XCTAssertNil(CodexQuotaReader(root: URL(fileURLWithPath: "/tmp/none")).parseLine(line, fileModifiedAt: nil))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run if full Xcode is selected:

```bash
xcodebuild test -project MacStatusCodexMonitor.xcodeproj -scheme MacStatusCodexMonitor -destination 'platform=macOS' -only-testing:MacStatusCodexMonitorTests/CodexQuotaReaderTests
```

Expected: FAIL because `CodexQuotaReader` is not defined.

- [ ] **Step 3: Implement parser**

Create `MacStatusCodexMonitor/Monitors/CodexQuotaReader.swift`:

```swift
import Foundation

final class CodexQuotaReader {
    private let root: URL
    private let fileManager: FileManager

    init(root: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex/sessions"),
         fileManager: FileManager = .default) {
        self.root = root
        self.fileManager = fileManager
    }

    func latestQuotaSnapshot() -> CodexQuotaSnapshot {
        let files = jsonlFiles(in: root)
        var latest: CodexQuotaSnapshot?

        for file in files {
            guard let text = try? String(contentsOf: file, encoding: .utf8) else { continue }
            let modifiedAt = (try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? nil
            for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
                guard let snapshot = parseLine(String(line), fileModifiedAt: modifiedAt) else { continue }
                if (snapshot.freshness ?? .distantPast) >= (latest?.freshness ?? .distantPast) {
                    latest = snapshot
                }
            }
        }

        return latest ?? .unavailable
    }

    func parseLine(_ line: String, fileModifiedAt: Date?) -> CodexQuotaSnapshot? {
        guard let data = line.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let payload = object["payload"] as? [String: Any],
              let rateLimits = payload["rate_limits"] as? [String: Any] else {
            return nil
        }

        let timestamp = (object["timestamp"] as? String).flatMap(Self.isoDate(_:)) ?? fileModifiedAt
        let primary = rateLimits["primary"] as? [String: Any]
        let usedPercent = primary?["used_percent"] as? Double
        let resetsAt = (primary?["resets_at"] as? TimeInterval).map { Date(timeIntervalSince1970: $0) }
        let windowMinutes = primary?["window_minutes"] as? Int
        let credits = Self.creditsDescription(rateLimits["credits"])
        let individualLimit = rateLimits["individual_limit"].map(Self.describeJSONValue) ?? "Not reported"
        let remaining = usedPercent.map { max(0, min(100, 100 - $0)) }

        return CodexQuotaSnapshot(
            sourceDescription: "local Codex log signal",
            freshness: timestamp,
            limitID: rateLimits["limit_id"] as? String,
            usedPercent: usedPercent,
            remainingPercent: remaining,
            resetsAt: resetsAt,
            windowMinutes: windowMinutes,
            planType: rateLimits["plan_type"] as? String,
            creditsDescription: credits,
            individualLimitDescription: individualLimit,
            rateLimitReachedType: rateLimits["rate_limit_reached_type"] as? String
        )
    }

    private func jsonlFiles(in root: URL) -> [URL] {
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return enumerator.compactMap { item in
            guard let url = item as? URL, url.pathExtension == "jsonl" else { return nil }
            return url
        }
    }

    private static func isoDate(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: string)
    }

    private static func creditsDescription(_ value: Any?) -> String {
        guard let dict = value as? [String: Any] else { return "Not reported" }
        let hasCredits = dict["has_credits"] as? Bool
        let unlimited = dict["unlimited"] as? Bool
        let balance = dict["balance"]

        if unlimited == true { return "Unlimited credits" }
        if hasCredits == false { return "No credits" }
        if let balance, !(balance is NSNull) { return "Balance: \(describeJSONValue(balance))" }
        return hasCredits == true ? "Credits available" : "Not reported"
    }

    private static func describeJSONValue(_ value: Any) -> String {
        if value is NSNull { return "Not reported" }
        if let string = value as? String { return string }
        if let number = value as? NSNumber { return number.stringValue }
        if JSONSerialization.isValidJSONObject(value),
           let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]),
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        return "\(value)"
    }
}
```

- [ ] **Step 4: Add file to project and run tests**

Run if full Xcode is selected:

```bash
xcodebuild test -project MacStatusCodexMonitor.xcodeproj -scheme MacStatusCodexMonitor -destination 'platform=macOS' -only-testing:MacStatusCodexMonitorTests/CodexQuotaReaderTests
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add MacStatusCodexMonitor/Monitors/CodexQuotaReader.swift MacStatusCodexMonitorTests/CodexQuotaReaderTests.swift MacStatusCodexMonitor.xcodeproj
git commit -m "feat: parse local codex quota signals"
```

---

### Task 4: Disk History and Cache Estimation

**Files:**
- Create: `MacStatusCodexMonitor/Monitors/DiskGrowthStore.swift`
- Create: `MacStatusCodexMonitor/Monitors/CacheAnalyzer.swift`
- Create: `MacStatusCodexMonitorTests/DiskGrowthStoreTests.swift`
- Modify: `MacStatusCodexMonitor.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: `DiskSnapshot`, `DiskGrowthSummary`, `CacheEstimate`.
- Produces:
  - `final class DiskGrowthStore`
  - `func record(_ snapshot: DiskSnapshot) throws`
  - `func loadSnapshots() -> [DiskSnapshot]`
  - `func growthSummary(now: Date) -> DiskGrowthSummary`
  - `final class CacheAnalyzer`
  - `func estimate() -> CacheEstimate`

- [ ] **Step 1: Write disk history tests**

Create `MacStatusCodexMonitorTests/DiskGrowthStoreTests.swift`:

```swift
import XCTest
@testable import MacStatusCodexMonitor

final class DiskGrowthStoreTests: XCTestCase {
    func testComputesTwentyFourHourGrowthFromAvailableSpaceDrop() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = DiskGrowthStore(storageURL: directory.appendingPathComponent("disk.json"))
        let now = Date(timeIntervalSince1970: 10_000_000)

        try store.record(DiskSnapshot(timestamp: now.addingTimeInterval(-25 * 3600), availableBytes: 900, totalBytes: 1_000))
        try store.record(DiskSnapshot(timestamp: now, availableBytes: 750, totalBytes: 1_000))

        let summary = store.growthSummary(now: now)

        XCTAssertEqual(summary.growthBytes, 150)
        XCTAssertEqual(summary.statusText, "24h history ready")
    }

    func testReportsLearningWhenHistoryIsShort() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = DiskGrowthStore(storageURL: directory.appendingPathComponent("disk.json"))
        let now = Date(timeIntervalSince1970: 10_000_000)

        try store.record(DiskSnapshot(timestamp: now.addingTimeInterval(-2 * 3600), availableBytes: 900, totalBytes: 1_000))
        try store.record(DiskSnapshot(timestamp: now, availableBytes: 800, totalBytes: 1_000))

        let summary = store.growthSummary(now: now)

        XCTAssertNil(summary.growthBytes)
        XCTAssertEqual(summary.statusText, "Learning: 2.0h history")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run if full Xcode is selected:

```bash
xcodebuild test -project MacStatusCodexMonitor.xcodeproj -scheme MacStatusCodexMonitor -destination 'platform=macOS' -only-testing:MacStatusCodexMonitorTests/DiskGrowthStoreTests
```

Expected: FAIL because `DiskGrowthStore` is not defined.

- [ ] **Step 3: Implement disk growth store**

Create `MacStatusCodexMonitor/Monitors/DiskGrowthStore.swift`:

```swift
import Foundation

final class DiskGrowthStore {
    private let storageURL: URL
    private let retention: TimeInterval = 30 * 24 * 3600

    init(storageURL: URL = DiskGrowthStore.defaultStorageURL()) {
        self.storageURL = storageURL
    }

    func record(_ snapshot: DiskSnapshot) throws {
        var snapshots = loadSnapshots()
        snapshots.append(snapshot)
        let cutoff = snapshot.timestamp.addingTimeInterval(-retention)
        snapshots = snapshots.filter { $0.timestamp >= cutoff }.sorted { $0.timestamp < $1.timestamp }
        try FileManager.default.createDirectory(at: storageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder.diskSnapshotEncoder.encode(snapshots)
        try data.write(to: storageURL, options: [.atomic])
    }

    func loadSnapshots() -> [DiskSnapshot] {
        guard let data = try? Data(contentsOf: storageURL),
              let snapshots = try? JSONDecoder.diskSnapshotDecoder.decode([DiskSnapshot].self, from: data) else {
            return []
        }
        return snapshots.sorted { $0.timestamp < $1.timestamp }
    }

    func growthSummary(now: Date) -> DiskGrowthSummary {
        let snapshots = loadSnapshots()
        guard let latest = snapshots.last else {
            return DiskGrowthSummary(latest: nil, baseline: nil, growthBytes: nil, observedHours: 0, statusText: "No disk history yet")
        }

        let target = now.addingTimeInterval(-24 * 3600)
        guard let earliest = snapshots.first else {
            return DiskGrowthSummary(latest: latest, baseline: nil, growthBytes: nil, observedHours: 0, statusText: "No disk history yet")
        }

        let observedHours = latest.timestamp.timeIntervalSince(earliest.timestamp) / 3600
        guard observedHours >= 24 else {
            return DiskGrowthSummary(
                latest: latest,
                baseline: earliest,
                growthBytes: nil,
                observedHours: observedHours,
                statusText: String(format: "Learning: %.1fh history", observedHours)
            )
        }

        let baseline = snapshots.last(where: { $0.timestamp <= target }) ?? earliest
        let growth = Int64(baseline.availableBytes) - Int64(latest.availableBytes)
        return DiskGrowthSummary(
            latest: latest,
            baseline: baseline,
            growthBytes: growth,
            observedHours: observedHours,
            statusText: "24h history ready"
        )
    }

    static func defaultStorageURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return appSupport.appendingPathComponent("MacStatusCodexMonitor/disk-snapshots.json")
    }
}

private extension JSONEncoder {
    static var diskSnapshotEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    static var diskSnapshotDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
```

- [ ] **Step 4: Implement cache analyzer**

Create `MacStatusCodexMonitor/Monitors/CacheAnalyzer.swift`:

```swift
import Foundation

final class CacheAnalyzer {
    private let directories: [URL]
    private let fileManager: FileManager

    init(directories: [URL] = CacheAnalyzer.defaultDirectories(), fileManager: FileManager = .default) {
        self.directories = directories
        self.fileManager = fileManager
    }

    func estimate() -> CacheEstimate {
        let entries = directories.compactMap { directory -> CacheEstimate.Entry? in
            let bytes = directorySize(directory)
            guard bytes > 0 else { return nil }
            return CacheEstimate.Entry(path: directory.path, bytes: bytes)
        }.sorted { $0.bytes > $1.bytes }

        let total = entries.reduce(UInt64(0)) { $0 + $1.bytes }
        return CacheEstimate(
            totalBytes: total,
            entries: Array(entries.prefix(8)),
            scannedAt: Date(),
            statusText: "User-cache estimate"
        )
    }

    private func directorySize(_ url: URL) -> UInt64 {
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return 0 }

        var total: UInt64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                  values.isRegularFile == true,
                  let size = values.fileSize else { continue }
            total += UInt64(max(0, size))
        }
        return total
    }

    static func defaultDirectories() -> [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            home.appendingPathComponent("Library/Caches"),
            home.appendingPathComponent("Library/Logs"),
            home.appendingPathComponent("Library/Developer/Xcode/DerivedData"),
            home.appendingPathComponent("Library/Developer/Xcode/Archives"),
            home.appendingPathComponent("Library/Developer/CoreSimulator/Caches")
        ]
    }
}
```

- [ ] **Step 5: Add files to project and run tests**

Run if full Xcode is selected:

```bash
xcodebuild test -project MacStatusCodexMonitor.xcodeproj -scheme MacStatusCodexMonitor -destination 'platform=macOS' -only-testing:MacStatusCodexMonitorTests/DiskGrowthStoreTests
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add MacStatusCodexMonitor/Monitors/DiskGrowthStore.swift MacStatusCodexMonitor/Monitors/CacheAnalyzer.swift MacStatusCodexMonitorTests/DiskGrowthStoreTests.swift MacStatusCodexMonitor.xcodeproj
git commit -m "feat: track disk growth and cache estimates"
```

---

### Task 5: System Monitor and Scheduler

**Files:**
- Create: `MacStatusCodexMonitor/Monitors/SystemMonitor.swift`
- Create: `MacStatusCodexMonitor/App/AppState.swift`
- Create: `MacStatusCodexMonitor/App/MonitoringScheduler.swift`
- Modify: `MacStatusCodexMonitor.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: models, `DiskGrowthStore`, `CacheAnalyzer`, `CodexQuotaReader`.
- Produces:
  - `final class SystemMonitor`
  - `func snapshot(previousIO: DiskIOSnapshot?) -> SystemSnapshot`
  - `@MainActor final class AppState: ObservableObject`
  - `func refresh()`
  - `final class MonitoringScheduler`
  - `func start(interval: TimeInterval, refresh: @escaping () -> Void)`
  - `func stop()`

- [ ] **Step 1: Implement scheduler**

Create `MacStatusCodexMonitor/App/MonitoringScheduler.swift`:

```swift
import Foundation

final class MonitoringScheduler {
    private var timer: Timer?

    func start(interval: TimeInterval, refresh: @escaping () -> Void) {
        stop()
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            refresh()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}
```

- [ ] **Step 2: Implement system monitor**

Create `MacStatusCodexMonitor/Monitors/SystemMonitor.swift`:

```swift
import Foundation
import IOKit.ps
import MachO

final class SystemMonitor {
    func snapshot(previousIO: DiskIOSnapshot? = nil) -> SystemSnapshot {
        let capacity = diskCapacity()
        return SystemSnapshot(
            timestamp: Date(),
            cpuUsage: cpuUsage(),
            memoryUsedPercent: memoryUsedPercent(),
            memoryUsedBytes: memoryUsedBytes(),
            memoryTotalBytes: ProcessInfo.processInfo.physicalMemory,
            battery: batterySnapshot(),
            diskCapacity: capacity,
            diskIO: DiskIOSnapshot(
                readBytesPerSecond: nil,
                writeBytesPerSecond: nil,
                readBytes24h: nil,
                writeBytes24h: nil,
                sourceDescription: "System I/O estimate unavailable in v1 collector"
            ),
            gpu: gpuSnapshot()
        )
    }

    private func cpuUsage() -> Double? {
        var load = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &load) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        let user = Double(load.cpu_ticks.0)
        let system = Double(load.cpu_ticks.1)
        let idle = Double(load.cpu_ticks.2)
        let nice = Double(load.cpu_ticks.3)
        let total = user + system + idle + nice
        guard total > 0 else { return nil }
        return (total - idle) / total * 100
    }

    private func memoryUsedBytes() -> UInt64? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        let pageSize = UInt64(vm_kernel_page_size)
        let active = UInt64(stats.active_count) * pageSize
        let wired = UInt64(stats.wire_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize
        return active + wired + compressed
    }

    private func memoryUsedPercent() -> Double? {
        guard let used = memoryUsedBytes() else { return nil }
        let total = ProcessInfo.processInfo.physicalMemory
        guard total > 0 else { return nil }
        return Double(used) / Double(total) * 100
    }

    private func batterySnapshot() -> BatterySnapshot {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef],
              let source = sources.first,
              let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any] else {
            return BatterySnapshot(percent: nil, isCharging: nil, timeRemainingMinutes: nil, statusText: "No battery")
        }

        let current = description[kIOPSCurrentCapacityKey as String] as? Double
        let max = description[kIOPSMaxCapacityKey as String] as? Double
        let percent = current.flatMap { currentValue in
            max.flatMap { maxValue in maxValue > 0 ? currentValue / maxValue * 100 : nil }
        }
        let state = description[kIOPSPowerSourceStateKey as String] as? String
        let charging = state == kIOPSACPowerValue
        let minutes = description[kIOPSTimeToEmptyKey as String] as? Int
        return BatterySnapshot(percent: percent, isCharging: charging, timeRemainingMinutes: minutes, statusText: charging ? "Charging" : "On battery")
    }

    private func diskCapacity() -> DiskCapacity {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let keys: Set<URLResourceKey> = [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]
        let values = try? home.resourceValues(forKeys: keys)
        let total = UInt64(values?.volumeTotalCapacity ?? 0)
        let available = UInt64(values?.volumeAvailableCapacityForImportantUsage ?? 0)
        return DiskCapacity(totalBytes: total, availableBytes: available)
    }

    private func gpuSnapshot() -> Availability<GPUSnapshot> {
        .unavailable("GPU utilization unavailable through stable public API")
    }
}
```

- [ ] **Step 3: Implement app state**

Create `MacStatusCodexMonitor/App/AppState.swift`:

```swift
import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var system: SystemSnapshot
    @Published private(set) var diskGrowth: DiskGrowthSummary
    @Published private(set) var cacheEstimate: CacheEstimate
    @Published private(set) var codexQuota: CodexQuotaSnapshot

    private let systemMonitor: SystemMonitor
    private let diskStore: DiskGrowthStore
    private let cacheAnalyzer: CacheAnalyzer
    private let codexReader: CodexQuotaReader

    init(systemMonitor: SystemMonitor = SystemMonitor(),
         diskStore: DiskGrowthStore = DiskGrowthStore(),
         cacheAnalyzer: CacheAnalyzer = CacheAnalyzer(),
         codexReader: CodexQuotaReader = CodexQuotaReader()) {
        self.systemMonitor = systemMonitor
        self.diskStore = diskStore
        self.cacheAnalyzer = cacheAnalyzer
        self.codexReader = codexReader
        self.system = systemMonitor.snapshot()
        self.diskGrowth = diskStore.growthSummary(now: Date())
        self.cacheEstimate = CacheEstimate(totalBytes: 0, entries: [], scannedAt: Date(), statusText: "Not scanned yet")
        self.codexQuota = .unavailable
    }

    func refresh() {
        let snapshot = systemMonitor.snapshot(previousIO: system.diskIO)
        system = snapshot
        let diskSnapshot = DiskSnapshot(
            timestamp: snapshot.timestamp,
            availableBytes: snapshot.diskCapacity.availableBytes,
            totalBytes: snapshot.diskCapacity.totalBytes
        )
        try? diskStore.record(diskSnapshot)
        diskGrowth = diskStore.growthSummary(now: snapshot.timestamp)
        cacheEstimate = cacheAnalyzer.estimate()
        codexQuota = codexReader.latestQuotaSnapshot()
    }
}
```

- [ ] **Step 4: Add files to project and build**

Run if full Xcode is selected:

```bash
xcodebuild build -project MacStatusCodexMonitor.xcodeproj -scheme MacStatusCodexMonitor -destination 'platform=macOS'
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add MacStatusCodexMonitor/App MacStatusCodexMonitor/Monitors/SystemMonitor.swift MacStatusCodexMonitor.xcodeproj
git commit -m "feat: collect system and app state snapshots"
```

---

### Task 6: Dashboard and Menu Bar UI

**Files:**
- Create: `MacStatusCodexMonitor/Views/MetricTile.swift`
- Create: `MacStatusCodexMonitor/Views/DashboardView.swift`
- Create: `MacStatusCodexMonitor/Views/MenuBarPopoverView.swift`
- Modify: `MacStatusCodexMonitor/App/AppDelegate.swift`
- Modify: `MacStatusCodexMonitor/MacStatusCodexMonitorApp.swift`
- Modify: `MacStatusCodexMonitor.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: `AppState`.
- Produces:
  - `struct DashboardView: View`
  - `struct MenuBarPopoverView: View`
  - app delegate method `showDashboard()`

- [ ] **Step 1: Implement reusable metric tile**

Create `MacStatusCodexMonitor/Views/MetricTile.swift`:

```swift
import SwiftUI

struct MetricTile: View {
    var title: String
    var value: String
    var detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
```

- [ ] **Step 2: Implement dashboard**

Create `MacStatusCodexMonitor/Views/DashboardView.swift`:

```swift
import SwiftUI

struct DashboardView: View {
    @ObservedObject var state: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Mac Status & Codex")
                    .font(.largeTitle)
                    .fontWeight(.semibold)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
                    MetricTile(title: "CPU", value: PercentFormatterUtility.string(state.system.cpuUsage), detail: "Live sample")
                    MetricTile(title: "Memory", value: PercentFormatterUtility.string(state.system.memoryUsedPercent), detail: memoryDetail)
                    MetricTile(title: "Disk", value: PercentFormatterUtility.string(state.system.diskCapacity.usedPercent), detail: diskDetail)
                    MetricTile(title: "Codex", value: PercentFormatterUtility.string(state.codexQuota.remainingPercent), detail: codexDetail)
                }

                section("Battery & GPU") {
                    MetricTile(title: "Battery", value: batteryValue, detail: state.system.battery.statusText)
                    MetricTile(title: "GPU", value: gpuValue, detail: gpuDetail)
                }

                section("Disk Growth & Cache") {
                    MetricTile(title: "24h Growth", value: diskGrowthValue, detail: state.diskGrowth.statusText)
                    MetricTile(title: "Cache Estimate", value: ByteFormatterUtility.string(bytes: state.cacheEstimate.totalBytes), detail: state.cacheEstimate.statusText)
                    ForEach(state.cacheEstimate.entries) { entry in
                        HStack {
                            Text(entry.path).lineLimit(1).truncationMode(.middle)
                            Spacer()
                            Text(ByteFormatterUtility.string(bytes: entry.bytes)).foregroundStyle(.secondary)
                        }
                        .font(.caption)
                    }
                }

                section("Codex Quota") {
                    MetricTile(title: "Used", value: PercentFormatterUtility.string(state.codexQuota.usedPercent), detail: state.codexQuota.sourceDescription)
                    MetricTile(title: "Reset", value: resetValue, detail: "Plan: \(state.codexQuota.planType ?? "Not reported")")
                    MetricTile(title: "Credits", value: state.codexQuota.creditsDescription, detail: "Individual limit: \(state.codexQuota.individualLimitDescription)")
                }
            }
            .padding(20)
        }
        .frame(minWidth: 760, minHeight: 560)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            content()
        }
    }

    private var memoryDetail: String {
        guard let used = state.system.memoryUsedBytes, let total = state.system.memoryTotalBytes else { return "Not reported" }
        return "\(ByteFormatterUtility.string(bytes: used)) of \(ByteFormatterUtility.string(bytes: total))"
    }

    private var diskDetail: String {
        "\(ByteFormatterUtility.string(bytes: state.system.diskCapacity.availableBytes)) available"
    }

    private var codexDetail: String {
        if let reset = state.codexQuota.resetsAt {
            return "Resets \(reset.formatted(date: .abbreviated, time: .shortened))"
        }
        return "Reset not reported"
    }

    private var batteryValue: String {
        PercentFormatterUtility.string(state.system.battery.percent)
    }

    private var gpuValue: String {
        switch state.system.gpu {
        case .available(let gpu): return gpu.name
        case .unavailable: return "Unavailable"
        }
    }

    private var gpuDetail: String {
        switch state.system.gpu {
        case .available(let gpu): return PercentFormatterUtility.string(gpu.utilizationPercent)
        case .unavailable(let message): return message
        }
    }

    private var diskGrowthValue: String {
        guard let growth = state.diskGrowth.growthBytes else { return "Learning" }
        return ByteFormatterUtility.signedString(bytes: growth)
    }

    private var resetValue: String {
        state.codexQuota.resetsAt?.formatted(date: .abbreviated, time: .shortened) ?? "Not reported"
    }
}
```

- [ ] **Step 3: Implement menu bar popover view**

Create `MacStatusCodexMonitor/Views/MenuBarPopoverView.swift`:

```swift
import SwiftUI

struct MenuBarPopoverView: View {
    @ObservedObject var state: AppState
    var openDashboard: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Mac Status & Codex").font(.headline)
            Text("CPU \(PercentFormatterUtility.string(state.system.cpuUsage))")
            Text("Mem \(PercentFormatterUtility.string(state.system.memoryUsedPercent))")
            Text("Disk \(diskGrowthValue)")
            Text("Codex \(PercentFormatterUtility.string(state.codexQuota.remainingPercent)) left")
            Divider()
            Button("Open Dashboard", action: openDashboard)
            Button("Quit") { NSApp.terminate(nil) }
        }
        .padding(14)
        .frame(width: 260)
    }

    private var diskGrowthValue: String {
        guard let growth = state.diskGrowth.growthBytes else { return "Learning" }
        return ByteFormatterUtility.signedString(bytes: growth)
    }
}
```

- [ ] **Step 4: Wire app delegate UI**

Replace `MacStatusCodexMonitor/App/AppDelegate.swift` with:

```swift
import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let state = AppState()
    private let scheduler = MonitoringScheduler()
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var dashboardWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        installMenuBarItem()
        scheduler.start(interval: 30) { [weak self] in
            Task { @MainActor in
                self?.state.refresh()
                self?.updateMenuBarTitle()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        scheduler.stop()
    }

    func showDashboard() {
        if dashboardWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 860, height: 640),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Mac Status & Codex"
            window.contentView = NSHostingView(rootView: DashboardView(state: state))
            dashboardWindow = window
        }
        dashboardWindow?.center()
        dashboardWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func installMenuBarItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.target = self
        item.button?.action = #selector(togglePopover)
        statusItem = item
        updateMenuBarTitle()

        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 260, height: 220)
        popover.contentViewController = NSHostingController(rootView: MenuBarPopoverView(state: state) { [weak self] in
            self?.popover?.performClose(nil)
            self?.showDashboard()
        })
        self.popover = popover
    }

    private func updateMenuBarTitle() {
        let cpu = PercentFormatterUtility.string(state.system.cpuUsage)
        let codex = PercentFormatterUtility.string(state.codexQuota.remainingPercent)
        statusItem?.button?.title = "CPU \(cpu) Codex \(codex)"
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button, let popover else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}
```

- [ ] **Step 5: Add files to project and build**

Run if full Xcode is selected:

```bash
xcodebuild build -project MacStatusCodexMonitor.xcodeproj -scheme MacStatusCodexMonitor -destination 'platform=macOS'
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add MacStatusCodexMonitor/App MacStatusCodexMonitor/Views MacStatusCodexMonitor.xcodeproj
git commit -m "feat: add dashboard and menu bar UI"
```

---

### Task 7: Touch Bar Integration

**Files:**
- Create: `MacStatusCodexMonitor/TouchBar/TouchBarController.swift`
- Modify: `MacStatusCodexMonitor/App/AppDelegate.swift`
- Modify: `MacStatusCodexMonitor.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: `AppState`.
- Produces:
  - `final class TouchBarController: NSObject, NSTouchBarDelegate`
  - `func makeTouchBar() -> NSTouchBar`

- [ ] **Step 1: Implement Touch Bar controller**

Create `MacStatusCodexMonitor/TouchBar/TouchBarController.swift`:

```swift
import AppKit
import Combine

final class TouchBarController: NSObject, NSTouchBarDelegate {
    private let state: AppState
    private var cancellables: Set<AnyCancellable> = []
    private var labels: [NSTouchBarItem.Identifier: NSTextField] = [:]

    static let cpu = NSTouchBarItem.Identifier("local.MacStatusCodexMonitor.touchbar.cpu")
    static let memory = NSTouchBarItem.Identifier("local.MacStatusCodexMonitor.touchbar.memory")
    static let disk = NSTouchBarItem.Identifier("local.MacStatusCodexMonitor.touchbar.disk")
    static let battery = NSTouchBarItem.Identifier("local.MacStatusCodexMonitor.touchbar.battery")
    static let codex = NSTouchBarItem.Identifier("local.MacStatusCodexMonitor.touchbar.codex")

    init(state: AppState) {
        self.state = state
        super.init()
        state.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateLabels()
            }
        }.store(in: &cancellables)
    }

    func makeTouchBar() -> NSTouchBar {
        let touchBar = NSTouchBar()
        touchBar.delegate = self
        touchBar.defaultItemIdentifiers = [Self.cpu, Self.memory, Self.disk, Self.battery, Self.codex]
        return touchBar
    }

    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        let item = NSCustomTouchBarItem(identifier: identifier)
        let label = NSTextField(labelWithString: text(for: identifier))
        label.alignment = .center
        item.view = label
        labels[identifier] = label
        return item
    }

    private func updateLabels() {
        for (identifier, label) in labels {
            label.stringValue = text(for: identifier)
        }
    }

    private func text(for identifier: NSTouchBarItem.Identifier) -> String {
        switch identifier {
        case Self.cpu:
            return "CPU \(PercentFormatterUtility.string(state.system.cpuUsage))"
        case Self.memory:
            return "Mem \(PercentFormatterUtility.string(state.system.memoryUsedPercent))"
        case Self.disk:
            if let growth = state.diskGrowth.growthBytes {
                return "Disk \(ByteFormatterUtility.signedString(bytes: growth))"
            }
            return "Disk Learning"
        case Self.battery:
            return "Batt \(PercentFormatterUtility.string(state.system.battery.percent))"
        case Self.codex:
            return "Codex \(PercentFormatterUtility.string(state.codexQuota.remainingPercent))"
        default:
            return ""
        }
    }
}
```

- [ ] **Step 2: Register Touch Bar in app delegate**

Modify `AppDelegate`:

- Add property:

```swift
private var touchBarController: TouchBarController?
```

- In `applicationDidFinishLaunching`, after `installMenuBarItem()`:

```swift
let touchController = TouchBarController(state: state)
touchBarController = touchController
NSApp.touchBar = touchController.makeTouchBar()
```

- [ ] **Step 3: Add file to project and build**

Run if full Xcode is selected:

```bash
xcodebuild build -project MacStatusCodexMonitor.xcodeproj -scheme MacStatusCodexMonitor -destination 'platform=macOS'
```

Expected: PASS on systems with full Xcode. The app should still run on Macs without Touch Bar.

- [ ] **Step 4: Commit**

```bash
git add MacStatusCodexMonitor/TouchBar/TouchBarController.swift MacStatusCodexMonitor/App/AppDelegate.swift MacStatusCodexMonitor.xcodeproj
git commit -m "feat: add touch bar status indicators"
```

---

### Task 8: Final Verification and Polish

**Files:**
- Modify: `README.md`
- Modify as needed: app files touched by verification fixes.

**Interfaces:**
- Consumes: complete app from Tasks 1-7.
- Produces: user-facing run notes and verified build/test status.

- [ ] **Step 1: Create README**

Create `README.md`:

```markdown
# Mac Status Codex Monitor

Native macOS menu bar app for monitoring Mac status and local Codex quota signals.

## Open in Xcode

Open `MacStatusCodexMonitor.xcodeproj`.

## Notes

- Codex quota comes from local `~/.codex/sessions/**/*.jsonl` `rate_limits` events.
- GPU utilization may show unavailable because macOS does not provide a stable public utilization API for this app.
- Disk growth starts tracking from the first app launch.
- Cache size is an estimate of user-readable cache-like directories. The app does not delete files.

## Verification

With full Xcode selected:

```bash
xcodebuild test -project MacStatusCodexMonitor.xcodeproj -scheme MacStatusCodexMonitor -destination 'platform=macOS'
```
```

- [ ] **Step 2: Run static checks available in this environment**

Run:

```bash
plutil -lint MacStatusCodexMonitor/Info.plist
```

Expected: `MacStatusCodexMonitor/Info.plist: OK`

Run:

```bash
find MacStatusCodexMonitor MacStatusCodexMonitorTests -name '*.swift' -print
```

Expected: prints all Swift files created in Tasks 1-7.

- [ ] **Step 3: Run Xcode verification where available**

Run:

```bash
xcodebuild test -project MacStatusCodexMonitor.xcodeproj -scheme MacStatusCodexMonitor -destination 'platform=macOS'
```

Expected with full Xcode selected: tests pass.

Expected in current Command Line Tools-only environment: `xcode-select: error: tool 'xcodebuild' requires Xcode`.

- [ ] **Step 4: Manual app verification**

Open `MacStatusCodexMonitor.xcodeproj` in Xcode and verify:

- The project opens without missing-file warnings.
- The app target builds.
- The app launches as a menu bar utility.
- Clicking the menu bar item opens the popover.
- The dashboard opens from the popover.
- CPU, memory, disk capacity, battery, cache estimate, and Codex quota fields render.
- Codex quota displays "local Codex log signal".
- Disk 24-hour growth shows "Learning" on a fresh run.
- Touch Bar items do not break launch on a Mac without Touch Bar.

- [ ] **Step 5: Commit**

```bash
git add README.md MacStatusCodexMonitor MacStatusCodexMonitorTests MacStatusCodexMonitor.xcodeproj
git commit -m "docs: add run and verification notes"
```

---

## Self-Review

Spec coverage:

- Menu bar item: Task 6.
- Dashboard window: Task 6.
- Touch Bar indicators: Task 7.
- CPU, memory, battery, disk capacity, GPU availability: Task 5.
- Disk 24-hour growth: Task 4 and Task 5.
- Cache estimate: Task 4 and Task 6.
- Disk I/O degraded state: Task 5 and Task 6.
- Codex quota parsing from local `rate_limits`: Task 3 and Task 6.
- Privacy and local-only behavior: Task 3, Task 8 README.
- Xcode-openable project: Task 1.
- Unit tests: Tasks 2, 3, 4.

Known implementation caveat:

- The current environment has Swift but not full Xcode selected, so `xcodebuild` verification may require the user to switch `xcode-select` to a full Xcode installation.
