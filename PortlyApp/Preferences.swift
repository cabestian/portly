import ServiceManagement
import AppKit

@MainActor
final class Preferences: ObservableObject {
    @Published var launchAtLogin: Bool {
        didSet {
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                NSLog("Portly: failed to update login item — \(error)")
            }
        }
    }

    init() {
        self.launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}
