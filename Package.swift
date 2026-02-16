// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Limiter",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Limiter",
            path: "Sources"
        )
    ]
)
