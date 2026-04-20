// swift-tools-version: 6.0

/* Native */
import PackageDescription

// MARK: - Package

let package = Package(
    name: "Translator",
    platforms: [
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "Translator",
            targets: ["Translator"]
        ),
    ],
    dependencies: [
        //        .package(url: "https://github.com/nicklockwood/SwiftFormat", branch: "main"),
//        .package(url: "https://github.com/realm/SwiftLint", branch: "main"),
    ],
    targets: [
        .target(
            name: "Translator",
            dependencies: [],
            path: "Sources",
            swiftSettings: [.swiftLanguageMode(.v6)],
            plugins: [ /* .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLint") */ ]
        ),
    ]
)
