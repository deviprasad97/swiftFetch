// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Aria2RPC",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "Aria2RPC",
            targets: ["Aria2RPC"]
        )
    ],
    targets: [
        .target(
            name: "Aria2RPC",
            dependencies: []
        ),
        .testTarget(
            name: "Aria2RPCTests",
            dependencies: ["Aria2RPC"]
        )
    ]
)