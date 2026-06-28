// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "KeyKeyEngine",
    // macOS 26 minimum, Apple Silicon only. Swift 5 language mode keeps the engine's
    // semantics identical to how the app compiles it (tools/build-app.sh: -swift-version 5).
    platforms: [.macOS(.v26)],
    products: [.library(name: "KeyKeyEngine", targets: ["KeyKeyEngine"])],
    targets: [
        .target(name: "KeyKeyEngine"),
        .testTarget(name: "KeyKeyEngineTests", dependencies: ["KeyKeyEngine"]),
    ],
    swiftLanguageModes: [.v5]
)
