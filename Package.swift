// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "GraphMetal",
    platforms: [
        .macOS(.v11), .iOS(.v14)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "GraphMetal",
            targets: ["GraphMetal"]),
        .library(
            name: "Shaders",
            targets: ["Shaders"])
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "git@github.com:jehansontech/GenericGraph.git", .branch("dev")),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "Shaders"),
        .target(
            name: "GraphMetal",
            dependencies: ["GenericGraph", .target(name: "Shaders")]),
        .testTarget(
            name: "GraphMetalTests",
            dependencies: [.target(name: "GraphMetal")]),
    ]
)
