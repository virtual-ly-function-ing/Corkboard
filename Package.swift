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
        .package(url: "https://github.com/P-H-C/phc-winner-argon2.git", revision: "f57e61e19229e23c4445b85494dbf7c07de721cb"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0"),
    ],
    targets: [
        .target(
            name: "corkboard-lib",
            dependencies: [
                .product(name: "argon2", package: "phc-winner-argon2"),
                .product(name: "Crypto", package: "swift-crypto"),
            ]
        ),
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
