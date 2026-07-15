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
