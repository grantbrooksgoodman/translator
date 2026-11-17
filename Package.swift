// swift-tools-version: 6.0

/* Native */
import PackageDescription

let package = Package(
    name: "Translator",
    platforms: [
        .iOS(.v18),
    ],
    products: [
        .library(
            name: "Translator",
            targets: ["Translator"]
        ),
    ],
    targets: [
        .target(
            name: "Translator",
            dependencies: [],
            path: "Sources",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
