import Foundation

public enum AppGroupStore {
    public static let groupID = "group.com.cabestian.portly"
    public static let snapshotFilename = "snapshot.json"

    /// Returns the App Group container if available (signed builds with the right
    /// entitlement), otherwise falls back to ~/Library/Application Support/Portly/.
    /// The fallback means the menu-bar app works in ad-hoc dev builds; the widget
    /// still needs a proper signed build to share state.
    public static var snapshotURL: URL? {
        if let group = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: groupID) {
            return group.appendingPathComponent(snapshotFilename)
        }
        guard let appSupport = try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        ) else { return nil }
        let dir = appSupport.appendingPathComponent("Portly", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(snapshotFilename)
    }

    /// Writes atomically — truncating an in-flight read is not acceptable.
    public static func write(_ snapshot: Snapshot) throws {
        guard let url = snapshotURL else {
            throw NSError(domain: "AppGroupStore", code: 1,
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
