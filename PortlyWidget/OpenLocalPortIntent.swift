import AppIntents
import AppKit

struct OpenLocalPortIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Local Port"
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Port") var port: Int

    init() {}
    init(port: Int) { self.port = port }

    @MainActor
    func perform() async throws -> some IntentResult {
        if let url = URL(string: "http://localhost:\(port)") {
            NSWorkspace.shared.open(url)
        }
        return .result()
    }
}
