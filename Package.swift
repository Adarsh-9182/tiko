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
        // App screens drawn in code with the exact position of every element,
        // shared by the checks and the benchmark.
        .target(name: "TikoFixtures", path: "Sources/TikoFixtures"),
        // `swift run TikoCheck` runs offline checks; `--live` also asks Gemini real questions.
        .executableTarget(name: "TikoCheck", dependencies: ["TikoCore", "TikoFixtures"], path: "Sources/TikoCheck"),
        // `swift run TikoBenchmark` measures pointing accuracy and writes benchmarks/RESULTS.md.
        .executableTarget(name: "TikoBenchmark", dependencies: ["TikoCore", "TikoFixtures"], path: "Sources/TikoBenchmark")
    ]
)
