import Foundation

public struct Snapshot: Codable, Equatable, Sendable {
    public let scannedAt: Date
    public let entries: [PortEntry]

    public init(scannedAt: Date, entries: [PortEntry]) {
        self.scannedAt = scannedAt
        self.entries = entries
    }
}
