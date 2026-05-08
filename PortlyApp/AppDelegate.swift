import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let scanRunner = ScanRunner()
    private var statusBar: StatusBarController?

    nonisolated override init() { super.init() }

    func applicationDidFinishLaunching(_ notification: Notification) {
        scanRunner.start()
        statusBar = StatusBarController(scanRunner: scanRunner)
    }
}
