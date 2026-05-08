import Testing
import Foundation
import Network
@testable import PortScanCore

@Suite("HTTPProbe")
struct HTTPProbeTests {

    @Test func returnsTrueForRespondingHTTPServer() async throws {
        let server = try EmbeddedHTTPServer(responseBody: "<html><head><title>Hello</title></head></html>")
        let port = server.port
        defer { server.stop() }

        let result = try await HTTPProbe.probe(port: port, timeoutMs: 1000)
        #expect(result.isHTTP)
        #expect(result.title == "Hello")
    }

    @Test func returnsFalseForNonHTTPListener() async throws {
        // Open a raw TCP listener that never sends HTTP back.
        let listener = try NWListener(using: .tcp, on: .any)
        let ready = DispatchSemaphore(value: 0)
        listener.stateUpdateHandler = { state in
            if case .ready = state { ready.signal() }
        }
        listener.newConnectionHandler = { conn in
            conn.start(queue: .main)
        }
        listener.start(queue: .main)
        defer { listener.cancel() }

        _ = ready.wait(timeout: .now() + 2)
        guard let port = listener.port?.rawValue, port != 0 else {
            Issue.record("Listener didn't bind")
            return
        }

        let result = try await HTTPProbe.probe(port: port, timeoutMs: 300)
        #expect(!result.isHTTP)
    }

    @Test func returnsFalseWhenNothingListens() async throws {
        // Port 1 is reserved/unused on macOS for normal users.
        let result = try await HTTPProbe.probe(port: 1, timeoutMs: 200)
        #expect(!result.isHTTP)
    }
}

/// Minimal HTTP server for tests. Returns a fixed response on any request.
final class EmbeddedHTTPServer: @unchecked Sendable {
    let listener: NWListener
    let response: String
    private let readySignal = DispatchSemaphore(value: 0)
    var port: UInt16 { listener.port?.rawValue ?? 0 }

    init(responseBody body: String) throws {
        let header = "HTTP/1.1 200 OK\r\nContent-Length: \(body.utf8.count)\r\nContent-Type: text/html\r\n\r\n"
        self.response = header + body
        self.listener = try NWListener(using: .tcp, on: .any)

        let captured = response
        let signal = readySignal
        listener.stateUpdateHandler = { state in
            if case .ready = state { signal.signal() }
        }
        listener.newConnectionHandler = { conn in
            conn.start(queue: .global())
            conn.receive(minimumIncompleteLength: 1, maximumLength: 4096) { _, _, _, _ in
                conn.send(content: captured.data(using: .utf8)!, completion: .contentProcessed { _ in
                    conn.cancel()
                })
            }
        }
        listener.start(queue: .global())

        _ = readySignal.wait(timeout: .now() + 2)
    }

    func stop() {
        listener.cancel()
    }
}
