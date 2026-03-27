// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "MidiClaw",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "MidiClawCore", targets: ["MidiClawCore"]),
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
        .testTarget(
            name: "MidiClawCoreTests",
            dependencies: ["MidiClawCore"],
            path: "Tests/MidiClawCoreTests"
        )
    ]
)
