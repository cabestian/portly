import Foundation

public actor PortScanner {
    public init() {}

    public func scan(probeTimeoutMs: Int = 300) async -> [PortEntry] {
        let raw = await Self.runLsofListeners()
        let listeners = LsofParser.parse(raw)

        return await withTaskGroup(of: PortEntry.self) { group in
            for listener in listeners {
                group.addTask {
                    let cwd = await Self.cwd(for: listener.pid)
                    let probeResult = (try? await HTTPProbe.probe(
                        port: listener.port,
                        timeoutMs: probeTimeoutMs
                    )) ?? HTTPProbe.Result(isHTTP: false, title: nil)
                    return PortEntry(
                        port: listener.port,
                        pid: listener.pid,
                        command: listener.command,
                        cwd: cwd,
                        title: probeResult.title,
                        isHTTP: probeResult.isHTTP
                    )
                }
            }
            var results: [PortEntry] = []
            for await entry in group { results.append(entry) }
            return results.sorted { $0.port < $1.port }
        }
    }

    private static func runLsofListeners() async -> String {
        await runProcess(
            executable: "/usr/sbin/lsof",
            args: ["-nP", "-iTCP", "-sTCP:LISTEN", "-F", "pcnPL"]
        )
    }

    private static func cwd(for pid: Int32) async -> String? {
        let raw = await runProcess(
            executable: "/usr/sbin/lsof",
            args: ["-a", "-p", String(pid), "-d", "cwd", "-F", "n"]
        )
        for line in raw.split(separator: "\n") where line.first == "n" {
            return String(line.dropFirst())
        }
        return nil
    }

    private static func runProcess(executable: String, args: [String]) async -> String {
        await withCheckedContinuation { (continuation: CheckedContinuation<String, Never>) in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = args
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()
            do {
                try process.run()
            } catch {
                continuation.resume(returning: "")
                return
            }
            DispatchQueue.global().async {
                process.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                continuation.resume(returning: String(data: data, encoding: .utf8) ?? "")
            }
        }
    }
}
