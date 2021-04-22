// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "GraphMetal",
    platforms: [
        .macOS(.v11), .iOS(.v14)
    ],
    products: [
        .library(
            name: "GraphMetal",
            targets: ["GraphMetal"]),
        .library(
            name: "Shaders",
            targets: ["Shaders", "GraphMetal"])
    ],
    dependencies: [
        .package(url: "git@github.com:jehansontech/GenericGraph.git", .branch("dev")),
    ],
    targets: [
        .target(
            name: "Shaders",
            resources: [.copy("Shaders.metallib")]),
        .target(
            name: "GraphMetal",
            dependencies: ["GenericGraph", .target(name: "Shaders")]),
        .testTarget(
            name: "GraphMetalTests",
            dependencies: [.target(name: "GraphMetal")]),
    ]
)
