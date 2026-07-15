# Bilingual Dashboard Redesign

## Goal

Redesign the main macOS dashboard so it feels like a native status center instead of a plain grid of generic cards. The UI must present Chinese and English together throughout the main dashboard.

## Scope

- Dashboard window only.
- Keep the existing data model, monitoring logic, menu bar title, popover, and Touch Bar behavior unchanged unless a label helper can be reused safely.
- Preserve Xcode importability and the current SwiftUI/AppKit structure.

## Layout

The main window becomes a three-column status center:

1. Top summary band
   - App title: `Mac 状态与 Codex / Mac Status & Codex`
   - Last sample/reset context when available.
   - Four compact summary metrics: CPU, Memory, Disk, Codex.

2. Left column: system health
   - CPU, memory, battery, GPU.
   - Use progress bars or status rows where values are percentage-like.

3. Middle column: disk and cache analysis
   - Disk used/available.
   - 24h disk growth.
   - 24h read/write totals and live read/write rates.
   - Cache total and 24h cache growth share.
   - Cache directory list as compact rows.

4. Right column: Codex quota
   - Remaining/used percent.
   - Reset date.
   - Credits/reset-card/secondary information.
   - Limit state.

## Visual Direction

- Use native macOS materials and system colors so light/dark mode both feel natural.
- Avoid the current "plain gray card grid" look.
- Use compact panels, status dots, thin separators, and progress bars.
- Keep cards at 8px radius or less.
- Keep typography restrained: large title only in the top band, compact headings inside panels.
- No marketing hero, no decorative blobs, no one-note color theme.

## Bilingual Text

- Display Chinese first and English second for major labels, separated by ` / `.
- Example labels:
  - `处理器 / CPU`
  - `内存 / Memory`
  - `硬盘 / Disk`
  - `电池 / Battery`
  - `显卡 / GPU`
  - `24小时增长 / 24h Growth`
  - `缓存增长 / Cache Growth`
  - `剩余额度 / Remaining`
  - `重置时间 / Reset`
- Runtime status values from system APIs may remain English if they come from collectors, but dashboard framing labels must be bilingual.

## Error And Learning States

- Keep current `Learning`, `Unavailable`, and `Not reported` semantics, but present them inside bilingual rows where possible.
- Do not hide unavailable GPU or sparse 24h history; make those states look intentional and calm.

## Testing

- Existing model and monitor tests should keep passing/building.
- Add or update view-adjacent tests only if public helper behavior changes.
- Verify with:
  - `git diff --check`
  - `xcodebuild build`
  - `xcodebuild build-for-testing`
  - LaunchServices app open smoke test

## Self Review

- No placeholders remain.
- Scope is limited to the dashboard redesign and bilingual dashboard labels.
- Existing monitor behavior is intentionally unchanged.
- The layout can be implemented in one focused SwiftUI pass without changing data collection.
