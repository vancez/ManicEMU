// swift-tools-version:5.6
import PackageDescription

let package = Package(
    name: "RswiftResourcesVendored",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v11),
        .tvOS(.v11),
        .watchOS(.v4),
    ],
    products: [
        .library(name: "RswiftResourcesVendored", targets: ["RswiftResourcesVendored"])
    ],
    targets: [
        .target(name: "RswiftResourcesVendored")
    ]
)
