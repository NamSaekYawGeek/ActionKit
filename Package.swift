// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ActionKitCore",
    platforms: [.iOS("18.0"), .macOS(.v13)],
    products: [.library(name: "ActionKitCore", targets: ["ActionKitCore"])],
    targets: [
        .target(name: "ActionKitCore"),
        .testTarget(name: "ActionKitCoreTests", dependencies: ["ActionKitCore"])
    ],
    swiftLanguageVersions: [.v5]
)
