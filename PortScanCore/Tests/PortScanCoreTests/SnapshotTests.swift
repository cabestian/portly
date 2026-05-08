import Testing
import Foundation
@testable import PortScanCore

@Suite("Snapshot")
struct SnapshotTests {
    @Test func roundtripJSON() throws {
        let snap = Snapshot(
            scannedAt: Date(timeIntervalSince1970: 1_700_000_000),
            entries: [
                PortEntry(port: 3000, pid: 1, command: "node", cwd: "/x/y", title: "Hi", isHTTP: true),
                PortEntry(port: 5432, pid: 2, command: "postgres", cwd: nil, title: nil, isHTTP: false)
            ]
        )
        let data = try JSONEncoder().encode(snap)
        let decoded = try JSONDecoder().decode(Snapshot.self, from: data)
        #expect(decoded == snap)
    }
}
