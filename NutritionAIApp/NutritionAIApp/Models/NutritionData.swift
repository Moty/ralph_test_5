//
//  NutritionData.swift
//  NutritionAIApp
//

import Foundation

struct NutritionData: Codable {
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    
    var macroPercentages: (protein: Double, carbs: Double, fat: Double) {
        let totalCalories = (protein * 4) + (carbs * 4) + (fat * 9)
        guard totalCalories > 0 else {
            return (0, 0, 0)
        }
        
        let proteinPercent = (protein * 4 / totalCalories) * 100
        let carbsPercent = (carbs * 4 / totalCalories) * 100
        let fatPercent = (fat * 9 / totalCalories) * 100
        
        return (proteinPercent, carbsPercent, fatPercent)
    }
}

struct FoodItem: Codable {
    let name: String
    let portion: String
    let confidence: Double
    let nutrition: NutritionData
}

struct MealAnalysis: Codable {
    let foods: [FoodItem]
    let totals: NutritionData
    let timestamp: String
}
