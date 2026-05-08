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
}
