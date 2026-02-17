// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Eval",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Eval", targets: ["Eval"])
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.24.0")
    ],
    targets: [
        .executableTarget(
            name: "Eval",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift")
            ],
            path: "Sources",
            exclude: ["Eval.entitlements", "Info.plist"],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "EvalTests",
            dependencies: ["Eval"],
            path: "EvalTests"
        )
    ]
)
