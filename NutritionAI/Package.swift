// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NutritionAI",
    platforms: [
        .macOS(.v12),
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "NutritionAI",
            targets: ["NutritionAI"])
    ],
    targets: [
        .target(
            name: "NutritionAI",
            dependencies: [],
            path: "Sources/NutritionAI",
            swiftSettings: [
                // Remove the @main app entry when building on macOS (e.g., `swift test`) to avoid duplicate `_main`.
                .define("TESTING", .when(platforms: [.macOS]))
            ]
        ),
        .testTarget(
            name: "NutritionAITests",
            dependencies: ["NutritionAI"],
            path: "Tests",
            swiftSettings: [
                // Disable the @main app entry when running tests to avoid duplicate _main symbol
                .define("TESTING")
            ]
        )
    ]
)
