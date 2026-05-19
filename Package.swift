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
            dependencies: ["Blocks", "Core"],
            path: "Sources/App",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("SwiftUI")
            ]
        ),
        .target(
            name: "Blocks",
            dependencies: ["CodexLog", "CopyHistory", "Core", "Quicksave"],
            path: "plugins",
            exclude: ["codexlog", "copyhistory", "quicksave"],
            sources: ["Blocks.swift"]
        ),
        .target(
            name: "Quicksave",
            dependencies: ["Core"],
            path: "plugins/quicksave/source",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon")
            ]
        ),
        .target(
            name: "CopyHistory",
            dependencies: ["Core"],
            path: "plugins/copyhistory/source"
        ),
        .target(
            name: "CodexLog",
            dependencies: ["Core"],
            path: "plugins/codexlog/source"
        ),
        .testTarget(
            name: "CoreTests",
            dependencies: ["Core"],
            path: "tests/CoreTests"
        ),
        .testTarget(
            name: "QuicksaveTests",
            dependencies: ["Quicksave"],
            path: "plugins/quicksave/tests"
        ),
        .testTarget(
            name: "CopyHistoryTests",
            dependencies: ["CopyHistory"],
            path: "plugins/copyhistory/tests"
        ),
        .testTarget(
            name: "CodexLogTests",
            dependencies: ["CodexLog"],
            path: "plugins/codexlog/tests"
        )
    ]
)
