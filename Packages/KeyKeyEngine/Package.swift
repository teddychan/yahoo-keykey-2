// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "KeyKeyEngine",
    platforms: [.macOS(.v12)],
    products: [.library(name: "KeyKeyEngine", targets: ["KeyKeyEngine"])],
    targets: [
        .target(name: "KeyKeyEngine"),
        .testTarget(name: "KeyKeyEngineTests", dependencies: ["KeyKeyEngine"]),
    ]
)
