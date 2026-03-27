// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "MidiClaw",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "MidiClawCore", targets: ["MidiClawCore"]),
        .library(name: "MidiClawAU", targets: ["MidiClawAU"]),
        .executable(name: "MidiClaw", targets: ["MidiClaw"])
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.24.0")
    ],
    targets: [
        .target(
            name: "MidiClawCore",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift")
            ],
            path: "Sources/MidiClawCore"
        ),
        .executableTarget(
            name: "MidiClaw",
            dependencies: ["MidiClawCore"],
            path: "Sources/MidiClaw"
        ),
        .target(
            name: "MidiClawAU",
            dependencies: ["MidiClawCore"],
            path: "Sources/MidiClawAU",
            linkerSettings: [
                .linkedFramework("AudioToolbox"),
                .linkedFramework("CoreMIDI"),
                .linkedFramework("CoreAudioKit"),
                .linkedFramework("AVFoundation"),
            ]
        ),
        .testTarget(
            name: "MidiClawCoreTests",
            dependencies: ["MidiClawCore"],
            path: "Tests/MidiClawCoreTests"
        ),
        .testTarget(
            name: "MidiClawAUTests",
            dependencies: ["MidiClawAU", "MidiClawCore"],
            path: "Tests/MidiClawAUTests"
        )
    ]
)
