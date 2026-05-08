import Foundation
import PortScanCore

@MainActor
final class ScanRunner: ObservableObject {
    @Published private(set) var snapshot: Snapshot = Snapshot(scannedAt: .distantPast, entries: [])

    private let scanner = PortScanner()
    private var timer: Timer?
    private var fastMode = false

    func start() {
        Task { await rescan() }
        scheduleTimer()
    }

    func setFastMode(_ on: Bool) {
        fastMode = on
        scheduleTimer()
        if on { Task { await rescan() } }
    }

    func forceRefresh() {
        Task { await rescan() }
    }

    private func scheduleTimer() {
        timer?.invalidate()
        let interval: TimeInterval = fastMode ? 3 : 15
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { await self?.rescan() }
        }
    }

    private func rescan() async {
        let entries = await scanner.scan()
        let snap = Snapshot(scannedAt: Date(), entries: entries)
        self.snapshot = snap
        try? AppGroupStore.write(snap)
    }
}
