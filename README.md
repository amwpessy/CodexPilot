# Mac Status Codex Monitor

Native macOS menu bar app for monitoring Mac status and local Codex quota signals.

## Open in Xcode

Open `MacStatusCodexMonitor.xcodeproj`.

## Notes

- Codex quota comes from local `~/.codex/sessions/**/*.jsonl` `rate_limits` events.
- Reset-card and secondary quota details are shown when those fields are present in local Codex events; otherwise they are labeled as not reported.
- GPU utilization may show unavailable because macOS does not provide a stable public utilization API for this app.
- The app refreshes periodically while running in the menu bar; the default cadence is two minutes to avoid excessive cache-directory scanning.
- Disk growth, disk I/O, and cache-growth attribution start tracking from the first app launch and need about 24 hours of local history before the 24h fields become ready.
- Cache size is an estimate of user-readable cache-like directories. The app estimates 24h cache-like growth but does not delete files.
- In this Codex sandbox, `xcodebuild test` may be blocked by `com.apple.testmanagerd.control`; `build` and `build-for-testing` still verify project wiring.

## Verification

With full Xcode selected:

```bash
xcodebuild test -project MacStatusCodexMonitor.xcodeproj -scheme MacStatusCodexMonitor -destination 'platform=macOS'
```
