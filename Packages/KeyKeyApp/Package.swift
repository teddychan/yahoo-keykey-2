// swift-tools-version:6.2
import PackageDescription

// Test-only harness for the App's dependency-light, non-UI logic (Preferences, the
// InputEngine protocol conformances, and the About/What's New content builders). The files
// under Sources/KeyKeyApp are SYMLINKS to the real App/ sources (SwiftPM cannot reference a
// path outside the package root), so there is no copy to drift. The release app is still
// built by tools/build-app.sh with swiftc; this package is never part of that path.
let package = Package(
    name: "KeyKeyApp",
    platforms: [.macOS(.v26)],
    products: [.library(name: "KeyKeyApp", targets: ["KeyKeyApp"])],
    dependencies: [
        .package(path: "../KeyKeyEngine"),
        .package(path: "../../vendor/dragon-kit"),
    ],
    targets: [
        .target(
            name: "KeyKeyApp",
            dependencies: [
                "KeyKeyEngine",
                .product(name: "DragonKit", package: "dragon-kit"),
            ],
            // Complete data-race checking, WARNINGS only under the Swift 5 language mode below
            // (see KeyKeyEngine/Package.swift). It covers the symlinked App/ sources too, which
            // is the only compile-time concurrency checking any App/ file gets. Keep it clean.
            swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]
        ),
        .testTarget(name: "KeyKeyAppTests", dependencies: ["KeyKeyApp"]),
    ],
    swiftLanguageModes: [.v5]
)
