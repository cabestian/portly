import AppKit
import SwiftUI

final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private let scanRunner: ScanRunner

    init(scanRunner: ScanRunner) {
        self.scanRunner = scanRunner
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "network", accessibilityDescription: "Portly")
            button.target = self
            button.action = #selector(togglePopover)
        }

        popover.behavior = .transient
        popover.contentSize = NSSize(width: 360, height: 420)
        popover.contentViewController = NSHostingController(
            rootView: PortListView(runner: scanRunner)
        )
        popover.delegate = self
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}

extension StatusBarController: NSPopoverDelegate {
    func popoverWillShow(_ notification: Notification) { scanRunner.setFastMode(true) }
    func popoverDidClose(_ notification: Notification) { scanRunner.setFastMode(false) }
}
