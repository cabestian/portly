import Foundation

/// Persists the most recent scan to disk. Lives at
/// `~/Library/Application Support/Portly/snapshot.json`.
public enum SnapshotStore {
    public static let snapshotFilename = "snapshot.json"

    public static var snapshotURL: URL? {
        guard let appSupport = try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        ) else { return nil }
        let dir = appSupport.appendingPathComponent("Portly", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(snapshotFilename)
    }

    public static func write(_ snapshot: Snapshot) throws {
        guard let url = snapshotURL else {
            throw NSError(domain: "SnapshotStore", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "No writable snapshot location"])
        }
        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: url, options: .atomic)
    }

    public static func read() -> Snapshot? {
        guard let url = snapshotURL,
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Snapshot.self, from: data)
    }
}
