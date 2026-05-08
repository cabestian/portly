import Testing
@testable import PortScanCore

@Suite("NameResolver")
struct NameResolverTests {
    @Test func titleWinsOverCwdAndCommand() {
        let name = NameResolver.resolve(title: "My App", cwd: "/Users/x/dashboard", command: "node")
        #expect(name == "My App")
    }

    @Test func cwdBasenameWhenNoTitle() {
        let name = NameResolver.resolve(title: nil, cwd: "/Users/x/dashboard", command: "node")
        #expect(name == "dashboard")
    }

    @Test func commandWhenNothingElse() {
        let name = NameResolver.resolve(title: nil, cwd: nil, command: "postgres")
        #expect(name == "postgres")
    }

    @Test func emptyTitleFallsThroughToCwd() {
        let name = NameResolver.resolve(title: "   ", cwd: "/x/y", command: "z")
        #expect(name == "y")
    }

    @Test func stripsRTLOverride() {
        // U+202E reverses display order — classic spoofing trick.
        let name = NameResolver.resolve(title: "Bank.com\u{202E}drauf", cwd: nil, command: "x")
        #expect(name == "Bank.comdrauf")
    }

    @Test func stripsControlCharacters() {
        let name = NameResolver.resolve(title: "Hello\u{0007}World\nbreak", cwd: nil, command: "x")
        #expect(name == "HelloWorldbreak")
    }

    @Test func stripsZeroWidthChars() {
        let name = NameResolver.resolve(title: "App\u{200B}le\u{FEFF}Pay", cwd: nil, command: "x")
        #expect(name == "ApplePay")
    }

    @Test func capsLongTitle() {
        let long = String(repeating: "a", count: 500)
        let name = NameResolver.resolve(title: long, cwd: nil, command: "x")
        #expect(name.count == 201) // 200 chars + ellipsis
        #expect(name.hasSuffix("…"))
    }
}
