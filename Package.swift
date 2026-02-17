// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Limiter",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "Limiter",
            path: "Sources"
        )
    ]
)
