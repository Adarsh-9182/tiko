// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Tiko",
    platforms: [.macOS(.v14)],
    targets: [
        // Logic with no UI and no permissions (the Gemini client, the prompt,
        // settings), so it can be checked from the command line.
        .target(name: "TikoCore", path: "Sources/TikoCore"),
        .executableTarget(name: "Tiko", dependencies: ["TikoCore"], path: "Sources/Tiko"),
        // `swift run TikoCheck` runs offline checks; `--live` also asks Gemini a real question.
        .executableTarget(name: "TikoCheck", dependencies: ["TikoCore"], path: "Sources/TikoCheck")
    ]
)
