// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "surface",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "Core", targets: ["Core"]),
        .library(name: "UI", targets: ["UI"]),
        .executable(name: "block-preview", targets: ["BlockPreview"]),
        .executable(name: "App", targets: ["App"])
    ],
    targets: [
        .target(
            name: "Core",
            path: "Sources/Core"
        ),
        .target(
            name: "UI",
            dependencies: ["Core"],
            path: "Sources/UI"
        ),
        .executableTarget(
            name: "App",
            dependencies: ["Blocks", "Core", "UI"],
            path: "Sources/App",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("ServiceManagement"),
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
            name: "BlockPreviewSupport",
            dependencies: ["Blocks", "Core", "UI"],
            path: "tools/block-preview/support",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI")
            ]
        ),
        .executableTarget(
            name: "BlockPreview",
            dependencies: ["BlockPreviewSupport"],
            path: "tools/block-preview/source"
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
        ),
        .testTarget(
            name: "BlockPreviewTests",
            dependencies: ["BlockPreviewSupport"],
            path: "tests/BlockPreviewTests"
        )
    ]
)
