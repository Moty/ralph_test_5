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
    let timestamp: Date
    
    enum CodingKeys: String, CodingKey {
        case foods, totals, timestamp
    }
    
    init(foods: [FoodItem], totals: NutritionData, timestamp: Date) {
        self.foods = foods
        self.totals = totals
        self.timestamp = timestamp
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        foods = try container.decode([FoodItem].self, forKey: .foods)
        totals = try container.decode(NutritionData.self, forKey: .totals)
        
        // Try to decode as Date first, then fall back to String
        if let date = try? container.decode(Date.self, forKey: .timestamp) {
            timestamp = date
        } else if let dateString = try? container.decode(String.self, forKey: .timestamp) {
            let formatter = ISO8601DateFormatter()
            timestamp = formatter.date(from: dateString) ?? Date()
        } else {
            timestamp = Date()
        }
    }
}
