# Lynncat Pilot / 林猫驾驶舱

Lynncat Pilot is a native macOS status cockpit for developers using Codex on Mac. It combines local quota signals, system health, disk activity, a menu bar display, and Touch Bar status in one bilingual app.

## Version 1.4

- Monitor CPU, memory, battery, disk usage, disk growth, and live disk I/O.
- Show supported Codex quota signals in the dashboard, menu bar, and Touch Bar.
- Switch between a light Normal mode and a one-second Sport mode.
- Join the optional Lynncat community with Apple or Lynncat account login.
- Earn participation points and collect all 108 Water Margin hero cards.
- Use the entertainment-only points Poker table in the Direct edition.
- Build separate App Store and notarized Direct editions from the same Xcode project.

Quota data depends on compatible events being readable from local Codex session logs. When no compatible event is available, the app reports that the quota is not available.

## Open In Xcode

Open `MacStatusCodexMonitor.xcodeproj`, then choose one of the shared schemes:

- `MacStatusCodexMonitor`: App Store edition.
- `Lynncat Pilot Direct`: direct-download edition with the points Poker table.

## Verification

```bash
xcodebuild test \
  -project MacStatusCodexMonitor.xcodeproj \
  -scheme MacStatusCodexMonitor \
  -destination 'platform=macOS,arch=arm64'
```

The project requires Xcode 26 or later and targets macOS 13 or later.
