import SwiftUI
import AppKit
import PortScanCore
import Darwin

// MARK: - Shared helpers

@MainActor
private func openPreferencesWindow() {
    PreferencesWindowController.shared.show()
}

@MainActor
private func confirmAndKill(_ entry: PortEntry) {
    let alert = NSAlert()
    alert.messageText = "Kill \(entry.displayName)?"
    alert.informativeText = "Send SIGTERM to PID \(entry.pid) (port \(entry.port)). The process will be asked to exit."
    alert.alertStyle = .warning
    let killBtn = alert.addButton(withTitle: "Kill")
    if #available(macOS 11.0, *) { killBtn.hasDestructiveAction = true }
    alert.addButton(withTitle: "Cancel")
    if alert.runModal() == .alertFirstButtonReturn {
        let result = kill(entry.pid, SIGTERM)
        if result != 0 {
            NSLog("Portly: kill(\(entry.pid)) failed — errno=\(errno)")
        }
    }
}

// MARK: - Dispatcher

struct PortListView: View {
    @ObservedObject var runner: ScanRunner
    @StateObject private var preferences = Preferences()

    @AppStorage(portlyStyleKey) private var style: PortlyStyle = .original
    @AppStorage(portlyDensityKey) private var density: Density = .regular

    @State private var showAll: Bool = false

    private var visibleEntries: [PortEntry] {
        let all = runner.snapshot.entries
        return showAll ? all : all.filter(\.isHTTP)
    }

    private func openURL(_ entry: PortEntry) {
        guard entry.isHTTP, let url = URL(string: "http://localhost:\(entry.port)") else { return }
        NSWorkspace.shared.open(url)
    }

    var body: some View {
        Group {
            switch style {
            case .original:
                OriginalContent(
                    runner: runner,
                    preferences: preferences,
                    showAll: $showAll,
                    visibleEntries: visibleEntries,
                    density: density,
                    openURL: openURL
                )
            case .soft:
                SoftContent(
                    runner: runner,
                    showAll: $showAll,
                    visibleEntries: visibleEntries,
                    density: density,
                    openURL: openURL
                )
            case .mono:
                MonoContent(
                    runner: runner,
                    showAll: $showAll,
                    visibleEntries: visibleEntries,
                    density: density,
                    openURL: openURL
                )
            case .tsshell:
                TSShellContent(
                    runner: runner,
                    showAll: $showAll,
                    visibleEntries: visibleEntries,
                    density: density,
                    openURL: openURL
                )
            }
        }
        .frame(width: density == .compact ? 300 : 360)
        .background(invisiblePreferencesShortcut)
    }

    // Hidden ⌘, shortcut: zero visual change, opens Preferences when popover is key.
    private var invisiblePreferencesShortcut: some View {
        Button("Preferences") { PreferencesWindowController.shared.show() }
            .keyboardShortcut(",", modifiers: .command)
            .opacity(0)
            .frame(width: 0, height: 0)
            .allowsHitTesting(false)
    }
}

// MARK: - 0 · Original (pixel-identical to the legacy popover)

private struct OriginalContent: View {
    @ObservedObject var runner: ScanRunner
    @ObservedObject var preferences: Preferences
    @Binding var showAll: Bool
    let visibleEntries: [PortEntry]
    let density: Density
    let openURL: (PortEntry) -> Void

    private var compact: Bool { density == .compact }

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
                            OriginalRow(entry: entry, compact: compact, onOpen: openURL)
                            Divider()
                        }
                    }
                }
                .frame(maxHeight: 360)
            }

            Divider()

            HStack(spacing: compact ? 8 : 12) {
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
                Button { openPreferencesWindow() } label: {
                    Image(systemName: "gear")
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .help("Preferences…  ⌘,")
                Button("Quit") { NSApp.terminate(nil) }
                    .buttonStyle(.borderless)
                    .font(.caption)
            }
            .padding(compact ? 5 : 8)
        }
    }
}

private struct OriginalRow: View {
    let entry: PortEntry
    let compact: Bool
    let onOpen: (PortEntry) -> Void

    @State private var hovered = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Button(action: { if entry.isHTTP { onOpen(entry) } }) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.displayName)
                            .font(compact ? .system(size: 11.5) : .body)
                            .foregroundStyle(entry.isHTTP ? .primary : .secondary)
                            .lineLimit(1)
                        Text(subtitle)
                            .font(compact ? .system(size: 10) : .caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Text(":\(entry.port)")
                        .font(.system(compact ? .footnote : .body, design: .monospaced))
                        .foregroundStyle(entry.isHTTP ? .primary : .secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(entry.isHTTP ? "Open http://localhost:\(entry.port)" : "Not an HTTP server")

            if hovered {
                Button { confirmAndKill(entry) } label: {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color.red.opacity(0.8))
                        .imageScale(compact ? .small : .medium)
                }
                .buttonStyle(.plain)
                .help("Kill this process (SIGTERM)")
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
        .padding(.horizontal, compact ? 10 : 12)
        .padding(.vertical, compact ? 5 : 8)
        .contentShape(Rectangle())
        .onHover { hovered = $0 }
        .animation(.easeInOut(duration: 0.14), value: hovered)
    }

    private var subtitle: String {
        if let cwd = entry.cwd {
            return "\(entry.command) · \((cwd as NSString).abbreviatingWithTildeInPath)"
        }
        return entry.command
    }
}

// MARK: - 3 · Soft (Raycast / Arc / Linear)

private struct SoftContent: View {
    @ObservedObject var runner: ScanRunner
    @Binding var showAll: Bool
    let visibleEntries: [PortEntry]
    let density: Density
    let openURL: (PortEntry) -> Void

    private var compact: Bool { density == .compact }
    private let coral = Color(red: 1.0, green: 110/255, blue: 74/255)
    private let warm  = Color(red: 0.10, green: 0.10, blue: 0.12)

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(visibleEntries.count) services")
                    .foregroundStyle(.secondary)
                Spacer()
                LiveIndicator(color: coral)
            }
            .font(.system(size: compact ? 10 : 11))
            .padding(.horizontal, compact ? 8 : 10)
            .padding(.top, compact ? 5 : 8)
            .padding(.bottom, compact ? 4 : 6)

            if visibleEntries.isEmpty {
                Text("No local servers detected")
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                ScrollView {
                    VStack(spacing: compact ? 4 : 6) {
                        ForEach(visibleEntries) { entry in
                            SoftCard(entry: entry, compact: compact, accent: coral, onOpen: openURL)
                        }
                    }
                    .padding(.horizontal, compact ? 2 : 4)
                    .padding(.bottom, compact ? 5 : 8)
                }
                .frame(maxHeight: 360)
            }

            HStack {
                Button { runner.forceRefresh() } label: {
                    HStack(spacing: 4) {
                        Text("⌘R").font(.system(size: compact ? 9.5 : 10.5, design: .monospaced))
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(Color.black.opacity(0.05), in: RoundedRectangle(cornerRadius: 4))
                        Text("Refresh")
                    }
                }
                .keyboardShortcut("r", modifiers: .command)
                .buttonStyle(.plain)
                .foregroundStyle(warm)
                Spacer()
                Toggle("Show all", isOn: $showAll)
                    .toggleStyle(.button)
                    .controlSize(.small)
                Button { openPreferencesWindow() } label: {
                    Image(systemName: "gear")
                        .foregroundStyle(coral)
                }
                .buttonStyle(.plain)
                .help("Preferences…  ⌘,")
                Button("Quit") { NSApp.terminate(nil) }
                    .buttonStyle(.plain)
                    .foregroundStyle(warm)
            }
            .font(.system(size: compact ? 10 : 11.5))
            .padding(.horizontal, compact ? 6 : 8)
            .padding(.vertical, compact ? 4 : 6)
        }
        .padding(compact ? 7 : 10)
        .background(
            LinearGradient(
                colors: [Color(red: 0.997, green: 0.992, blue: 0.984),
                         Color(red: 0.969, green: 0.953, blue: 0.933)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .foregroundStyle(warm)
    }
}

private struct SoftCard: View {
    let entry: PortEntry
    let compact: Bool
    let accent: Color
    let onOpen: (PortEntry) -> Void

    @State private var hovered = false

    var body: some View {
        HStack(spacing: compact ? 8 : 10) {
            Button(action: { onOpen(entry) }) {
                HStack(spacing: compact ? 9 : 12) {
                    Circle()
                        .fill(entry.isHTTP ? Color(red: 41/255, green: 201/255, blue: 113/255) : Color(red: 200/255, green: 192/255, blue: 179/255))
                        .frame(width: compact ? 6 : 8, height: compact ? 6 : 8)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.displayName)
                            .font(.system(size: compact ? 11.5 : 13.5, weight: compact ? .medium : .semibold))
                            .foregroundStyle(entry.isHTTP ? .primary : .secondary)
                            .lineLimit(1)
                        Text(subtitle)
                            .font(.system(size: compact ? 10 : 11.5))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    Text("\(entry.port)")
                        .font(.system(size: compact ? 11 : 13, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(entry.isHTTP ? .primary : .secondary)
                    Text("→")
                        .font(.system(size: compact ? 11 : 14))
                        .foregroundStyle(entry.isHTTP ? accent : .clear)
                        .frame(width: compact ? 12 : 16, alignment: .trailing)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(entry.isHTTP ? "Open http://localhost:\(entry.port)" : "Not an HTTP server")

            if hovered {
                Button { confirmAndKill(entry) } label: {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color.red.opacity(0.85))
                        .imageScale(compact ? .small : .medium)
                }
                .buttonStyle(.plain)
                .help("Kill this process (SIGTERM)")
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
        .padding(.horizontal, compact ? 9 : 12)
        .padding(.vertical, compact ? 6 : 10)
        .background(
            RoundedRectangle(cornerRadius: compact ? 8 : 10)
                .fill(.white)
                .shadow(color: .black.opacity(hovered ? 0.16 : 0.03),
                        radius: hovered ? 6 : 1, x: 0, y: hovered ? 4 : 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: compact ? 8 : 10)
                .strokeBorder(.black.opacity(0.04))
        )
        .scaleEffect(hovered ? 1.005 : 1)
        .onHover { hovered = $0 }
        .animation(.easeInOut(duration: 0.14), value: hovered)
    }

    private var subtitle: String {
        if let cwd = entry.cwd {
            let abbreviated = (cwd as NSString).abbreviatingWithTildeInPath
            let basename = (abbreviated as NSString).lastPathComponent
            return "\(entry.command) · \(basename)"
        }
        return entry.command
    }
}

// MARK: - 5 · Mono cards (Warp / Vercel CLI)

private struct MonoContent: View {
    @ObservedObject var runner: ScanRunner
    @Binding var showAll: Bool
    let visibleEntries: [PortEntry]
    let density: Density
    let openURL: (PortEntry) -> Void

    private var compact: Bool { density == .compact }
    private let amber = Color(red: 1.0, green: 170/255, blue: 58/255)
    private let dim   = Color(red: 110/255, green: 101/255, blue: 87/255)
    private let cream = Color(red: 232/255, green: 223/255, blue: 208/255)

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(visibleEntries.count) services")
                Spacer()
                LiveIndicator(color: amber, label: "scanning")
            }
            .font(.system(size: compact ? 9.5 : 10.5, design: .monospaced))
            .tracking(1.0)
            .textCase(.uppercase)
            .foregroundStyle(dim)
            .padding(.horizontal, compact ? 8 : 10)
            .padding(.top, compact ? 4 : 6)
            .padding(.bottom, compact ? 7 : 10)

            if visibleEntries.isEmpty {
                Text("No local servers detected")
                    .font(.system(size: compact ? 11 : 12, design: .monospaced))
                    .foregroundStyle(dim)
                    .padding()
            } else {
                ScrollView {
                    VStack(spacing: compact ? 3 : 5) {
                        ForEach(visibleEntries) { entry in
                            MonoCard(entry: entry, compact: compact, amber: amber, dim: dim, cream: cream, onOpen: openURL)
                        }
                    }
                    .padding(.horizontal, compact ? 2 : 4)
                    .padding(.bottom, compact ? 5 : 8)
                }
                .frame(maxHeight: 360)
            }

            Divider().background(.white.opacity(0.05))

            HStack(spacing: compact ? 10 : 14) {
                MonoKbd("⏎", "open", amber: amber, compact: compact)
                MonoKbd("⌥⏎", "copy", amber: amber, compact: compact)
                MonoKbd("a", "all", amber: amber, compact: compact)
                MonoKbd("r", "refresh", amber: amber, compact: compact)
                Spacer()
                Button { openPreferencesWindow() } label: {
                    HStack(spacing: 4) {
                        Text(",")
                            .foregroundStyle(amber)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(amber.opacity(0.08), in: RoundedRectangle(cornerRadius: 3))
                        Text("prefs")
                    }
                }
                .buttonStyle(.plain)
                .help("Preferences…  ⌘,")
                Button("quit") { NSApp.terminate(nil) }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color(red: 138/255, green: 130/255, blue: 117/255))
            }
            .font(.system(size: compact ? 9.5 : 10.5, design: .monospaced))
            .tracking(0.8)
            .textCase(.uppercase)
            .foregroundStyle(dim)
            .padding(.horizontal, compact ? 8 : 10)
            .padding(.vertical, compact ? 5 : 8)
        }
        .padding(compact ? 7 : 10)
        .background(
            LinearGradient(
                colors: [Color(red: 21/255, green: 18/255, blue: 15/255),
                         Color(red: 28/255, green: 24/255, blue: 21/255)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .foregroundStyle(cream)
    }
}

private struct MonoCard: View {
    let entry: PortEntry
    let compact: Bool
    let amber: Color
    let dim: Color
    let cream: Color
    let onOpen: (PortEntry) -> Void

    @State private var hovered = false

    var body: some View {
        HStack(spacing: compact ? 7 : 10) {
            Button(action: { onOpen(entry) }) {
                HStack(alignment: .firstTextBaseline, spacing: compact ? 10 : 14) {
                    Text("\(entry.port)")
                        .font(.system(size: compact ? 11 : 13, weight: entry.isHTTP ? .semibold : .medium, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(entry.isHTTP ? amber : dim)
                        .frame(width: compact ? 46 : 56, alignment: .leading)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.displayName)
                            .font(.system(size: compact ? 11 : 12.5, design: .monospaced))
                            .foregroundStyle(entry.isHTTP ? cream : Color(red: 138/255, green: 130/255, blue: 117/255))
                            .lineLimit(1)
                        if let cwd = entry.cwd {
                            Text((cwd as NSString).abbreviatingWithTildeInPath)
                                .font(.system(size: compact ? 9.5 : 11, design: .monospaced))
                                .foregroundStyle(dim)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                    Text("→")
                        .font(.system(size: compact ? 11 : 13, design: .monospaced))
                        .foregroundStyle(entry.isHTTP ? amber : .clear)
                        .frame(width: compact ? 11 : 14, alignment: .trailing)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(entry.isHTTP ? "Open http://localhost:\(entry.port)" : "Not an HTTP server")

            if hovered {
                Button { confirmAndKill(entry) } label: {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color(red: 1.0, green: 100/255, blue: 80/255))
                        .imageScale(compact ? .small : .medium)
                }
                .buttonStyle(.plain)
                .help("Kill this process (SIGTERM)")
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
        .padding(.horizontal, compact ? 9 : 12)
        .padding(.vertical, compact ? 5 : 9)
        .background(
            RoundedRectangle(cornerRadius: compact ? 6 : 8)
                .fill(hovered ? amber.opacity(0.04) : Color(red: 32/255, green: 25/255, blue: 21/255).opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: compact ? 6 : 8)
                .strokeBorder(hovered ? amber.opacity(0.18) : .white.opacity(0.04))
        )
        .offset(y: hovered ? -1 : 0)
        .onHover { hovered = $0 }
        .animation(.easeInOut(duration: 0.13), value: hovered)
    }
}

private struct MonoKbd: View {
    let key: String
    let label: String
    let amber: Color
    let compact: Bool

    init(_ key: String, _ label: String, amber: Color, compact: Bool) {
        self.key = key; self.label = label; self.amber = amber; self.compact = compact
    }

    var body: some View {
        HStack(spacing: 4) {
            Text(key)
                .foregroundStyle(amber)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(amber.opacity(0.08), in: RoundedRectangle(cornerRadius: 3))
            Text(label)
        }
    }
}

// MARK: - 6 · TypeScript shell (VS Code Tokyo Night)

private struct TSShellContent: View {
    @ObservedObject var runner: ScanRunner
    @Binding var showAll: Bool
    let visibleEntries: [PortEntry]
    let density: Density
    let openURL: (PortEntry) -> Void

    private var compact: Bool { density == .compact }

    // Tokyo Night palette
    private let bg     = Color(red: 26/255, green: 27/255, blue: 38/255)
    private let head   = Color(red: 22/255, green: 22/255, blue: 30/255)
    private let border = Color(red: 44/255, green: 47/255, blue: 67/255)
    private let fg     = Color(red: 192/255, green: 202/255, blue: 245/255)
    private let kw     = Color(red: 187/255, green: 154/255, blue: 247/255)   // const
    private let ty     = Color(red: 42/255, green: 195/255, blue: 222/255)    // Listener
    private let key    = Color(red: 125/255, green: 207/255, blue: 255/255)   // port, name
    private let str    = Color(red: 158/255, green: 206/255, blue: 106/255)   // "next-dev"
    private let num    = Color(red: 255/255, green: 158/255, blue: 100/255)   // 3000
    private let comm   = Color(red: 86/255, green: 95/255, blue: 137/255)     // // comment
    private let punc   = Color(red: 108/255, green: 115/255, blue: 148/255)   // { } : ,

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 0) {
                    Text("● ").foregroundStyle(comm)
                    Text("services.ts").foregroundStyle(Color(red: 122/255, green: 162/255, blue: 247/255))
                }
                Spacer()
                Text("\(visibleEntries.count) listeners")
                    .foregroundStyle(comm)
            }
            .font(.system(size: compact ? 9.5 : 10.5, design: .monospaced))
            .padding(.horizontal, compact ? 12 : 14)
            .padding(.vertical, compact ? 4 : 6)
            .frame(maxWidth: .infinity)
            .background(head)
            .overlay(Rectangle().fill(border).frame(height: 1), alignment: .bottom)

            if visibleEntries.isEmpty {
                Text("// no local servers detected")
                    .font(.system(size: compact ? 11 : 12, design: .monospaced))
                    .foregroundStyle(comm)
                    .padding()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        TSLine(num: 1, compact: compact, comm: comm) {
                            Text("// click a row to open in browser").foregroundStyle(comm)
                        }
                        TSLine(num: 2, compact: compact, comm: comm) {
                            (
                                Text("const ").foregroundStyle(kw)
                                + Text("services").foregroundStyle(fg)
                                + Text(": ").foregroundStyle(punc)
                                + Text("Listener").foregroundStyle(ty)
                                + Text("[]").foregroundStyle(punc)
                                + Text(" = ").foregroundStyle(punc)
                                + Text("[").foregroundStyle(punc)
                            )
                        }
                        ForEach(Array(visibleEntries.enumerated()), id: \.offset) { idx, entry in
                            TSEntryLine(num: idx + 3, entry: entry, compact: compact,
                                        key: key, str: str, num_: num, punc: punc, fg: fg, comm: comm,
                                        accent: Color(red: 122/255, green: 162/255, blue: 247/255),
                                        onOpen: openURL)
                        }
                        TSLine(num: visibleEntries.count + 3, compact: compact, comm: comm) {
                            Text("]").foregroundStyle(punc)
                        }
                    }
                    .padding(.top, compact ? 5 : 8)
                    .padding(.bottom, compact ? 3 : 4)
                }
                .frame(maxHeight: 360)
            }

            HStack(spacing: 14) {
                tsKbd("⏎", "open")
                tsKbd("⌥⏎", "copy")
                tsKbd("a", "show all")
                Spacer()
                Button { openPreferencesWindow() } label: {
                    HStack(spacing: 3) {
                        Text(",").foregroundStyle(kw).italic(false)
                        Text("settings")
                    }
                }
                .buttonStyle(.plain)
                .help("Preferences…  ⌘,")
                tsKbd("q", "quit")
            }
            .font(.system(size: compact ? 9.5 : 10.5, design: .monospaced))
            .italic()
            .foregroundStyle(comm)
            .padding(.horizontal, compact ? 12 : 14)
            .padding(.vertical, compact ? 4 : 6)
            .overlay(Rectangle().fill(border).frame(height: 1), alignment: .top)
        }
        .background(bg)
    }

    private func tsKbd(_ k: String, _ label: String) -> some View {
        HStack(spacing: 3) {
            Text(k).foregroundStyle(kw).fontWeight(.regular).italic(false)
            Text(label)
        }
    }
}

private struct TSLine<Content: View>: View {
    let num: Int
    let compact: Bool
    let comm: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text("\(num)")
                .font(.system(size: compact ? 10 : 11, design: .monospaced))
                .foregroundStyle(Color(red: 59/255, green: 63/255, blue: 90/255))
                .frame(width: compact ? 24 : 28, alignment: .trailing)
                .padding(.trailing, compact ? 10 : 12)
            content()
                .font(.system(size: compact ? 11 : 12, design: .monospaced))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.trailing, compact ? 12 : 14)
        .padding(.vertical, compact ? 0 : 1)
    }
}

private struct TSEntryLine: View {
    let num: Int
    let entry: PortEntry
    let compact: Bool
    let key: Color
    let str: Color
    let num_: Color
    let punc: Color
    let fg: Color
    let comm: Color
    let accent: Color
    let onOpen: (PortEntry) -> Void

    @State private var hovered = false

    private var nameValue: String { entry.displayName.replacingOccurrences(of: "\"", with: "\\\"") }
    private var cwdValue: String? {
        guard let cwd = entry.cwd else { return nil }
        let abbreviated = (cwd as NSString).abbreviatingWithTildeInPath
        return (abbreviated as NSString).lastPathComponent
    }

    private func keyText(_ s: String) -> Text { Text(s).foregroundStyle(key) }
    private func strText(_ s: String, dim: Bool = false) -> Text {
        var t = Text("\"\(s)\"").foregroundStyle(str)
        if dim { t = t.foregroundStyle(str.opacity(0.55)) }
        return t
    }
    private func numText(_ n: UInt16, dim: Bool = false) -> Text {
        Text("\(n)").foregroundStyle(dim ? num_.opacity(0.55) : num_)
    }
    private func puncText(_ s: String) -> Text { Text(s).foregroundStyle(punc) }

    private var lineText: Text {
        if entry.isHTTP, let cwd = cwdValue {
            let part1 = puncText("  { ") + keyText("port") + puncText(": ") + numText(entry.port) + puncText(", ")
            let part2 = keyText("name") + puncText(": ") + strText(nameValue) + puncText(", ")
            let part3 = keyText("cwd") + puncText(": ") + strText(cwd) + puncText(" },")
            return part1 + part2 + part3
        } else {
            let part1 = puncText("  { ") + keyText("port") + puncText(": ") + numText(entry.port, dim: !entry.isHTTP)
            let part2 = puncText(", ") + keyText("name") + puncText(": ") + strText(nameValue, dim: !entry.isHTTP)
            let part3 = puncText(", ") + keyText("proto") + puncText(": ") + strText("tcp", dim: true) + puncText(" },")
            return part1 + part2 + part3
        }
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Button(action: { if entry.isHTTP { onOpen(entry) } }) {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("\(num)")
                        .font(.system(size: compact ? 10 : 11, design: .monospaced))
                        .foregroundStyle(Color(red: 59/255, green: 63/255, blue: 90/255))
                        .frame(width: compact ? 24 : 28, alignment: .trailing)
                        .padding(.trailing, compact ? 10 : 12)

                    lineText
                        .font(.system(size: compact ? 11 : 12, design: .monospaced))
                        .lineLimit(1)

                    if entry.isHTTP {
                        Text(" ↗")
                            .foregroundStyle(accent)
                            .opacity(hovered ? 1 : 0)
                            .font(.system(size: compact ? 11 : 12))
                            .padding(.leading, 4)
                    }

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(entry.isHTTP ? "Open http://localhost:\(entry.port)" : "Not an HTTP server")

            if hovered {
                Button { confirmAndKill(entry) } label: {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color(red: 247/255, green: 118/255, blue: 142/255))
                        .imageScale(compact ? .small : .medium)
                }
                .buttonStyle(.plain)
                .padding(.leading, 6)
                .help("Kill this process (SIGTERM)")
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
        .padding(.trailing, compact ? 12 : 14)
        .padding(.vertical, compact ? 0 : 1)
        .background(hovered && entry.isHTTP ? Color(red: 122/255, green: 162/255, blue: 247/255).opacity(0.07) : .clear)
        .onHover { hovered = $0 }
        .animation(.easeInOut(duration: 0.12), value: hovered)
    }
}

// MARK: - Shared live indicator (used by Soft and Mono)

private struct LiveIndicator: View {
    let color: Color
    var label: String = "scanning"

    @State private var pulse: CGFloat = 0

    var body: some View {
        HStack(spacing: 5) {
            ZStack {
                Circle().fill(color.opacity(0.45 - pulse * 0.45))
                    .frame(width: 6 + pulse * 14, height: 6 + pulse * 14)
                Circle().fill(color).frame(width: 6, height: 6)
            }
            .frame(width: 20, height: 20)
            Text(label)
                .foregroundStyle(color)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) {
                pulse = 1
            }
        }
    }
}
