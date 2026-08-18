// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ExtraDock",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "ExtraDock",
            path: "Sources/ExtraDock"
        )
    ]
)
