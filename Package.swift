// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "KetcherApp",
    platforms: [.macOS(.v13)],
    targets: [.executableTarget(name: "KetcherApp", path: "Sources/KetcherApp")]
)
