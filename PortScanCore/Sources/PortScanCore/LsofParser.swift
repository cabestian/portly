import Foundation

public enum LsofParser {
    /// Parses output of `lsof -nP -iTCP -sTCP:LISTEN -F pcnPL`.
    /// Returns one Listener per unique (pid, port). IPv6 entries are
    /// merged with their IPv4 twin on the same port.
    public static func parse(_ raw: String) -> [Listener] {
        var listeners: [Listener] = []
        var currentPid: Int32?
        var currentCommand: String = ""
        var seenForCurrent = Set<UInt16>()

        for line in raw.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let tag = line.first else { continue }
            let rest = String(line.dropFirst())

            switch tag {
            case "p":
                currentPid = Int32(rest)
                currentCommand = ""
                seenForCurrent.removeAll()
            case "c":
                currentCommand = rest
            case "n":
                guard let pid = currentPid,
                      let (addr, port) = Self.parseAddress(rest),
                      !seenForCurrent.contains(port),
                      Self.isLocal(addr) else { continue }
                seenForCurrent.insert(port)
                listeners.append(Listener(
                    pid: pid,
                    command: currentCommand,
                    port: port,
                    address: addr
                ))
            default:
                continue
            }
        }
        return listeners
    }

    private static func parseAddress(_ s: String) -> (address: String, port: UInt16)? {
        // Forms: "127.0.0.1:3000", "*:4280", "[::1]:8080"
        if s.hasPrefix("[") {
            guard let closeBracket = s.firstIndex(of: "]") else { return nil }
            let addr = String(s[s.index(after: s.startIndex)..<closeBracket])
            let afterBracket = s.index(after: closeBracket)
            guard afterBracket < s.endIndex, s[afterBracket] == ":" else { return nil }
            let portString = String(s[s.index(after: afterBracket)...])
            guard let port = UInt16(portString) else { return nil }
            return (addr, port)
        }
        guard let colon = s.lastIndex(of: ":") else { return nil }
        let addr = String(s[..<colon])
        let portString = String(s[s.index(after: colon)...])
        guard let port = UInt16(portString) else { return nil }
        return (addr, port)
    }

    private static func isLocal(_ address: String) -> Bool {
        return address == "127.0.0.1" || address == "::1" || address == "*"
    }
}
