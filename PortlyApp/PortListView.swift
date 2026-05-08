import SwiftUI
import AppKit
import PortScanCore

struct PortListView: View {
    @ObservedObject var runner: ScanRunner
    @StateObject private var preferences = Preferences()
    @State private var showAll: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if visibleEntries.isEmpty {
                Text("No local servers detected")
                    .foregroundStyle(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(visibleEntries) { entry in
                            PortRow(entry: entry, onOpen: openURL)
                            Divider()
                        }
                    }
                }
                .frame(maxHeight: 360)
            }

            Divider()

            HStack(spacing: 12) {
                Toggle("Launch at login", isOn: $preferences.launchAtLogin)
                    .toggleStyle(.checkbox)
                    .font(.caption)
                Toggle("Show all", isOn: $showAll)
                    .toggleStyle(.checkbox)
                    .font(.caption)
                Spacer()
                Button("Refresh") { runner.forceRefresh() }
                    .keyboardShortcut("r", modifiers: .command)
                    .buttonStyle(.borderless)
                    .font(.caption)
                Button("Quit") { NSApp.terminate(nil) }
                    .buttonStyle(.borderless)
                    .font(.caption)
            }
            .padding(8)
        }
        .frame(width: 360)
    }

    private var visibleEntries: [PortEntry] {
        let all = runner.snapshot.entries
        return showAll ? all : all.filter(\.isHTTP)
    }

    private func openURL(_ entry: PortEntry) {
        guard entry.isHTTP, let url = URL(string: "http://localhost:\(entry.port)") else { return }
        NSWorkspace.shared.open(url)
    }
}

private struct PortRow: View {
    let entry: PortEntry
    let onOpen: (PortEntry) -> Void

    var body: some View {
        Button(action: { onOpen(entry) }) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.displayName)
                        .font(.body)
                        .foregroundStyle(entry.isHTTP ? .primary : .secondary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Text(":\(entry.port)")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(entry.isHTTP ? .primary : .secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!entry.isHTTP)
        .help(entry.isHTTP ? "Open http://localhost:\(entry.port)" : "Not an HTTP server")
    }

    private var subtitle: String {
        if let cwd = entry.cwd {
            return "\(entry.command) · \((cwd as NSString).abbreviatingWithTildeInPath)"
        }
        return entry.command
    }
}
