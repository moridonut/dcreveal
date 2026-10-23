// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "dcreveal",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "dcreveal",
            path: "Sources/dcreveal"
        )
    ]
)
