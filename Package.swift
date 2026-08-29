// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Pounce",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PounceCore", targets: ["PounceCore"]),
        .executable(name: "Pounce", targets: ["Pounce"]),
        .executable(name: "PounceChecks", targets: ["PounceChecks"])
    ],
    targets: [
        .target(name: "PounceCore"),
        .executableTarget(name: "Pounce", dependencies: ["PounceCore"], path: "Sources/Pounce"),
        .executableTarget(name: "PounceChecks", dependencies: ["PounceCore"])
    ],
    swiftLanguageModes: [.v6]
)
