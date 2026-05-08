import Testing
import Foundation
@testable import PortScanCore

@Suite("LsofParser")
struct LsofParserTests {
    private func loadFixture(_ name: String) throws -> String {
        let url = Bundle.module.url(forResource: name, withExtension: "txt", subdirectory: "Fixtures")!
        return try String(contentsOf: url)
    }

    @Test func parsesNormalListeners() throws {
        let raw = try loadFixture("lsof_normal")
        let listeners = LsofParser.parse(raw)
        #expect(listeners.count == 3)
        #expect(listeners[0] == Listener(pid: 1234, command: "node", port: 3000, address: "127.0.0.1"))
        #expect(listeners[1] == Listener(pid: 5678, command: "cargo", port: 4280, address: "*"))
        #expect(listeners[2] == Listener(pid: 9012, command: "postgres", port: 5432, address: "127.0.0.1"))
    }

    @Test func dedupesIPv4AndIPv6OnSamePort() throws {
        let raw = try loadFixture("lsof_ipv6")
        let listeners = LsofParser.parse(raw)
        #expect(listeners.count == 1)
        #expect(listeners[0].port == 8080)
    }

    @Test func skipsMalformedLines() {
        let raw = "p1234\nXgarbage\ncnode\nPTCP\nn127.0.0.1:3000\n"
        let listeners = LsofParser.parse(raw)
        #expect(listeners.count == 1)
        #expect(listeners[0].pid == 1234)
    }

    @Test func ignoresRemoteOnlyBinds() {
        let raw = "p1\ncssh\nPTCP\nn10.0.0.5:22\n"
        let listeners = LsofParser.parse(raw)
        #expect(listeners.isEmpty, "Non-local addresses should be filtered out")
    }
}
