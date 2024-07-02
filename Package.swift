// swift-tools-version: 5.10

/* Native */
import PackageDescription

// MARK: - Package

let package = Package(
    name: "Translator",
    platforms: [
        .iOS(.v17),
        .tvOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "Translator",
            targets: ["Translator"]
        ),
    ],
    dependencies: [
        //        .package(url: "https://github.com/nicklockwood/SwiftFormat", from: "0.53.8"),
//        .package(url: "https://github.com/realm/SwiftLint", branch: "main"),
    ],
    targets: [
        .target(
            name: "Translator",
            dependencies: [],
            path: "Sources" /* , */
//            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLint")]
        ),
    ]
)
