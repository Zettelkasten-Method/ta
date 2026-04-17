// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ta",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "ta", targets: ["ta"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
        .package(url: "https://github.com/apple/swift-markdown", from: "0.4.0"),
        .package(url: "https://github.com/jpsim/Yams", from: "5.1.0"),
    ],
    targets: [
        .executableTarget(
            name: "ta",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Markdown", package: "swift-markdown"),
                .product(name: "Yams", package: "Yams"),
            ]
        ),
        .testTarget(
            name: "taTests",
            dependencies: ["ta"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
