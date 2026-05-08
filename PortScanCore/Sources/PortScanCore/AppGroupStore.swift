import Foundation

public enum AppGroupStore {
    public static let groupID = "group.com.cabestian.portly"
    public static let snapshotFilename = "snapshot.json"

    public static var snapshotURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: groupID)?
            .appendingPathComponent(snapshotFilename)
    }

    /// Writes atomically — truncating an in-flight read is not acceptable.
    public static func write(_ snapshot: Snapshot) throws {
        guard let url = snapshotURL else {
            throw NSError(domain: "AppGroupStore", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "App group container not available"])
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
