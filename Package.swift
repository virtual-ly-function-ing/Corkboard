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
    dependencies: [
        .package(url: "https://github.com/P-H-C/phc-winner-argon2.git", branch: "master")
    ],
    targets: [
        .target(
            name: "corkboard-lib",
            dependencies: [.product(name: "argon2", package: "phc-winner-argon2")]),
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
