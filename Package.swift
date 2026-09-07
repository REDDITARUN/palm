// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Palm",
    platforms: [.macOS(.v15)],
    products: [.executable(name: "Palm", targets: ["Palm"]), .library(name: "PalmKit", targets: ["PalmCore", "PalmComponents"])],
    dependencies: [
        .package(path: "Vendor/CodeEditSymbols"),
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0"),
        .package(url: "https://github.com/gonzalezreal/textual.git", branch: "main"),
        .package(url: "https://github.com/nodes-app/swift-markdown-engine.git", branch: "main"),
        .package(url: "https://github.com/CodeEditApp/CodeEditSourceEditor.git", branch: "main"),
        .package(url: "https://github.com/open-spaced-repetition/swift-fsrs.git", branch: "main"),
        .package(url: "https://github.com/MacPaw/OpenAI.git", from: "0.4.7")
    ],
    targets: [
        .target(name: "PalmComponents", dependencies: [.product(name: "Textual", package: "textual"), .product(name: "MarkdownEngine", package: "swift-markdown-engine"), .product(name: "CodeEditSourceEditor", package: "CodeEditSourceEditor")]),
        .target(name: "PalmCore", dependencies: [
            .product(name: "GRDB", package: "GRDB.swift"),
            .product(name: "FSRS", package: "swift-fsrs"),
            .product(name: "OpenAI", package: "OpenAI")
        ], resources: [.copy("Resources")]),
        .executableTarget(name: "Palm", dependencies: [
            "PalmCore", .product(name: "Textual", package: "textual"),
            .product(name: "MarkdownEngine", package: "swift-markdown-engine"),
            .product(name: "CodeEditSourceEditor", package: "CodeEditSourceEditor")
        ]),
        .testTarget(name: "PalmCoreTests", dependencies: ["PalmCore"]),
        .testTarget(name: "PalmUITests", dependencies: ["Palm"])
    ],
    swiftLanguageModes: [.v5]
)
