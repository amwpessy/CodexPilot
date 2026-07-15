import AppKit
import SwiftUI

struct MenuBarPopoverView: View {
    @ObservedObject var state: AppState
    var openDashboard: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Mac Status & Codex").font(.headline)
            Text("CPU \(PercentFormatterUtility.string(state.system.cpuUsage))")
            Text("Mem \(PercentFormatterUtility.string(state.system.memoryUsedPercent))")
            Text("Disk \(PercentFormatterUtility.string(state.system.diskCapacity.usedPercent))")
            Text("Codex \(PercentFormatterUtility.string(state.codexQuota.remainingPercent)) left")
            Divider()
            Button("Open Dashboard", action: openDashboard)
            Button("Quit") { NSApp.terminate(nil) }
        }
        .padding(14)
        .frame(width: 260)
    }
}
