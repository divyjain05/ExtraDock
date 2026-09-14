// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ExtraDock",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0")
    ],
    targets: [
        .executableTarget(
            name: "ExtraDock",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/ExtraDock"
        )
    ]
)
