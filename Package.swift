//swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "Corkboard",
    products: [
        .library(
            name: "corkboard-lib",
            targets: ["corkboard-lib"]
        ),
        .executable(
            name: "Corkboard",
            targets: ["corkboard-main"]
        ),
    ],
    targets: [
        .target(name: "corkboard-lib"),
        .executableTarget(
            name: "corkboard-main",
            dependencies: ["corkboard-lib"]
        ),
        .testTarget(
            name: "corkboard-libTests",
            dependencies: ["corkboard-lib"]
        ),
    ]
)
