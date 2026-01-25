// swift-tools-version: 6.0

import PackageDescription

// Platform-specific targets for Linux WebKit support
#if os(Linux)
let linuxTargets: [Target] = [
    // System library for WebKit on Linux
    // See: https://www.swift.org/blog/improving-usability-of-c-libraries-in-swift/
    .systemLibrary(
        name: "CWebKit",
        path: "Sources/CWebKit",
        pkgConfig: "wpe-webkit-1.1",
        providers: [
            .apt(["libwpewebkit-1.1-dev", "libwpe-1.0-dev"]),
            .yum(["wpewebkit-devel", "wpebackend-fdo-devel"])
        ]
    ),
    // Linux-specific extensions (WPE WebKit / WebKitGTK rendering)
    .target(
        name: "WKZombieLinux",
        dependencies: ["WKZombie", "CWebKit"],
        swiftSettings: [
            .swiftLanguageMode(.v6)
        ]
    )
]
let linuxProducts: [Product] = [
    .library(
        name: "SwiftHeadlessWebKitLinux",
        targets: ["WKZombieLinux"]
    )
]
#else
let linuxTargets: [Target] = []
let linuxProducts: [Product] = []
#endif

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
        .library(
            name: "SwiftHeadlessWebKit",
            targets: ["WKZombie"]
        ),
        .library(
            name: "SwiftHeadlessWebKitApple",
            targets: ["WKZombieApple"]
        )
    ] + linuxProducts,
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
    ] + linuxTargets
)
