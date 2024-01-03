// swift-tools-version: 5.9

import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("BareSlashRegexLiterals"),
    .enableUpcomingFeature("ConciseMagicFile"),
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("ForwardTrailingClosures"),
    .enableUpcomingFeature("ImplicitOpenExistentials"),
    .enableUpcomingFeature("StrictConcurrency"),
    .unsafeFlags([
        "-warn-concurrency", "-enable-actor-data-race-checks",
    ]),
]

let package = Package(
    name: "ScribeSystem",
    products: [
        .library(
            name: "ScribeSystem",
            targets: ["ScribeSystem"]),
        .plugin(
            name: "FilesPlugin",
            targets: ["FilesPlugin"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/apple/swift-nio.git",
            from: "2.62.0")
    ],
    targets: [
        .executableTarget(name: "Http", dependencies: ["ScribeSystem"]),
        .target(
            name: "ScribeSystem",
            dependencies: [
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
            ],
            exclude: ["README.md"]
            // Swift 6 settings disabled for for tagged release.
            // ,swiftSettings: swiftSettings
        ),
        .executableTarget(name: "Files", dependencies: ["ScribeSystem"]),
        // Plugins
        .plugin(
            name: "FilesPlugin",
            capability: .command(
                intent: .custom(
                    verb: "files",
                    description: "changing files"),
                permissions: [
                    .writeToPackageDirectory(
                        reason: "changes files")
                ]
            ),
            dependencies: [
                "Files"
            ]
        ),
    ]
)
