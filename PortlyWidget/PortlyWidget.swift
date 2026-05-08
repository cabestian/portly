import WidgetKit
import SwiftUI
import PortScanCore

@main
struct PortlyWidgetBundle: WidgetBundle {
    var body: some Widget {
        PortlyWidget()
    }
}

struct PortlyWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.cabestian.portly.widget", provider: PortlyTimelineProvider()) { entry in
            PortlyWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Portly")
        .description("Click to jump to a local server.")
        .supportedFamilies([.systemMedium])
    }
}

struct PortlyTimelineEntry: TimelineEntry {
    let date: Date
    let snapshot: Snapshot?
}

struct PortlyTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> PortlyTimelineEntry {
        PortlyTimelineEntry(date: .now, snapshot: nil)
    }
    func getSnapshot(in context: Context, completion: @escaping (PortlyTimelineEntry) -> Void) {
        completion(.init(date: .now, snapshot: AppGroupStore.read()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<PortlyTimelineEntry>) -> Void) {
        let entry = PortlyTimelineEntry(date: .now, snapshot: AppGroupStore.read())
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(30))))
    }
}

struct PortlyWidgetView: View {
    let entry: PortlyTimelineEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Portly")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.top, 6)
            Divider()

            if let entries = httpEntries, !entries.isEmpty {
                ForEach(entries.prefix(5)) { e in
                    PortRowView(entry: e)
                    Divider()
                }
                Spacer(minLength: 0)
            } else if let snap = entry.snapshot, snap.scannedAt > Date().addingTimeInterval(-60) {
                Spacer()
                Text("No local servers detected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                Spacer()
                Text("Portly is not running")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            }
        }
    }

    private var httpEntries: [PortEntry]? {
        entry.snapshot?.entries.filter(\.isHTTP)
    }
}
