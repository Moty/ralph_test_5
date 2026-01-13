//
//  HistoryItemCard.swift
//  NutritionAIApp
//

import SwiftUI
import NutritionAI

struct HistoryItemCard: View {
    let analysis: MealAnalysis
    let thumbnail: UIImage?
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: analysis.timestamp)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail or placeholder
            Group {
                if let thumbnail = thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Image(systemName: "fork.knife")
                        .font(.title2)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(width: 60, height: 60)
            .background(Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 4) {
                // Total calories
                Text("\(Int(analysis.totals.calories)) cal")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                // Food item count
                Text("\(analysis.foods.count) item\(analysis.foods.count == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Timestamp
                Text(formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Chevron indicator
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

#Preview {
    VStack(spacing: 12) {
        HistoryItemCard(
            analysis: MealAnalysis(
                foods: [
                    FoodItem(
                        name: "Grilled Chicken",
                        portion: "6 oz",
                        nutrition: NutritionData(calories: 280, protein: 53, carbs: 0, fat: 6),
                        confidence: 0.92
                    )
                ],
                totals: NutritionData(calories: 650, protein: 55, carbs: 60, fat: 15),
                timestamp: Date()
            ),
            thumbnail: nil
        )
        
        HistoryItemCard(
            analysis: MealAnalysis(
                foods: [
                    FoodItem(
                        name: "Pasta",
                        portion: "2 cups",
                        nutrition: NutritionData(calories: 400, protein: 14, carbs: 80, fat: 2),
                        confidence: 0.85
                    ),
                    FoodItem(
                        name: "Salad",
                        portion: "1 cup",
                        nutrition: NutritionData(calories: 50, protein: 2, carbs: 10, fat: 1),
                        confidence: 0.75
                    )
                ],
                totals: NutritionData(calories: 450, protein: 16, carbs: 90, fat: 3),
                timestamp: Date().addingTimeInterval(-3600)
            ),
            thumbnail: UIImage(systemName: "photo")
        )
    }
    .padding()
}
