import SwiftUI
#if canImport(UIKit)
import UIKit

struct NutritionResultView: View {
    let analysis: MealAnalysis?
    let error: String?
    let isLoading: Bool
    let onDismiss: () -> Void
    
    var body: some View {
        VStack {
            // Header with dismiss button
            HStack {
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
                .padding()
            }
            
            ScrollView {
                VStack(spacing: 20) {
                    if isLoading {
                        // Loading indicator
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Analyzing your food...")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 100)
                    } else if let errorMessage = error {
                        // Error message
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.orange)
                            Text("Analysis Failed")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text(errorMessage)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            Button("Back to Camera") {
                                onDismiss()
                            }
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .padding(.top, 100)
                    } else if let mealAnalysis = analysis {
                        // Nutrition results
                        VStack(spacing: 24) {
                            // Total nutrition summary
                            VStack(spacing: 12) {
                                Text("Total Nutrition")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                HStack(spacing: 20) {
                                    NutritionSummaryCard(
                                        label: "Calories",
                                        value: String(format: "%.0f", mealAnalysis.totals.calories),
                                        unit: "kcal"
                                    )
                                    
                                    NutritionSummaryCard(
                                        label: "Protein",
                                        value: String(format: "%.1f", mealAnalysis.totals.protein),
                                        unit: "g"
                                    )
                                }
                                
                                HStack(spacing: 20) {
                                    NutritionSummaryCard(
                                        label: "Carbs",
                                        value: String(format: "%.1f", mealAnalysis.totals.carbs),
                                        unit: "g"
                                    )
                                    
                                    NutritionSummaryCard(
                                        label: "Fat",
                                        value: String(format: "%.1f", mealAnalysis.totals.fat),
                                        unit: "g"
                                    )
                                }
                            }
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                            
                            // Individual food items
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Identified Foods")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                
                                ForEach(Array(mealAnalysis.foods.enumerated()), id: \.offset) { index, food in
                                    FoodItemCard(food: food)
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
        }
    }
}

struct NutritionSummaryCard: View {
    let label: String
    let value: String
    let unit: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(unit)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white)
        .cornerRadius(8)
        .shadow(radius: 2)
    }
}

struct FoodItemCard: View {
    let food: FoodItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Food name and confidence
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(food.name)
                        .font(.headline)
                    Text(food.portion)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Confidence indicator
                ConfidenceBadge(confidence: food.confidence)
            }
            
            // Nutrition breakdown
            HStack(spacing: 16) {
                NutritionDetail(label: "Cal", value: String(format: "%.0f", food.nutrition.calories))
                NutritionDetail(label: "Protein", value: String(format: "%.1fg", food.nutrition.protein))
                NutritionDetail(label: "Carbs", value: String(format: "%.1fg", food.nutrition.carbs))
                NutritionDetail(label: "Fat", value: String(format: "%.1fg", food.nutrition.fat))
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

struct ConfidenceBadge: View {
    let confidence: Double
    
    var color: Color {
        if confidence >= 0.8 { return .green }
        if confidence >= 0.6 { return .orange }
        return .red
    }
    
    var body: some View {
        Text("\(Int(confidence * 100))%")
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(6)
    }
}

struct NutritionDetail: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

#else

// Fallback for non-iOS platforms
struct NutritionResultView: View {
    let analysis: MealAnalysis?
    let error: String?
    let isLoading: Bool
    let onDismiss: () -> Void
    
    var body: some View {
        Text("Results view is only available on iOS")
            .padding()
    }
}

#endif
