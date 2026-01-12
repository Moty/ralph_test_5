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
            path: "Sources")
    ]
)
