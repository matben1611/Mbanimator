// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Mbanimator",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Mbanimator",
            path: "Sources/Mbanimator"
        )
    ]
)
