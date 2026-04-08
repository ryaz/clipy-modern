// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Clipy",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Clipy", targets: ["Clipy"])],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0"),
        .package(url: "https://github.com/Clipy/Sauce", from: "2.4.0"),
    ],
    targets: [
        .executableTarget(
            name: "Clipy",
            dependencies: [
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
                .product(name: "Sparkle", package: "Sparkle"),
                .product(name: "Sauce", package: "Sauce"),
            ],
            path: "Clipy/Sources",
            resources: [.process("Resources")]
        ),
        .testTarget(name: "ClipyTests", dependencies: ["Clipy"], path: "ClipyTests")
    ]
)
