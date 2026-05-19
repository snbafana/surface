// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "surface",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "Core", targets: ["Core"]),
        .executable(name: "App", targets: ["App"])
    ],
    targets: [
        .target(
            name: "Core",
            path: "Sources/Core"
        ),
        .executableTarget(
            name: "App",
            dependencies: ["Core"],
            path: "Sources/App",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("SwiftUI")
            ]
        ),
        .testTarget(
            name: "CoreTests",
            dependencies: ["Core"],
            path: "tests/CoreTests"
        )
    ]
)
