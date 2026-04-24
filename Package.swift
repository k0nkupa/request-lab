// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "RequestLab",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "RequestLab", targets: ["RequestLab"]),
        .library(name: "RequestLabCore", targets: ["RequestLabCore"])
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "6.2.1")
    ],
    targets: [
        .executableTarget(
            name: "RequestLab",
            dependencies: ["RequestLabCore"],
            path: "Sources/RequestLab"
        ),
        .target(
            name: "RequestLabCore",
            dependencies: [
                .product(name: "Yams", package: "Yams")
            ],
            path: "Sources/RequestLabCore"
        ),
        .testTarget(
            name: "RequestLabCoreTests",
            dependencies: ["RequestLabCore"],
            path: "Tests/RequestLabCoreTests"
        )
    ]
)
