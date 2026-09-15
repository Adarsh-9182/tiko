// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Tiko",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Tiko", path: "Sources/Tiko")
    ]
)
