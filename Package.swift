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
                .linkedFramework("SwiftUI")
            ]
        ),
        .target(
            name: "Blocks",
            dependencies: ["ActivityContext", "CodexLog", "CopyHistory", "FollowUpQueue", "GitHubQueue", "IntegrationHub", "Core", "Quicksave"],
            path: "plugins",
            exclude: ["activitycontext", "codexlog", "copyhistory", "followupqueue", "githubqueue", "integrationhub", "quicksave"],
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
        .target(
            name: "ActivityContext",
            dependencies: ["Core"],
            path: "plugins/activitycontext/source",
            linkerSettings: [
                .linkedFramework("AppKit")
            ]
        ),
        .target(
            name: "FollowUpQueue",
            dependencies: ["Core"],
            path: "plugins/followupqueue/source",
            linkerSettings: [
                .linkedFramework("AppKit")
            ]
        ),
        .target(
            name: "GitHubQueue",
            dependencies: ["Core"],
            path: "plugins/githubqueue/source",
            linkerSettings: [
                .linkedFramework("AppKit")
            ]
        ),
        .target(
            name: "IntegrationHub",
            dependencies: ["Core"],
            path: "plugins/integrationhub/source",
            linkerSettings: [
                .linkedFramework("AppKit")
            ]
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
            name: "ActivityContextTests",
            dependencies: ["ActivityContext"],
            path: "plugins/activitycontext/tests"
        ),
        .testTarget(
            name: "FollowUpQueueTests",
            dependencies: ["FollowUpQueue"],
            path: "plugins/followupqueue/tests"
        ),
        .testTarget(
            name: "GitHubQueueTests",
            dependencies: ["GitHubQueue"],
            path: "plugins/githubqueue/tests"
        ),
        .testTarget(
            name: "IntegrationHubTests",
            dependencies: ["IntegrationHub"],
            path: "plugins/integrationhub/tests"
        ),
        .testTarget(
            name: "BlockPreviewTests",
            dependencies: ["BlockPreviewSupport"],
            path: "tests/BlockPreviewTests"
        )
    ]
)
