// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SwiftHeadlessWebKit",
    platforms: [
        .macOS(.v12),
        .iOS(.v15),
        .tvOS(.v15),
        .watchOS(.v8),
        .visionOS(.v1)
    ],
    products: [
        // Unified product - automatically uses correct engine per platform
        .library(
            name: "SwiftHeadlessWebKit",
            targets: ["SwiftHeadlessWebKit"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.7.0")
    ],
    targets: [
        // Unified target that re-exports platform-specific modules
        .target(
            name: "SwiftHeadlessWebKit",
            dependencies: [
                "WKZombie",
                .target(name: "WKZombieApple", condition: .when(platforms: [.macOS, .iOS, .tvOS, .watchOS, .visionOS])),
                .target(name: "WKZombieLinux", condition: .when(platforms: [.linux]))
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
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
        // Linux-specific extensions
        .target(
            name: "WKZombieLinux",
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
