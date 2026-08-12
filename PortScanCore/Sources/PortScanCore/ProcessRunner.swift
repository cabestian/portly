import Foundation

/// Lance un process externe en lisant stdout et stderr **en parallèle** de
/// l'attente, ce qui évite le deadlock de pipe (le child bloque en écriture
/// quand un buffer ~64 Ko se remplit et que personne ne le draine). Impose un
/// timeout dur : au-delà, le process est tué (`terminate`), les lectures voient
/// alors EOF et la fonction rend la main. `stderr` est drainé puis jeté.
public enum ProcessRunner {
    /// Conteneur thread-safe : écrit par le drain, lu après `group.wait()`.
    /// La barrière du DispatchGroup garantit le happens-before entre les deux.
    private final class DataBox: @unchecked Sendable {
        var data = Data()
    }

    public static func run(
        executable: String,
        args: [String],
        timeout: TimeInterval = 2.0
    ) async -> String {
        await withCheckedContinuation { (continuation: CheckedContinuation<String, Never>) in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = args

            let outPipe = Pipe()
            let errPipe = Pipe()
            process.standardOutput = outPipe
            process.standardError = errPipe

            do {
                try process.run()
            } catch {
                continuation.resume(returning: "")
                return
            }

            // Drains concurrents : chaque flux est lu sur sa propre tâche pour
            // que ni stdout ni stderr ne sature et ne bloque le child.
            let group = DispatchGroup()
            let outBox = DataBox()

            DispatchQueue.global().async(group: group) {
                outBox.data = outPipe.fileHandleForReading.readDataToEndOfFile()
            }
            DispatchQueue.global().async(group: group) {
                _ = errPipe.fileHandleForReading.readDataToEndOfFile()
            }

            // Timeout dur : tue le process s'il dépasse le délai. Les lectures
            // ci-dessus voient alors EOF et le group se complète. Le garde
            // `isRunning` rend ce tir inoffensif si le process est déjà sorti.
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                if process.isRunning { process.terminate() }
            }

            DispatchQueue.global().async {
                process.waitUntilExit()
                group.wait()                 // garantit que les deux drains sont finis
                continuation.resume(returning: String(data: outBox.data, encoding: .utf8) ?? "")
            }
        }
    }
}
