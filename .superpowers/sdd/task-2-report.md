# Task 2 Report: Models and Formatting

## What I implemented

- Added model files:
  - `MacStatusCodexMonitor/Models/SystemSnapshot.swift`
  - `MacStatusCodexMonitor/Models/DiskSnapshot.swift`
  - `MacStatusCodexMonitor/Models/CodexQuotaSnapshot.swift`
- Added formatter utilities:
  - `MacStatusCodexMonitor/Utilities/ByteFormatter.swift`
  - `MacStatusCodexMonitor/Utilities/PercentFormatter.swift`
- Added behavior-checking tests:
  - `MacStatusCodexMonitorTests/FormattingTests.swift`
- Updated `MacStatusCodexMonitor.xcodeproj/project.pbxproj` to include the new app-target and test-target files.

Implementation details:
- Added `Availability<Value>`, `SystemSnapshot`, `BatterySnapshot`, `DiskCapacity`, `DiskIOSnapshot`, and `GPUSnapshot`.
- Added `DiskSnapshot`, `DiskGrowthSummary`, and `CacheEstimate`.
- Added `CodexQuotaSnapshot` plus the specified `unavailable` static value.
- Implemented byte/rate/percent formatting.

Note:
- I started with the formatter implementation exactly as written in the brief, then verified that Foundation's `ByteCountFormatter` output on this toolchain would not satisfy the required test strings (`Zero bytes`, `2 KB`, `1.07 GB` rather than `0 B`, `1.5 KB`, `1 GB`). I therefore adjusted `ByteFormatterUtility` to deterministic unit formatting that matches the test contract.

## What I tested and test results

### Attempted canonical XCTest command

Command:

```bash
xcodebuild test -project MacStatusCodexMonitor.xcodeproj -scheme MacStatusCodexMonitor -destination 'platform=macOS'
```

Result:

```text
xcode-select: error: tool 'xcodebuild' requires Xcode, but active developer directory '/Library/Developer/CommandLineTools' is a command line tools instance
```

This matches the environment note in the brief, so full XCTest execution was not available here.

### Environment-limited verification performed

Typechecked the new model and utility files:

```bash
env HOME=/Users/laosuer/Xcode/60714SeeS CLANG_MODULE_CACHE_PATH=/private/tmp/codex-clang-cache SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/codex-swiftpm-cache swiftc -module-cache-path /private/tmp/codex-clang-cache -typecheck MacStatusCodexMonitor/Models/SystemSnapshot.swift MacStatusCodexMonitor/Models/DiskSnapshot.swift MacStatusCodexMonitor/Models/CodexQuotaSnapshot.swift MacStatusCodexMonitor/Utilities/ByteFormatter.swift MacStatusCodexMonitor/Utilities/PercentFormatter.swift
```

Result:
- Exit code `0`
- No diagnostics

Compiled and ran a small verification harness against the actual formatter source files:

```bash
env HOME=/Users/laosuer/Xcode/60714SeeS CLANG_MODULE_CACHE_PATH=/private/tmp/codex-clang-cache SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/codex-swiftpm-cache swiftc -module-cache-path /private/tmp/codex-clang-cache MacStatusCodexMonitor/Utilities/ByteFormatter.swift MacStatusCodexMonitor/Utilities/PercentFormatter.swift .superpowers/sdd/task-2-verification.swift -o /private/tmp/task-2-verification && /private/tmp/task-2-verification
```

Result:

```text
Task 2 verification passed
```

Also ran:

```bash
git diff --check
```

Result:
- Exit code `0`
- No whitespace or patch-format issues

## TDD Evidence

### RED

I created `MacStatusCodexMonitorTests/FormattingTests.swift` first and wired it into the Xcode test target before implementation.

Attempted RED command:

```bash
xcodebuild test -project MacStatusCodexMonitor.xcodeproj -scheme MacStatusCodexMonitor -destination 'platform=macOS'
```

Observed result:

```text
xcode-select: error: tool 'xcodebuild' requires Xcode, but active developer directory '/Library/Developer/CommandLineTools' is a command line tools instance
```

Because the environment cannot invoke `xcodebuild`, I could not capture the expected symbol-missing XCTest failure in this shell. This is the environment-limited equivalent described by the brief.

### GREEN

After implementing the files, I verified:
- `swiftc -typecheck` succeeded for all new model and utility files
- A compiled harness asserted the exact formatter outputs from the brief and passed

## Files changed

- `MacStatusCodexMonitor.xcodeproj/project.pbxproj`
- `MacStatusCodexMonitor/Models/SystemSnapshot.swift`
- `MacStatusCodexMonitor/Models/DiskSnapshot.swift`
- `MacStatusCodexMonitor/Models/CodexQuotaSnapshot.swift`
- `MacStatusCodexMonitor/Utilities/ByteFormatter.swift`
- `MacStatusCodexMonitor/Utilities/PercentFormatter.swift`
- `MacStatusCodexMonitorTests/FormattingTests.swift`

## Self-review findings

- No structural issues found in the added model files.
- The only notable adjustment was replacing direct `ByteCountFormatter` output with deterministic custom formatting so the required XCTest expectations are satisfied consistently.

## Any issues or concerns

- `xcodebuild` could not run in this environment because the active developer directory points to Command Line Tools instead of a full Xcode installation.
- XCTest execution therefore remains to be confirmed in a full Xcode-selected environment, but the project file has been updated so Xcode can build the new files and test file.

---

## Follow-up fix after review

### What I fixed

- Updated `ByteFormatterUtility.signedString(bytes:)` in `MacStatusCodexMonitor/Utilities/ByteFormatter.swift` to use `bytes.magnitude` instead of `abs(bytes)`, which avoids overflow for `Int64.min`.
- Preserved signed output behavior explicitly for positive, zero, and negative values.
- Extended `MacStatusCodexMonitorTests/FormattingTests.swift` with signed-format coverage for a normal negative value and the `Int64.min` edge case.

### Tests run and results

Confirmed the pre-fix failure mode with the old `abs(bytes)` logic:

```bash
env HOME=/Users/laosuer/Xcode/60714SeeS CLANG_MODULE_CACHE_PATH=/private/tmp/codex-clang-cache SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/codex-swiftpm-cache swift -module-cache-path /private/tmp/codex-clang-cache -e "import Foundation; func string(bytes: UInt64) -> String { return String(bytes) }; func signedString(bytes: Int64) -> String { let sign = bytes > 0 ? \"+\" : \"\"; return \"\\(sign)\\(string(bytes: UInt64(abs(bytes))))\" }; print(signedString(bytes: Int64.min))"
```

Result:

```text
Exit code 133
Stack dump includes: libswiftCore.dylib ... $ss3absyxxSLRzs13SignedNumericRzlF
```

Typechecked the touched production file:

```bash
env HOME=/Users/laosuer/Xcode/60714SeeS CLANG_MODULE_CACHE_PATH=/private/tmp/codex-clang-cache SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/codex-swiftpm-cache swiftc -module-cache-path /private/tmp/codex-clang-cache -typecheck /Users/laosuer/Xcode/60714SeeS/MacStatusCodexMonitor/Utilities/ByteFormatter.swift
```

Result:

```text
Exit code 0
No diagnostics
```

Compiled and ran a formatter verification harness against the actual source file:

```bash
printf '%s\n' 'import Foundation' '@main' 'struct Runner {' '    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {' '        if !condition() {' '            fputs("Assertion failed: \(message)\n", stderr)' '            exit(1)' '        }' '    }' '' '    static func main() {' '        expect(ByteFormatterUtility.string(bytes: 0) == "0 B", "0 bytes formats as 0 B")' '        expect(ByteFormatterUtility.string(bytes: 1_536) == "1.5 KB", "1536 bytes formats as 1.5 KB")' '        expect(ByteFormatterUtility.string(bytes: 1_073_741_824) == "1 GB", "1 GiB formats as 1 GB")' '        expect(ByteFormatterUtility.rate(bytesPerSecond: 1_048_576) == "1 MB/s", "rate appends /s")' '        expect(ByteFormatterUtility.signedString(bytes: -1_536) == "-1.5 KB", "negative signed string keeps minus sign")' '        expect(ByteFormatterUtility.signedString(bytes: Int64.min) == "-\(ByteFormatterUtility.string(bytes: Int64.min.magnitude))", "Int64.min formats without overflow")' '        print("Task 2 formatter verification passed")' '    }' '}' > /private/tmp/task-2-byteformatter-verification.swift && env HOME=/Users/laosuer/Xcode/60714SeeS CLANG_MODULE_CACHE_PATH=/private/tmp/codex-clang-cache SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/codex-swiftpm-cache swiftc -module-cache-path /private/tmp/codex-clang-cache /Users/laosuer/Xcode/60714SeeS/MacStatusCodexMonitor/Utilities/ByteFormatter.swift /private/tmp/task-2-byteformatter-verification.swift -o /private/tmp/task-2-byteformatter-verification && /private/tmp/task-2-byteformatter-verification
```

Result:

```text
Task 2 formatter verification passed
```

Patch hygiene check:

```bash
git diff --check
```

Result:

```text
Exit code 0
No output
```

### Files changed

- `MacStatusCodexMonitor/Utilities/ByteFormatter.swift`
- `MacStatusCodexMonitorTests/FormattingTests.swift`
- `.superpowers/sdd/task-2-report.md`
