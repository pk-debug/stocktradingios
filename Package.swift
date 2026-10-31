// swift-tools-version: 6.0
// Package.swift tells Swift how to compile the reusable core and its tests.
// The iOS app links this package through the Xcode project.
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
