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
