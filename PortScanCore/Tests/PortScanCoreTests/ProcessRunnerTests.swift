import Testing
import Foundation
@testable import PortScanCore

@Suite("ProcessRunner")
struct ProcessRunnerTests {

    /// Reproduit le deadlock historique : une commande qui écrit bien au-delà
    /// du buffer de pipe (~64 Ko) sur stdout ET stderr doit quand même se
    /// terminer et rendre la totalité de stdout. L'ancien runProcess (attente
    /// avant lecture, stderr jamais drainé) bloquait ici indéfiniment.
    @Test func drainsLargeStdoutAndStderrWithoutDeadlock() async {
        let lines = 10_000  // ~100 Ko par flux, largement au-dessus du buffer
        let script = "i=1; while [ $i -le \(lines) ]; do echo \"out-$i\"; echo \"err-$i\" 1>&2; i=$((i+1)); done"
        let out = await ProcessRunner.run(
            executable: "/bin/sh",
            args: ["-c", script],
            timeout: 10
        )
        // La dernière ligne présente prouve que tout stdout a été lu sans blocage.
        #expect(out.contains("out-\(lines)"))
    }

    /// Prouve que le timeout dur tue un process bloqué au lieu d'attendre l'infini.
    @Test func killsHungProcessWithinTimeout() async {
        let start = Date()
        let out = await ProcessRunner.run(
            executable: "/bin/sh",
            args: ["-c", "sleep 30"],
            timeout: 1
        )
        let elapsed = Date().timeIntervalSince(start)
        #expect(elapsed < 5)   // rendu rapidement, pas après 30 s
        #expect(out.isEmpty)
    }

    @Test func returnsStdoutForSimpleCommand() async {
        let out = await ProcessRunner.run(
            executable: "/bin/echo",
            args: ["hello"],
            timeout: 2
        )
        #expect(out.trimmingCharacters(in: .whitespacesAndNewlines) == "hello")
    }
}
