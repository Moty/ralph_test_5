import Foundation

struct MealAnalysis: Codable {
    let foods: [FoodItem]
    let totals: NutritionData
    let timestamp: Date
}
