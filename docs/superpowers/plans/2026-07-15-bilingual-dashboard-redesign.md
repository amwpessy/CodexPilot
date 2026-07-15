# Bilingual Dashboard Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the plain dashboard card grid with a bilingual native macOS status center.

**Architecture:** Keep monitoring and app state unchanged. Rebuild `DashboardView` as a top summary band plus three focused columns backed by small private SwiftUI subviews in the same file. Preserve current formatter utilities and state-derived computed values.

**Tech Stack:** Swift 5, SwiftUI, AppKit colors/materials, existing Xcode macOS app target.

## Global Constraints

- Dashboard window only.
- Chinese appears first and English second for dashboard framing labels, separated by ` / `.
- Existing data collection, menu bar title, popover, and Touch Bar behavior remain unchanged.
- Use native macOS materials and system colors.
- Keep cards/panels at 8px radius or less.
- Verify with `git diff --check`, `xcodebuild build`, `xcodebuild build-for-testing`, and LaunchServices app open smoke test.

---

### Task 1: Rebuild Dashboard Layout

**Files:**
- Modify: `MacStatusCodexMonitor/Views/DashboardView.swift`

**Interfaces:**
- Consumes: `AppState`, `SystemSnapshot`, `DiskGrowthSummary`, `CacheEstimate`, `CodexQuotaSnapshot`, `ByteFormatterUtility`, `PercentFormatterUtility`.
- Produces: a redesigned `DashboardView` with private helper views `StatusCenterPanel`, `SummaryPill`, `MetricGauge`, `StatusRow`, and `CacheDirectoryRow`.

- [ ] **Step 1: Replace the old grid with the new status-center structure**

Implement `DashboardView.body` with:

```swift
ScrollView {
    VStack(alignment: .leading, spacing: 16) {
        headerBand
        HStack(alignment: .top, spacing: 14) {
            systemHealthColumn
                .frame(minWidth: 220, maxWidth: 260)
            diskAnalysisColumn
                .frame(minWidth: 300, maxWidth: .infinity)
            codexColumn
                .frame(minWidth: 240, maxWidth: 300)
        }
    }
    .padding(18)
}
.background(Color(nsColor: .windowBackgroundColor))
.frame(minWidth: 920, minHeight: 620)
```

- [ ] **Step 2: Add bilingual top summary band**

Create `headerBand` with title `Mac 状态与 Codex / Mac Status & Codex`, a subtitle showing sample time and reset context, and four `SummaryPill` views for CPU, memory, disk, and Codex.

- [ ] **Step 3: Add three dashboard columns**

Create:

```swift
private var systemHealthColumn: some View
private var diskAnalysisColumn: some View
private var codexColumn: some View
```

Use bilingual labels for every panel title and row title.

- [ ] **Step 4: Add native panel and metric subviews**

Add private SwiftUI views:

```swift
private struct StatusCenterPanel<Content: View>: View
private struct SummaryPill: View
private struct MetricGauge: View
private struct StatusRow: View
private struct CacheDirectoryRow: View
```

Use `.background(.regularMaterial)`, system separators, progress bars, status dots, and 8px rounded rectangles.

- [ ] **Step 5: Preserve and extend computed values**

Keep existing computed values for memory, disk, battery, GPU, disk growth, disk I/O, cache growth, and reset time. Add:

```swift
private var sampleTimeValue: String
private var resetContext: String
private var diskUsedDetail: String
private var codexRemainingValue: String
```

- [ ] **Step 6: Build**

Run:

```bash
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild build -project MacStatusCodexMonitor.xcodeproj -scheme MacStatusCodexMonitor -destination 'platform=macOS' -derivedDataPath /private/tmp/MacStatusCodexMonitor-dashboard-build
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 7: Commit**

```bash
git add MacStatusCodexMonitor/Views/DashboardView.swift
git commit -m "style: redesign bilingual dashboard"
```

### Task 2: Verify Integration

**Files:**
- Read: `README.md`
- Read: `MacStatusCodexMonitor/Views/DashboardView.swift`

**Interfaces:**
- Consumes: the redesigned Dashboard from Task 1.
- Produces: verified project state with no additional source changes unless a build issue is found.

- [ ] **Step 1: Run whitespace check**

Run:

```bash
git diff --check
```

Expected: no output and exit code 0.

- [ ] **Step 2: Build test bundle**

Run:

```bash
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild build-for-testing -project MacStatusCodexMonitor.xcodeproj -scheme MacStatusCodexMonitor -destination 'platform=macOS' -derivedDataPath /private/tmp/MacStatusCodexMonitor-dashboard-bft
```

Expected: `** TEST BUILD SUCCEEDED **`.

- [ ] **Step 3: Try full test run**

Run:

```bash
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild test -project MacStatusCodexMonitor.xcodeproj -scheme MacStatusCodexMonitor -destination 'platform=macOS' -derivedDataPath /private/tmp/MacStatusCodexMonitor-dashboard-test
```

Expected in this sandbox: may fail with `com.apple.testmanagerd.control` sandbox restriction. Any Swift compile or assertion failure must be fixed.

- [ ] **Step 4: Launch smoke test**

Run:

```bash
open /private/tmp/MacStatusCodexMonitor-dashboard-build/Build/Products/Debug/MacStatusCodexMonitor.app
```

Expected: app launches without a new `MacStatusCodexMonitor-*.ips` crash report.

- [ ] **Step 5: Final status**

Run:

```bash
git status --short
git log --oneline -3
```

Expected: no source changes beyond the known untracked Xcode workspace directory, and recent commits include the dashboard redesign.

## Self Review

- Spec coverage: bilingual labels, native status center, top summary, three columns, calm unavailable states, and verification are covered.
- Placeholder scan: no TBD/TODO/fill-in placeholders remain.
- Type consistency: helper view names and computed properties are local to `DashboardView.swift`; existing app-state types are unchanged.
