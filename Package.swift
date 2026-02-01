// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SwiftOnce",
    platforms: [.iOS(.v16), .macOS(.v13), .tvOS(.v16), .watchOS(.v9), .visionOS(.v1)],
    products: [
        .library(name: "SwiftOnce", targets: ["SwiftOnce"]),
    ],
    targets: [
        .target(name: "SwiftOnce"),
        .testTarget(name: "SwiftOnceTests", dependencies: ["SwiftOnce"]),
    ]
)
