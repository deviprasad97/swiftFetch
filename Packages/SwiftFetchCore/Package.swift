// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SwiftFetchCore",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "SwiftFetchCore",
            targets: ["SwiftFetchCore"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.0.0")
    ],
    targets: [
        .target(
            name: "SwiftFetchCore",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift")
            ]
        ),
        .testTarget(
            name: "SwiftFetchCoreTests",
            dependencies: ["SwiftFetchCore"]
        )
    ]
)