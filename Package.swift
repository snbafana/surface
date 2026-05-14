// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "surface",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "SurfaceCore", targets: ["SurfaceCore"]),
        .executable(name: "SurfaceApp", targets: ["SurfaceApp"])
    ],
    targets: [
        .target(
            name: "SurfaceCore",
            path: "src/SurfaceCore"
        ),
        .executableTarget(
            name: "SurfaceApp",
            dependencies: ["SurfaceCore"],
            path: "src/SurfaceApp",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI")
            ]
        ),
        .testTarget(
            name: "SurfaceCoreTests",
            dependencies: ["SurfaceCore"],
            path: "tests/SurfaceCoreTests"
        )
    ]
)
