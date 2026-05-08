import Foundation

/// A raw TCP listener observed via lsof, before HTTP probing.
public struct Listener: Equatable, Sendable {
    public let pid: Int32
    public let command: String
    public let port: UInt16
    public let address: String   // "127.0.0.1", "::1", or "*"

    public init(pid: Int32, command: String, port: UInt16, address: String) {
        self.pid = pid
        self.command = command
        self.port = port
        self.address = address
    }
}
