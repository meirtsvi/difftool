// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DiffTool",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "DiffTool",
            path: "Sources"
        )
    ]
)
