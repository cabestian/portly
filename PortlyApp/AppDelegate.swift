import AppKit

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    let scanRunner = ScanRunner()
    private var statusBar: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        scanRunner.start()
        statusBar = StatusBarController(scanRunner: scanRunner)
    }
}
