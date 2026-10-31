// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NorthstarCore",
    platforms: [.iOS(.v18), .macOS(.v13)],
    products: [.library(name: "NorthstarCore", targets: ["NorthstarCore"])],
    targets: [
        .target(name: "NorthstarCore"),
        .testTarget(name: "NorthstarCoreTests", dependencies: ["NorthstarCore"])
    ],
    swiftLanguageModes: [.v6]
)
