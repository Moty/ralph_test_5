//
//  FoodItemCard.swift
//  NutritionAIApp
//

import SwiftUI
import NutritionAI

struct FoodItemCard: View {
    let foodItem: FoodItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Food name and portion
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(foodItem.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(foodItem.portion)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Confidence score with color coding
                ConfidenceBadge(confidence: foodItem.confidence)
            }
            
            Divider()
            
            // Individual nutrition values
            HStack(spacing: 16) {
                NutritionValueView(label: "Cal", value: Int(foodItem.nutrition.calories))
                NutritionValueView(label: "Protein", value: Int(foodItem.nutrition.protein), unit: "g")
                NutritionValueView(label: "Carbs", value: Int(foodItem.nutrition.carbs), unit: "g")
                NutritionValueView(label: "Fat", value: Int(foodItem.nutrition.fat), unit: "g")
            }
            .font(.caption)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct ConfidenceBadge: View {
    let confidence: Double
    
    var confidenceColor: Color {
        if confidence >= 0.8 {
            return .green
        } else if confidence >= 0.5 {
            return .orange
        } else {
            return .red
        }
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(confidenceColor)
                .frame(width: 8, height: 8)
            Text("\(Int(confidence * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(8)
    }
}

struct NutritionValueView: View {
    let label: String
    let value: Int
    var unit: String = ""
    
    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .foregroundColor(.secondary)
            Text("\(value)\(unit)")
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    VStack(spacing: 16) {
        FoodItemCard(foodItem: FoodItem(
            name: "Grilled Chicken Breast",
            portion: "6 oz (170g)",
            nutrition: NutritionData(
                calories: 280,
                protein: 53,
                carbs: 0,
                fat: 6
            ),
            confidence: 0.92
        ))
        
        FoodItemCard(foodItem: FoodItem(
            name: "Brown Rice",
            portion: "1 cup (195g)",
            nutrition: NutritionData(
                calories: 218,
                protein: 5,
                carbs: 46,
                fat: 2
            ),
            confidence: 0.65
        ))
        
        FoodItemCard(foodItem: FoodItem(
            name: "Mixed Vegetables",
            portion: "1/2 cup (80g)",
            nutrition: NutritionData(
                calories: 40,
                protein: 2,
                carbs: 8,
                fat: 0
            ),
            confidence: 0.45
        ))
    }
    .padding()
}
