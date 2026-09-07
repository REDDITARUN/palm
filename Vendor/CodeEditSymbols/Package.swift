// swift-tools-version: 5.9
import PackageDescription

// Satisfies an unused transitive module import without redistributing upstream assets.
let package = Package(
    name: "CodeEditSymbols",
    platforms: [.macOS(.v12)],
    products: [.library(name: "CodeEditSymbols", targets: ["CodeEditSymbols"])],
    targets: [.target(name: "CodeEditSymbols")]
)
