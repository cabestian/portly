import Foundation

/// A fully-resolved listener with HTTP-probe and name-resolution results.
/// This is the model written to snapshot.json and consumed by the widget.
public struct PortEntry: Codable, Equatable, Identifiable, Sendable {
    public let port: UInt16
    public let pid: Int32
    public let command: String
    public let cwd: String?
    public let title: String?
    public let isHTTP: Bool

    public var id: UInt16 { port }

    public var displayName: String {
        if let t = title?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty {
            return t
        }
        if let c = cwd, !c.isEmpty {
            return (c as NSString).lastPathComponent
        }
        return command
    }

    public init(port: UInt16, pid: Int32, command: String, cwd: String?, title: String?, isHTTP: Bool) {
        self.port = port
        self.pid = pid
        self.command = command
        self.cwd = cwd
        self.title = title
        self.isHTTP = isHTTP
    }
}
