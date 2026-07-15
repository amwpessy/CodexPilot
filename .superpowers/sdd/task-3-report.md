# Task 3 Report: Codex Quota Parser

## What I implemented

- Added [`CodexQuotaReader.swift`](/Users/laosuer/Xcode/60714SeeS/MacStatusCodexMonitor/Monitors/CodexQuotaReader.swift) with the exact briefed API:
  - `init(root:fileManager:)`
  - `latestQuotaSnapshot()`
  - `parseLine(_:fileModifiedAt:)`
- Implemented JSONL discovery under `~/.codex/sessions` and selection of the freshest parsed quota snapshot.
- Kept parsing scoped to quota metadata under `payload.rate_limits`; the parser does not surface or index conversation text.
- Preserved the required source label: `local Codex log signal`.
- Added [`CodexQuotaReaderTests.swift`](/Users/laosuer/Xcode/60714SeeS/MacStatusCodexMonitorTests/CodexQuotaReaderTests.swift) with the two tests from the brief.
- Updated [`project.pbxproj`](/Users/laosuer/Xcode/60714SeeS/MacStatusCodexMonitor.xcodeproj/project.pbxproj) so both the new source file and test file are included in Xcode targets.

## What I tested and results

- `xcodebuild test -project MacStatusCodexMonitor.xcodeproj -scheme MacStatusCodexMonitor -destination 'platform=macOS' -only-testing:MacStatusCodexMonitorTests/CodexQuotaReaderTests`
  - Result: failed before compilation because the scheme is not configured for the test action in this project state.
- `xcodebuild build -project MacStatusCodexMonitor.xcodeproj -target MacStatusCodexMonitorTests CODE_SIGNING_ALLOWED=NO OBJROOT=/private/tmp/MacStatusCodexMonitor-Obj SYMROOT=/private/tmp/MacStatusCodexMonitor-Sym`
  - Result: environment-limited failure while Xcode attempted to write module session data / DerivedData outside writable areas.
- Focused fallback verification with Xcode toolchain `swiftc`:
  - RED: compiled a temporary client against a module built from `CodexQuotaSnapshot.swift` only; it failed with `cannot find 'CodexQuotaReader' in scope`.
  - GREEN: compiled a module from `CodexQuotaSnapshot.swift` + `CodexQuotaReader.swift`, then compiled and ran a temporary executable that exercised the same parser expectations as the briefed tests and printed `green-ok`.

## TDD Evidence

### RED

Command:

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer zsh -lc 'tmp=/private/tmp/codexquota-red-check.swift; printf "%s\n" "import Foundation" "import MacStatusCodexMonitor" "let _ = CodexQuotaReader(root: URL(fileURLWithPath: \"/tmp/none\"))" > "$tmp"; SDK=$(xcrun --sdk macosx --show-sdk-path); xcrun swiftc -sdk "$SDK" -target arm64-apple-macos26.0 -module-cache-path /private/tmp/CodexQuotaRed/ModuleCache -I /private/tmp/CodexQuotaRed -L /private/tmp/CodexQuotaRed -lMacStatusCodexMonitor "$tmp" -o /private/tmp/CodexQuotaRed/red-check'
```

Output:

```text
/private/tmp/codexquota-red-check.swift:3:9: error: cannot find 'CodexQuotaReader' in scope
```

### GREEN

Command:

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc -module-cache-path /private/tmp/CodexQuotaGreen/ModuleCache -emit-library -emit-module -module-name MacStatusCodexMonitor /Users/laosuer/Xcode/60714SeeS/MacStatusCodexMonitor/Models/CodexQuotaSnapshot.swift /Users/laosuer/Xcode/60714SeeS/MacStatusCodexMonitor/Monitors/CodexQuotaReader.swift -enable-testing -o /private/tmp/CodexQuotaGreen/libMacStatusCodexMonitor.dylib -emit-module-path /private/tmp/CodexQuotaGreen/MacStatusCodexMonitor.swiftmodule
```

Result:

```text
exit 0
```

Command:

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer zsh -lc 'tmp=/private/tmp/codexquota-green-check.swift; printf "%s\n" "import Foundation" "@testable import MacStatusCodexMonitor" "let reader = CodexQuotaReader(root: URL(fileURLWithPath: \"/tmp/none\"))" "let rateLine = \"{\\\"timestamp\\\":\\\"2026-07-15T07:55:30.701Z\\\",\\\"type\\\":\\\"event_msg\\\",\\\"payload\\\":{\\\"type\\\":\\\"token_count\\\",\\\"rate_limits\\\":{\\\"limit_id\\\":\\\"codex\\\",\\\"primary\\\":{\\\"used_percent\\\":2.0,\\\"window_minutes\\\":10080,\\\"resets_at\\\":1784704630},\\\"secondary\\\":null,\\\"credits\\\":{\\\"has_credits\\\":false,\\\"unlimited\\\":false,\\\"balance\\\":null},\\\"individual_limit\\\":null,\\\"plan_type\\\":\\\"team\\\",\\\"rate_limit_reached_type\\\":null}}}\"" "guard let snapshot = reader.parseLine(rateLine, fileModifiedAt: nil) else { fatalError(\"expected snapshot\") }" "precondition(snapshot.limitID == \"codex\")" "precondition(snapshot.usedPercent == 2.0)" "precondition(snapshot.remainingPercent == 98.0)" "precondition(snapshot.windowMinutes == 10080)" "precondition(snapshot.planType == \"team\")" "precondition(snapshot.creditsDescription == \"No credits\")" "precondition(snapshot.sourceDescription == \"local Codex log signal\")" "let conversationLine = \"{\\\"timestamp\\\":\\\"2026-07-15T07:55:30.701Z\\\",\\\"type\\\":\\\"event_msg\\\",\\\"payload\\\":{\\\"type\\\":\\\"agent_message\\\",\\\"text\\\":\\\"hello\\\"}}\"" "precondition(reader.parseLine(conversationLine, fileModifiedAt: nil) == nil)" "print(\"green-ok\")" > "$tmp"; SDK=$(xcrun --sdk macosx --show-sdk-path); xcrun swiftc -sdk "$SDK" -target arm64-apple-macos26.0 -module-cache-path /private/tmp/CodexQuotaGreen/ModuleCache -I /private/tmp/CodexQuotaGreen -L /private/tmp/CodexQuotaGreen -lMacStatusCodexMonitor "$tmp" -o /private/tmp/CodexQuotaGreen/green-check && /private/tmp/CodexQuotaGreen/green-check'
```

Output:

```text
green-ok
```

## Files changed

- [`MacStatusCodexMonitor/Monitors/CodexQuotaReader.swift`](/Users/laosuer/Xcode/60714SeeS/MacStatusCodexMonitor/Monitors/CodexQuotaReader.swift)
- [`MacStatusCodexMonitorTests/CodexQuotaReaderTests.swift`](/Users/laosuer/Xcode/60714SeeS/MacStatusCodexMonitorTests/CodexQuotaReaderTests.swift)
- [`MacStatusCodexMonitor.xcodeproj/project.pbxproj`](/Users/laosuer/Xcode/60714SeeS/MacStatusCodexMonitor.xcodeproj/project.pbxproj)

## Self-review findings

- No functional issues found in the final diff.
- The parser intentionally ignores any JSONL line without `payload.rate_limits`, which keeps it aligned with the privacy constraint and the task scope.

## Issues or concerns

- The requested `xcodebuild test` path is still blocked here by project/environment issues outside the parser itself:
  - the scheme is not configured for the test action, and
  - sandboxed Xcode writes to user DerivedData/module cache locations that are not writable in this session.
- The project file was still updated so the new source and test files are present for normal Xcode use.

---

## Task 3 review fix

### What I fixed

- Added a shared scheme at [`MacStatusCodexMonitor.xcodeproj/xcshareddata/xcschemes/MacStatusCodexMonitor.xcscheme`](/Users/laosuer/Xcode/60714SeeS/MacStatusCodexMonitor.xcodeproj/xcshareddata/xcschemes/MacStatusCodexMonitor.xcscheme) so the checked-in app scheme has a real `TestAction` for `MacStatusCodexMonitorTests`.
- Updated [`MacStatusCodexMonitor.xcodeproj/project.pbxproj`](/Users/laosuer/Xcode/60714SeeS/MacStatusCodexMonitor.xcodeproj/project.pbxproj) so the app target builds with Debug testability enabled and the test target is hosted by the app executable via `TEST_HOST` / `BUNDLE_LOADER`.
- Added a focused regression test in [`MacStatusCodexMonitorTests/CodexQuotaReaderTests.swift`](/Users/laosuer/Xcode/60714SeeS/MacStatusCodexMonitorTests/CodexQuotaReaderTests.swift) covering `latestQuotaSnapshot()` choosing the freshest quota event across multiple files and lines.

### Tests run and results

- RED:

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project MacStatusCodexMonitor.xcodeproj -scheme MacStatusCodexMonitor -destination 'platform=macOS' -only-testing:MacStatusCodexMonitorTests/CodexQuotaReaderTests -derivedDataPath /private/tmp/MacStatusCodexMonitorDerived -clonedSourcePackagesDirPath /private/tmp/MacStatusCodexMonitorSPM
```

Output:

```text
xcodebuild: error: Scheme MacStatusCodexMonitor is not currently configured for the test action.
```

- After adding the shared scheme, Debug testability, and test host wiring:

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project MacStatusCodexMonitor.xcodeproj -scheme MacStatusCodexMonitor -destination 'platform=macOS' -only-testing:MacStatusCodexMonitorTests/CodexQuotaReaderTests -derivedDataPath /private/tmp/MacStatusCodexMonitorDerived -clonedSourcePackagesDirPath /private/tmp/MacStatusCodexMonitorSPM
```

Output tail:

```text
Testing failed:
	MacStatusCodexMonitor encountered an error (Failed to establish communication with the test runner. (Underlying Error: Couldn’t communicate with a helper application. Try your operation again. If that fails, quit and relaunch the application and try again. The connection to service named com.apple.testmanagerd.control was invalidated: Connection init failed at lookup with error 159 - Sandbox restriction.))
```

- Focused fallback harness for the new behavior:

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer zsh -lc 'tmp=/private/tmp/codexquota-latest-harness.swift; printf "%s\n" "import Foundation" "@main" "struct Harness {" "    static func main() throws {" "        let fileManager = FileManager.default" "        let root = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)" "        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)" "        defer { try? fileManager.removeItem(at: root) }" "        let olderFile = root.appendingPathComponent(\"older.jsonl\")" "        let newerFile = root.appendingPathComponent(\"newer.jsonl\")" "        try \"{\\\"timestamp\\\":\\\"2026-07-15T07:45:30.000Z\\\",\\\"payload\\\":{\\\"rate_limits\\\":{\\\"limit_id\\\":\\\"codex\\\",\\\"primary\\\":{\\\"used_percent\\\":12.0,\\\"window_minutes\\\":60,\\\"resets_at\\\":1784700000},\\\"credits\\\":{\\\"has_credits\\\":false,\\\"unlimited\\\":false,\\\"balance\\\":null},\\\"individual_limit\\\":null,\\\"plan_type\\\":\\\"team\\\",\\\"rate_limit_reached_type\\\":null}}}\\n{\\\"timestamp\\\":\\\"2026-07-15T07:55:30.000Z\\\",\\\"payload\\\":{\\\"rate_limits\\\":{\\\"limit_id\\\":\\\"codex\\\",\\\"primary\\\":{\\\"used_percent\\\":44.0,\\\"window_minutes\\\":60,\\\"resets_at\\\":1784700600},\\\"credits\\\":{\\\"has_credits\\\":true,\\\"unlimited\\\":false,\\\"balance\\\":3},\\\"individual_limit\\\":null,\\\"plan_type\\\":\\\"team\\\",\\\"rate_limit_reached_type\\\":null}}}\".write(to: olderFile, atomically: true, encoding: .utf8)" "        try \"{\\\"timestamp\\\":\\\"2026-07-15T07:50:30.000Z\\\",\\\"payload\\\":{\\\"rate_limits\\\":{\\\"limit_id\\\":\\\"codex\\\",\\\"primary\\\":{\\\"used_percent\\\":23.0,\\\"window_minutes\\\":60,\\\"resets_at\\\":1784700300},\\\"credits\\\":{\\\"has_credits\\\":false,\\\"unlimited\\\":false,\\\"balance\\\":null},\\\"individual_limit\\\":null,\\\"plan_type\\\":\\\"team\\\",\\\"rate_limit_reached_type\\\":null}}}\".write(to: newerFile, atomically: true, encoding: .utf8)" "        let snapshot = CodexQuotaReader(root: root).latestQuotaSnapshot()" "        let formatter = ISO8601DateFormatter()" "        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]" "        precondition(snapshot.limitID == \"codex\")" "        precondition(snapshot.usedPercent == 44.0)" "        precondition(snapshot.remainingPercent == 56.0)" "        precondition(snapshot.creditsDescription == \"Balance: 3\")" "        precondition(snapshot.planType == \"team\")" "        precondition(snapshot.freshness == formatter.date(from: \"2026-07-15T07:55:30.000Z\"))" "        print(\"freshest-ok\")" "    }" "}" > "$tmp"; SDK=$(xcrun --sdk macosx --show-sdk-path); xcrun swiftc -sdk "$SDK" -target arm64-apple-macos13.0 -module-cache-path /private/tmp/CodexQuotaHarness/ModuleCache /Users/laosuer/Xcode/60714SeeS/MacStatusCodexMonitor/Models/CodexQuotaSnapshot.swift /Users/laosuer/Xcode/60714SeeS/MacStatusCodexMonitor/Monitors/CodexQuotaReader.swift "$tmp" -o /private/tmp/CodexQuotaHarness/latest-harness && /private/tmp/CodexQuotaHarness/latest-harness'
```

Output:

```text
freshest-ok
```

### Files changed

- [`MacStatusCodexMonitor.xcodeproj/project.pbxproj`](/Users/laosuer/Xcode/60714SeeS/MacStatusCodexMonitor.xcodeproj/project.pbxproj)
- [`MacStatusCodexMonitor.xcodeproj/xcshareddata/xcschemes/MacStatusCodexMonitor.xcscheme`](/Users/laosuer/Xcode/60714SeeS/MacStatusCodexMonitor.xcodeproj/xcshareddata/xcschemes/MacStatusCodexMonitor.xcscheme)
- [`MacStatusCodexMonitorTests/CodexQuotaReaderTests.swift`](/Users/laosuer/Xcode/60714SeeS/MacStatusCodexMonitorTests/CodexQuotaReaderTests.swift)
