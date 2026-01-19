import SwiftUI
#if canImport(UIKit)
import UIKit

struct NutritionResultView: View {
    let analysis: MealAnalysis?
    let error: String?
    let isLoading: Bool
    let onDismiss: (() -> Void)?
    
    // Initializer for standalone use (from history)
    init(analysis: MealAnalysis) {
        self.analysis = analysis
        self.error = nil
        self.isLoading = false
        self.onDismiss = nil
    }
    
    // Initializer for camera flow
    init(analysis: MealAnalysis?, error: String?, isLoading: Bool, onDismiss: @escaping () -> Void) {
        self.analysis = analysis
        self.error = error
        self.isLoading = isLoading
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        ZStack {
            AppGradients.background
                .ignoresSafeArea()
            
            VStack {
                // Header with dismiss button (only show if onDismiss provided)
                if let dismissAction = onDismiss {
                    HStack {
                        Spacer()
                        Button(action: dismissAction) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title)
                                .foregroundStyle(AppGradients.primary)
                        }
                        .padding()
                    }
                }
                
                ScrollView {
                    VStack(spacing: 24) {
                        if isLoading {
                            // Loading indicator
                            VStack(spacing: 20) {
                                ZStack {
                                    Circle()
                                        .fill(AppGradients.primary.opacity(0.2))
                                        .frame(width: 100, height: 100)
                                    
                                    ProgressView()
                                        .scaleEffect(1.8)
                                }
                                
                                Text("Analyzing your food...")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                
                                Text("Using AI to identify ingredients")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(40)
                            .glassMorphism()
                            .padding(.top, 60)
                            .padding(.horizontal)
                        } else if let errorMessage = error {
                            // Error message
                            VStack(spacing: 20) {
                                ZStack {
                                    Circle()
                                        .fill(Color.orange.opacity(0.2))
                                        .frame(width: 100, height: 100)
                                    
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 45))
                                        .foregroundColor(.orange)
                                }
                                
                                Text("Analysis Failed")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Text(errorMessage)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                
                                if let dismissAction = onDismiss {
                                    Button(action: dismissAction) {
                                        HStack {
                                            Image(systemName: "arrow.clockwise")
                                            Text("Try Again")
                                        }
                                        .fontWeight(.semibold)
                                    }
                                    .buttonStyle(GradientButtonStyle())
                                }
                            }
                            .padding(40)
                            .glassMorphism()
                            .padding(.top, 40)
                            .padding(.horizontal)
                        } else if let mealAnalysis = analysis {
                            // Nutrition results
                            VStack(spacing: 24) {
                                // Total nutrition summary
                                VStack(spacing: 16) {
                                    HStack {
                                        Image(systemName: "chart.pie.fill")
                                            .foregroundStyle(AppGradients.primary)
                                        Text("Total Nutrition")
                                            .font(.title2)
                                            .fontWeight(.bold)
                                    }
                                    
                                    HStack(spacing: 14) {
                                        NutritionSummaryCard(
                                            label: "Calories",
                                            value: String(format: "%.0f", mealAnalysis.totals.calories),
                                            unit: "kcal",
                                            color: AppColors.calories,
                                            icon: "flame.fill"
                                        )
                                        
                                        NutritionSummaryCard(
                                            label: "Protein",
                                            value: String(format: "%.1f", mealAnalysis.totals.protein),
                                            unit: "g",
                                            color: AppColors.protein,
                                            icon: "bolt.fill"
                                        )
                                    }
                                    
                                    HStack(spacing: 14) {
                                        NutritionSummaryCard(
                                            label: "Carbs",
                                            value: String(format: "%.1f", mealAnalysis.totals.carbs),
                                            unit: "g",
                                            color: AppColors.carbs,
                                            icon: "leaf.fill"
                                        )
                                        
                                        NutritionSummaryCard(
                                            label: "Fat",
                                            value: String(format: "%.1f", mealAnalysis.totals.fat),
                                            unit: "g",
                                            color: AppColors.fat,
                                            icon: "drop.fill"
                                        )
                                    }
                                }
                                .padding(20)
                                .background(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .fill(Color(.systemBackground))
                                        .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
                                )
                                
                                // Individual food items
                                VStack(alignment: .leading, spacing: 16) {
                                    HStack {
                                        Image(systemName: "list.bullet.circle.fill")
                                            .foregroundStyle(AppGradients.primary)
                                        Text("Identified Foods")
                                            .font(.title3)
                                            .fontWeight(.bold)
                                    }
                                    
                                    ForEach(Array(mealAnalysis.foods.enumerated()), id: \.offset) { index, food in
                                        FoodItemCard(food: food, index: index)
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
}

struct NutritionSummaryCard: View {
    let label: String
    let value: String
    let unit: String
    var color: Color = AppColors.primaryGradientStart
    var icon: String? = nil
    
    var body: some View {
        VStack(spacing: 8) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(color)
            }
            
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            HStack(alignment: .bottom, spacing: 2) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(color)
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 3)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(color.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

struct FoodItemCard: View {
    @Environment(\.colorScheme) var colorScheme
    let food: FoodItem
    var index: Int = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Food name and confidence
            HStack {
                ZStack {
                    Circle()
                        .fill(AppGradients.cardGradient(at: index))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "leaf.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 18))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(food.name)
                        .font(.headline)
                        .fontWeight(.bold)
                    Text(food.portion)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Confidence indicator
                ConfidenceBadge(confidence: food.confidence)
            }
            
            // Nutrition breakdown
            HStack(spacing: 12) {
                NutritionDetail(label: "Cal", value: String(format: "%.0f", food.nutrition.calories), color: AppColors.calories)
                NutritionDetail(label: "Protein", value: String(format: "%.1fg", food.nutrition.protein), color: AppColors.protein)
                NutritionDetail(label: "Carbs", value: String(format: "%.1fg", food.nutrition.carbs), color: AppColors.carbs)
                NutritionDetail(label: "Fat", value: String(format: "%.1fg", food.nutrition.fat), color: AppColors.fat)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppColors.cardBg(for: colorScheme))
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
        )
    }
}

struct ConfidenceBadge: View {
    let confidence: Double
    
    var color: Color {
        if confidence >= 0.8 { return AppColors.primaryGradientStart }
        if confidence >= 0.6 { return AppColors.accentSecondary }
        return AppColors.accent
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: confidence >= 0.8 ? "checkmark.circle.fill" : confidence >= 0.6 ? "exclamationmark.circle.fill" : "questionmark.circle.fill")
                .font(.caption)
            Text("\(Int(confidence * 100))%")
                .font(.caption)
                .fontWeight(.bold)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(color.opacity(0.15))
        )
        .foregroundColor(color)
    }
}

struct NutritionDetail: View {
    let label: String
    let value: String
    var color: Color = .primary
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.08))
        )
    }
}

#else

// Fallback for non-iOS platforms
struct NutritionResultView: View {
    let analysis: MealAnalysis?
    let error: String?
    let isLoading: Bool
    let onDismiss: (() -> Void)?
    
    // Initializer for standalone use (from history)
    init(analysis: MealAnalysis) {
        self.analysis = analysis
        self.error = nil
        self.isLoading = false
        self.onDismiss = nil
    }
    
    // Initializer for camera flow
    init(analysis: MealAnalysis?, error: String?, isLoading: Bool, onDismiss: @escaping () -> Void) {
        self.analysis = analysis
        self.error = error
        self.isLoading = isLoading
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        Text("Results view is only available on iOS")
            .padding()
    }
}

#endif
