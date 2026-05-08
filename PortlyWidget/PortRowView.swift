import SwiftUI
import AppIntents
import PortScanCore

struct PortRowView: View {
    let entry: PortEntry

    var body: some View {
        Button(intent: OpenLocalPortIntent(port: Int(entry.port))) {
            HStack {
                Text(entry.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Spacer()
                Text(":\(entry.port)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
