import AppKit
import Foundation
import PortScanCore

@MainActor
final class ScanRunner: ObservableObject {
    @Published private(set) var snapshot: Snapshot = Snapshot(scannedAt: .distantPast, entries: [])

    private let scanner = PortScanner()
    private var timer: Timer?
    private var fastMode = false
    private var isScanning = false
    private var isAsleep = false
    private var wakeObserver: NSObjectProtocol?
    private var sleepObserver: NSObjectProtocol?
    private var activityToken: NSObjectProtocol?

    func start() {
        beginAntiNapActivity()
        Task { await rescan() }
        scheduleTimer()
        observeSleepWake()
    }

    func setFastMode(_ on: Bool) {
        fastMode = on
        scheduleTimer()
        if on { Task { await rescan() } }
    }

    func forceRefresh() {
        Task { await rescan() }
    }

    /// Opt-out d'App Nap pour que le Timer continue de fire quand le menu est
    /// fermé (un agent .accessory sans fenêtre est une cible prioritaire d'App
    /// Nap, qui coalesce/suspend ses timers → données figées). On utilise
    /// .userInitiatedAllowingIdleSystemSleep : ça neutralise App Nap SANS
    /// empêcher le Mac de se mettre en veille — un moniteur de ports ne doit
    /// jamais bloquer le sommeil système.
    private func beginAntiNapActivity() {
        guard activityToken == nil else { return }
        activityToken = ProcessInfo.processInfo.beginActivity(
            options: .userInitiatedAllowingIdleSystemSleep,
            reason: "Portly monitors local ports"
        )
    }

    private func observeSleepWake() {
        let center = NSWorkspace.shared.notificationCenter
        if sleepObserver == nil {
            sleepObserver = center.addObserver(
                forName: NSWorkspace.willSleepNotification, object: nil, queue: nil
            ) { [weak self] _ in
                Task { @MainActor [weak self] in self?.isAsleep = true }
            }
        }
        if wakeObserver == nil {
            wakeObserver = center.addObserver(
                forName: NSWorkspace.didWakeNotification, object: nil, queue: nil
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.isAsleep = false
                    self.scheduleTimer()
                    // Débounce : au réveil, réseau et montages (disque externe,
                    // partages) sont instables. Scanner immédiatement maximise
                    // les hangs/timeouts. On laisse le système se rétablir.
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    await self.rescan()
                }
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
        // Garde de réentrance : timer, forceRefresh, toggle fast-mode et réveil
        // peuvent déclencher des rescans concurrents, chacun spawnant des
        // process lsof → on sérialise pour ne pas empiler le travail. On ne
        // scanne pas pendant le sommeil (rien à observer, montages instables).
        guard !isScanning, !isAsleep else { return }
        isScanning = true
        defer { isScanning = false }

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
