# Mac Status and Codex Quota Monitor Design

Date: 2026-07-15

## Goal

Build a native macOS app that can be opened directly in Xcode and monitors local Mac health plus local Codex quota signals. The app runs as a menu bar utility, provides a full SwiftUI dashboard window, and exposes compact status items through the Touch Bar when available.

## Product Shape

The app has three surfaces:

1. Menu bar item: always-on compact summary for CPU, memory, disk growth, and Codex quota.
2. Dashboard window: detailed panels for Mac status, disk history, cache analysis, disk I/O, and Codex quota.
3. Touch Bar: compact live indicators for CPU, memory, disk delta, battery, and Codex quota.

The first version prioritizes reliable local monitoring and clear degraded states over aggressive privileged collection.

## Architecture

The app will be a pure Swift/SwiftUI macOS project.

Core layers:

- `AppState`: shared observable model for the latest machine and Codex snapshots.
- `MonitoringScheduler`: timer-driven sampler that refreshes metrics at fixed intervals.
- `SystemMonitor`: collects CPU, memory, battery, disk capacity, disk I/O, and GPU availability.
- `DiskGrowthStore`: persists timestamped disk snapshots locally and computes 24-hour growth.
- `CacheAnalyzer`: scans known user-cache locations and estimates cache-like growth.
- `CodexQuotaReader`: parses local Codex JSONL session files for latest `rate_limits` events.
- `MenuBarController`: owns the `NSStatusItem` and menu popover/window actions.
- `TouchBarController`: bridges AppKit `NSTouchBar` into the app lifecycle.
- `DashboardView`: SwiftUI dashboard for all sections.

This keeps collection, storage, parsing, and UI separated so individual collectors can be replaced later.

## System Monitoring

CPU:

- Use Mach host processor APIs to sample per-core ticks.
- Compute usage from deltas between samples.
- Show total usage and optionally core count/model metadata.

Memory:

- Use `host_statistics64`.
- Show used, free, wired/compressed, and pressure-like percentage where possible.

Battery:

- Use IOKit power source APIs.
- Show battery percentage, charging state, time remaining when available.
- On desktops or unavailable devices, show a stable "No battery" state.

Disk capacity:

- Use `FileManager` volume resource values for total and available bytes.
- Track the primary user volume in version 1.

Disk growth over the last 24 hours:

- Store periodic snapshots of available bytes.
- Compute growth as the decrease in available space between the nearest snapshot before 24 hours ago and the latest snapshot.
- If less than 24 hours of history exists, show "learning" with the available window length.

Cache garbage estimate:

- Scan user-level directories only in version 1:
  - `~/Library/Caches`
  - `~/Library/Logs`
  - `~/Library/Developer/Xcode/DerivedData`
  - `~/Library/Developer/Xcode/Archives`
  - `~/Library/Developer/CoreSimulator/Caches`
- Report total cache-like size and top directories.
- Do not delete files automatically.
- Clearly label this as an estimate, not a guaranteed safe-clean amount.

Disk read/write:

- Prefer system I/O counters sampled over time.
- Show read/write rate and 24-hour accumulated estimates when available.
- If the OS does not expose stable per-disk counters without elevated permissions, show a system-level I/O estimate and mark it as such.

GPU:

- Use public system information to show GPU device name and availability.
- GPU utilization is not guaranteed through stable public macOS APIs, so version 1 shows "utilization unavailable" unless a reliable public collector is found during implementation.

## Codex Quota Monitoring

The app reads local Codex state only.

Primary source:

- `~/.codex/sessions/**/*.jsonl`
- Latest event whose payload contains `rate_limits`

Observed fields to support:

- `limit_id`
- `primary.used_percent`
- `primary.resets_at`
- `primary.window_minutes`
- `secondary`
- `credits.has_credits`
- `credits.unlimited`
- `credits.balance`
- `individual_limit`
- `plan_type`
- `rate_limit_reached_type`

Displayed values:

- Remaining quota percent as `100 - used_percent`
- Used percent
- Reset date/time from `resets_at`
- Plan type
- Window length
- Extra credits/reset-card-like information when present
- Data freshness timestamp

Fallback behavior:

- If no local `rate_limits` event exists, show "No local quota event found".
- If specific fields are null, show "Not reported".
- Since this is parsed from local Codex logs rather than a documented public quota API, label the source as "local Codex log signal".

Privacy:

- The parser should only decode event metadata needed for quota.
- It must not display or index user conversation text.

## UI Design

Menu bar:

- Text/icon summary: CPU, memory, disk, Codex.
- Click opens a compact popover.
- Popover has a button to open the dashboard window.

Dashboard:

- Dense utility layout, not a landing page.
- Top row: overall machine status and Codex quota.
- System section: CPU, memory, battery, GPU.
- Disk section: capacity, 24-hour growth, cache estimate, read/write history.
- Codex section: quota percent, reset time, plan type, credits/reset-card fields, freshness.
- Use restrained colors with status accents for warning/critical states.

Touch Bar:

- Compact buttons/items:
  - CPU percentage
  - Memory percentage
  - Disk 24-hour delta
  - Battery percentage or no battery
  - Codex remaining quota percentage
- Items update from `AppState`.
- On Macs without Touch Bar, the app works normally.

## Permissions and Limits

Version 1 should avoid privileged helpers and full-disk access requirements.

Expected limits:

- Cache scanning is limited to user-readable folders.
- Disk history starts when the app first runs.
- GPU utilization may be unavailable.
- Codex quota depends on local Codex session logs and may change if Codex changes its log format.

The UI must show these limits clearly without blocking normal use.

## Persistence

Use local app support storage:

- Disk snapshots: JSON or SQLite.
- User settings: `UserDefaults`.
- No cloud sync.
- No network calls in version 1.

Snapshots should be pruned to a practical retention window, such as 7 to 30 days.

## Xcode Project

Generate a standard macOS app project that Xcode can open directly:

- SwiftUI lifecycle app.
- AppKit bridge for menu bar and Touch Bar.
- macOS deployment target: macOS 13 or later unless implementation requires newer APIs.
- No third-party dependency in version 1 unless strongly justified.

## Testing and Verification

Manual verification:

- Project opens in Xcode.
- App builds with `xcodebuild`.
- Menu bar item appears.
- Dashboard opens and renders without overlap.
- Metrics refresh over time.
- Disk snapshots are persisted and loaded.
- Codex quota parser extracts the latest local `rate_limits` event.
- App behaves on systems with no battery and no Touch Bar.

Focused unit tests:

- Codex JSONL quota parsing.
- Disk snapshot 24-hour delta calculation.
- Cache directory size aggregation with temporary fixtures.
- Formatting for unavailable/null states.

## Out of Scope for Version 1

- Automatic cache deletion.
- Privileged helper installation.
- Full-disk scan.
- Network-based Codex quota API.
- Guaranteed GPU utilization percentage.
- Multi-machine monitoring.

## Open Implementation Notes

- During implementation, inspect available Xcode tooling in the environment before generating the project.
- Prefer native Swift APIs and small AppKit bridges.
- Keep collectors independently testable.
- Treat Codex quota fields as schema-flexible because they are inferred from local logs.
