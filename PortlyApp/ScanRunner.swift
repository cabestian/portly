import AppKit
import Foundation
import PortScanCore

@MainActor
final class ScanRunner: ObservableObject {
    @Published private(set) var snapshot: Snapshot = Snapshot(scannedAt: .distantPast, entries: [])

    private let scanner = PortScanner()
    private var timer: Timer?
    private var fastMode = false
    private var wakeObserver: NSObjectProtocol?

    func start() {
        Task { await rescan() }
        scheduleTimer()
        observeWake()
    }

    func setFastMode(_ on: Bool) {
        fastMode = on
        scheduleTimer()
        if on { Task { await rescan() } }
    }

    func forceRefresh() {
        Task { await rescan() }
    }

    private func observeWake() {
        guard wakeObserver == nil else { return }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.scheduleTimer()
                await self.rescan()
            }
        }
    }

    private func scheduleTimer() {
        timer?.invalidate()
        let interval: TimeInterval = fastMode ? 3 : 15
        // Timer ajouté en mode .common pour qu'il continue à fire pendant
        // le tracking du popover. Sans ça, ouvrir le volet gèle les scans
        // jusqu'à la fermeture (RunLoop passe en mode eventTracking).
        let newTimer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { await self?.rescan() }
        }
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }

    private func rescan() async {
        let entries = await scanner.scan()
        let snap = Snapshot(scannedAt: Date(), entries: entries)
        // Ne ré-affecte la prop @Published que si les entries ont changé.
        // Sans ce diff, SwiftUI re-render PortListView à chaque scan et
        // AppKit signale une récursion de layout sur NSStatusItemView
        // (WarnOnce "layoutSubtreeIfNeeded on a view already being laid out").
        if entries != self.snapshot.entries {
            self.snapshot = snap
        }
        try? SnapshotStore.write(snap)
    }
}
