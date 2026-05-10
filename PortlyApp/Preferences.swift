import ServiceManagement
import AppKit
import SwiftUI

// MARK: - Theme + density enums

enum PortlyStyle: String, CaseIterable, Identifiable {
    case original
    case soft
    case mono
    case tsshell

    var id: String { rawValue }

    var label: String {
        switch self {
        case .original: return "Original"
        case .soft: return "Soft"
        case .mono: return "Mono cards"
        case .tsshell: return "TypeScript shell (experimental)"
        }
    }
}

enum Density: String, CaseIterable, Identifiable {
    case regular
    case compact

    var id: String { rawValue }
    var label: String { self == .regular ? "Regular" : "Compact" }
}

let portlyStyleKey = "portly.style"
let portlyDensityKey = "portly.density"

// MARK: - Preferences (launch-at-login)

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

// MARK: - Preferences window content (SwiftUI)

struct PreferencesView: View {
    @AppStorage(portlyStyleKey) private var style: PortlyStyle = .original
    @AppStorage(portlyDensityKey) private var density: Density = .regular

    var body: some View {
        Form {
            Section {
                Picker("Style", selection: $style) {
                    ForEach(PortlyStyle.allCases) { s in
                        Text(s.label).tag(s)
                    }
                }
                .pickerStyle(.radioGroup)
            } header: {
                Text("Theme").font(.headline)
            } footer: {
                Text("Original is the look you've always known. Other themes are opt-in.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Picker("Density", selection: $density) {
                    Text("Regular").tag(Density.regular)
                    Text("Compact").tag(Density.compact)
                }
                .pickerStyle(.radioGroup)
            } header: {
                Text("Density").font(.headline)
            } footer: {
                Text("Compact reduces font sizes and paddings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 360)
    }
}

// MARK: - Preferences window controller

@MainActor
final class PreferencesWindowController: NSWindowController {
    static let shared = PreferencesWindowController()

    private convenience init() {
        let host = NSHostingController(rootView: PreferencesView())
        let window = NSWindow(contentViewController: host)
        window.title = "Portly Preferences"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        self.init(window: window)
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}
