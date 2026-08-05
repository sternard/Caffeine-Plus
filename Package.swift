// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "CaffeinePlus",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "CaffeinePlusCore",
            targets: ["CaffeinePlusCore"]
        ),
        .executable(
            name: "CaffeinePlusApp",
            targets: ["CaffeinePlusApp"]
        )
    ],
    targets: [
        .target(
            name: "CaffeinePlusCore",
            linkerSettings: [
                .linkedFramework("IOKit")
            ]
        ),
        .executableTarget(
            name: "CaffeinePlusApp",
            dependencies: ["CaffeinePlusCore"]
        ),
        .testTarget(
            name: "CaffeinePlusCoreTests",
            dependencies: ["CaffeinePlusCore"]
        )
    ]
)
