import Foundation

final class MonitoringScheduler {
    private var timer: Timer?
    private(set) var currentInterval: TimeInterval?

    func start(interval: TimeInterval, refresh: @escaping () -> Void) {
        stop()
        currentInterval = interval
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            refresh()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        currentInterval = nil
    }
}
