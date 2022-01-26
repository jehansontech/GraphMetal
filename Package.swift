// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "GraphMetal",
    platforms: [
        .macOS(.v11), .iOS(.v14)
    ],
    products: [
//        .library(
//            name: "Shaders",
//            targets: ["Shaders"]),
        .library(
            name: "GraphMetal",
            targets: ["GraphMetal"])
    ],
    dependencies: [
        .package(url: "git@github.com:jehansontech/GenericGraph.git", .branch("dev")),
        .package(url: "git@github.com:jehansontech/Wacoma.git", .branch("dev")),
    ],
    targets: [
//        .target(
//            name: "Shaders",
//            dependencies: []),
        .target(
            name: "GraphMetal",
//            dependencies: ["GenericGraph", "Shaders", "Wacoma"]),
            dependencies: ["GenericGraph", "Wacoma"]),
        .testTarget(
            name: "GraphMetalTests",
            dependencies: ["GraphMetal"])
    ]
)
