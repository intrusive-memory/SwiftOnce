// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SwiftOnce",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "SwiftOnce", targets: ["SwiftOnce"]),
    ],
    targets: [
        .target(name: "SwiftOnce"),
        .testTarget(name: "SwiftOnceTests", dependencies: ["SwiftOnce"]),
    ]
)
