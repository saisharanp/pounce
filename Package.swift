// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DesktopCat",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "DesktopCatCore", targets: ["DesktopCatCore"]),
        .executable(name: "DesktopCat", targets: ["DesktopCat"]),
        .executable(name: "DesktopCatChecks", targets: ["DesktopCatChecks"])
    ],
    targets: [
        .target(name: "DesktopCatCore"),
        .executableTarget(name: "DesktopCat", dependencies: ["DesktopCatCore"]),
        .executableTarget(name: "DesktopCatChecks", dependencies: ["DesktopCatCore"])
    ],
    swiftLanguageModes: [.v6]
)
