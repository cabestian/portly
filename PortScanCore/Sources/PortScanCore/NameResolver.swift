import Foundation

public enum NameResolver {
    public static func resolve(title: String?, cwd: String?, command: String) -> String {
        if let t = title?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty {
            return t
        }
        if let c = cwd, !c.isEmpty {
            return (c as NSString).lastPathComponent
        }
        return command
    }
}
