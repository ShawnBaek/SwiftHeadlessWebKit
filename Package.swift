// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "WKZombie",
    platforms: [
        .macOS(.v12),
        .iOS(.v15),
        .tvOS(.v15),
        .watchOS(.v8),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "WKZombie",
            targets: ["WKZombie"]
        ),
        .library(
            name: "WKZombieApple",
            targets: ["WKZombieApple"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.7.0")
    ],
    targets: [
        // Core cross-platform library
        .target(
            name: "WKZombie",
            dependencies: ["SwiftSoup"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        // Apple-specific extensions (WebKit rendering)
        .target(
            name: "WKZombieApple",
            dependencies: ["WKZombie"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        // Tests using Swift Testing framework
        .testTarget(
            name: "WKZombieTests",
            dependencies: ["WKZombie"],
            resources: [
                .copy("Resources")
            ]
        ),
        .testTarget(
            name: "WKZombieAppleTests",
            dependencies: ["WKZombieApple"],
            resources: [
                .copy("Resources")
            ]
        )
    ]
)
