// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Accentuate",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "AccentuateCore",
            resources: [.copy("Resources/accents.tsv")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "Accentuate",
            dependencies: ["AccentuateCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "AccentuateCoreTests",
            dependencies: ["AccentuateCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
