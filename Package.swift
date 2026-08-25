// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DesktopCat",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "DesktopCat", targets: ["DesktopCat"])
    ],
    targets: [
        .executableTarget(name: "DesktopCat"),
        .testTarget(name: "DesktopCatTests", dependencies: ["DesktopCat"])
    ],
    swiftLanguageModes: [.v6]
)
