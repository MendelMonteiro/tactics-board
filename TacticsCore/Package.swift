// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TacticsCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "TacticsCore", targets: ["TacticsCore"]),
    ],
    targets: [
        .target(name: "TacticsCore"),
        .testTarget(name: "TacticsCoreTests", dependencies: ["TacticsCore"]),
    ]
)
