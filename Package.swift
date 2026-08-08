// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "MicPause",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "MicPause", targets: ["MicPause"])
    ],
    targets: [
        .executableTarget(
            name: "MicPause",
            path: "Sources/MicPause",
            exclude: ["Resources"]
        ),
        .testTarget(
            name: "MicPauseTests",
            dependencies: ["MicPause"],
            path: "Tests/MicPauseTests"
        )
    ]
)
