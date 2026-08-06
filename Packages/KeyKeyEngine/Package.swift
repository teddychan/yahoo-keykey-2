// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "KeyKeyEngine",
    // macOS 26 minimum, Apple Silicon only. Swift 5 language mode keeps the engine's
    // semantics identical to how the app compiles it (tools/build-app.sh: -swift-version 5).
    platforms: [.macOS(.v26)],
    products: [.library(name: "KeyKeyEngine", targets: ["KeyKeyEngine"])],
    targets: [
        // StrictConcurrency turns on complete data-race checking. Under the Swift 5 language
        // mode above it reports WARNINGS, not errors, so release semantics are unchanged — it
        // exists to surface isolation and Sendable problems the app's own -swift-version 5
        // compile cannot see. Keep this target at zero warnings.
        .target(name: "KeyKeyEngine", swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]),
        .testTarget(name: "KeyKeyEngineTests", dependencies: ["KeyKeyEngine"]),
    ],
    swiftLanguageModes: [.v5]
)
