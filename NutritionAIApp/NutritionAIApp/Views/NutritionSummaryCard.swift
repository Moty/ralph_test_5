//
//  NutritionSummaryCard.swift
//  NutritionAIApp
//

import SwiftUI
import NutritionAI

struct NutritionSummaryCard: View {
    let nutrition: NutritionData
    
    var body: some View {
        VStack(spacing: 16) {
            // Total Calories - Prominently displayed
            VStack(spacing: 4) {
                Text("Total Calories")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text("\(Int(nutrition.calories))")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.primary)
            }
            
            Divider()
            
            // Macros in grams
            HStack(spacing: 20) {
                MacroView(name: "Protein", value: nutrition.protein, color: .blue)
                MacroView(name: "Carbs", value: nutrition.carbs, color: .orange)
                MacroView(name: "Fat", value: nutrition.fat, color: .purple)
            }
            
            // Macro percentages
            let percentages = nutrition.macroPercentages
            HStack(spacing: 12) {
                PercentageLabel(name: "P", percentage: percentages.protein, color: .blue)
                PercentageLabel(name: "C", percentage: percentages.carbs, color: .orange)
                PercentageLabel(name: "F", percentage: percentages.fat, color: .purple)
            }
            .font(.caption)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct MacroView: View {
    let name: String
    let value: Double
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(name)
                .font(.caption)
                .foregroundColor(.secondary)
            Text("\(Int(value))g")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }
}

struct PercentageLabel: View {
    let name: String
    let percentage: Double
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Text(name)
                .fontWeight(.semibold)
                .foregroundColor(color)
            Text("\(Int(percentage))%")
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    NutritionSummaryCard(nutrition: NutritionData(
        calories: 650,
        protein: 35,
        carbs: 75,
        fat: 20
    ))
    .padding()
}
