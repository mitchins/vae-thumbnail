// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "VAEThumbnailKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "VAEThumbnailKit",
            targets: ["VAEThumbnailKit"]
        ),
        .executable(
            name: "BasicThumbnailCLI",
            targets: ["BasicThumbnailCLI"]
        )
    ],
    targets: [
        .target(
            name: "VAEThumbnailKit",
            resources: [
                .copy("Resources/Models")
            ]
        ),
        .executableTarget(
            name: "BasicThumbnailCLI",
            dependencies: ["VAEThumbnailKit"],
            path: "Examples/BasicThumbnailCLI"
        ),
        .testTarget(
            name: "VAEThumbnailKitTests",
            dependencies: ["VAEThumbnailKit"]
        )
    ]
)
