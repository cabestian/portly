// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PortScanCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PortScanCore", targets: ["PortScanCore"])
    ],
    targets: [
        .target(name: "PortScanCore"),
        .testTarget(
            name: "PortScanCoreTests",
            dependencies: ["PortScanCore"],
            resources: [.copy("Fixtures")]
        )
    ]
)
