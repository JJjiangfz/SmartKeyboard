// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SmartKeyboard",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "SmartKeyboardCore",
            targets: ["SmartKeyboardCore"]
        ),
        .executable(
            name: "SmartKeyboardCLI",
            targets: ["SmartKeyboardCLI"]
        ),
        .executable(
            name: "SmartKeyboardApp",
            targets: ["SmartKeyboardApp"]
        ),
        .executable(
            name: "SmartKeyboardSelfTest",
            targets: ["SmartKeyboardSelfTest"]
        )
    ],
    targets: [
        .target(
            name: "SmartKeyboardCore"
        ),
        .executableTarget(
            name: "SmartKeyboardCLI",
            dependencies: ["SmartKeyboardCore"]
        ),
        .executableTarget(
            name: "SmartKeyboardApp",
            dependencies: ["SmartKeyboardCore"]
        ),
        .executableTarget(
            name: "SmartKeyboardSelfTest",
            dependencies: ["SmartKeyboardCore"]
        ),
        .testTarget(
            name: "SmartKeyboardCoreTests",
            dependencies: ["SmartKeyboardCore"],
            swiftSettings: [
                .unsafeFlags([
                    "-F", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks"
                ])
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-F", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
                    "-Xlinker", "-rpath",
                    "-Xlinker", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks"
                ])
            ]
        )
    ]
)
