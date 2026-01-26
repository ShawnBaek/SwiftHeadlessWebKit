// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "VaporExample",
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.92.0"),
        .package(path: "../..")  // SwiftHeadlessWebKit
    ],
    targets: [
        .executableTarget(
            name: "VaporExample",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "SwiftHeadlessWebKit", package: "SwiftHeadlessWebKit")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "VaporExampleTests",
            dependencies: [
                "VaporExample",
                .product(name: "XCTVapor", package: "vapor")
            ]
        )
    ]
)
