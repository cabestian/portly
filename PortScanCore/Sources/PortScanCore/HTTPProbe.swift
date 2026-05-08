import Foundation

public enum HTTPProbe {
    public struct Result: Equatable, Sendable {
        public let isHTTP: Bool
        public let title: String?

        public init(isHTTP: Bool, title: String?) {
            self.isHTTP = isHTTP
            self.title = title
        }
    }

    /// Issues GET / on http://127.0.0.1:port. Returns isHTTP=true if any HTTP
    /// response is received. Extracts <title> from the body if present.
    public static func probe(port: UInt16, timeoutMs: Int = 300) async throws -> Result {
        guard let url = URL(string: "http://127.0.0.1:\(port)/") else {
            return Result(isHTTP: false, title: nil)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("bytes=0-2048", forHTTPHeaderField: "Range")
        request.timeoutInterval = TimeInterval(timeoutMs) / 1000.0

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = TimeInterval(timeoutMs) / 1000.0
        config.timeoutIntervalForResource = TimeInterval(timeoutMs) / 1000.0
        let session = URLSession(configuration: config)

        do {
            let (data, response) = try await session.data(for: request)
            guard response is HTTPURLResponse else {
                return Result(isHTTP: false, title: nil)
            }
            let body = String(data: data, encoding: .utf8) ?? ""
            return Result(isHTTP: true, title: Self.extractTitle(body))
        } catch {
            return Result(isHTTP: false, title: nil)
        }
    }

    private static func extractTitle(_ html: String) -> String? {
        guard let regex = try? NSRegularExpression(
            pattern: "<title[^>]*>([^<]+)</title>",
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else { return nil }
        let range = NSRange(html.startIndex..., in: html)
        guard let match = regex.firstMatch(in: html, range: range),
              let titleRange = Range(match.range(at: 1), in: html) else { return nil }
        return String(html[titleRange]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
