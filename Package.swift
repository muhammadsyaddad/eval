// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "MacPulse",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "MacPulse", targets: ["MacPulse"])
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.24.0")
    ],
    targets: [
        .executableTarget(
            name: "MacPulse",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift")
            ],
            path: "Sources",
            exclude: ["MacPulse.entitlements", "Info.plist"]
        ),
        .testTarget(
            name: "MacPulseTests",
            dependencies: ["MacPulse"],
            path: "Tests/MacPulseTests"
        )
    ]
)
