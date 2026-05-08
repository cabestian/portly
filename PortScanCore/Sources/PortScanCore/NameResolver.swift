import Foundation

public enum NameResolver {
    public static func resolve(title: String?, cwd: String?, command: String) -> String {
        if let raw = title?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty {
            return sanitize(raw)
        }
        if let c = cwd, !c.isEmpty {
            return (c as NSString).lastPathComponent
        }
        return command
    }

    /// Strips C0/C1 control characters and Unicode bidi overrides from
    /// untrusted strings. Prevents UI spoofing via malicious HTTP <title>
    /// values (RTL override, invisible chars, line breaks, ...).
    static func sanitize(_ s: String) -> String {
        let stripped = String(s.unicodeScalars.filter { scalar in
            switch scalar.value {
            case 0x00...0x1F,         // C0 controls (incl. \n, \r, \t)
                 0x7F...0x9F,         // DEL + C1 controls
                 0x202A...0x202E,     // LRE, RLE, PDF, LRO, RLO
                 0x2066...0x2069,     // LRI, RLI, FSI, PDI
                 0x200E, 0x200F,      // LRM, RLM
                 0x200B, 0x200C, 0x200D, 0xFEFF: // zero-width spaces, BOM
                return false
            default:
                return true
            }
        })
        // Cap to 200 chars so a megabyte-long title can't blow up the UI.
        if stripped.count > 200 {
            return String(stripped.prefix(200)) + "…"
        }
        return stripped
    }
}
