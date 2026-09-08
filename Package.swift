// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RareUI",
    // macOS is declared so `swift test` runs the numeric goldens natively without a
    // simulator; the components themselves are SwiftUI and build for both.
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "RareUI", targets: ["RareUI"])
    ],
    targets: [
        .target(
            name: "RareUI",
            // Metal sources are not compiled unless they are declared. Processing them
            // produces a metallib inside the module's bundle, which is where
            // `ShaderLibrary.bundle(.module)` looks for it.
            resources: [.process("Shaders")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "RareUITests",
            dependencies: ["RareUI"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
