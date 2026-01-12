import Foundation

public struct MealAnalysis: Codable {
    public let foods: [FoodItem]
    public let totals: NutritionData
    public let timestamp: Date
    
    public init(foods: [FoodItem], totals: NutritionData, timestamp: Date) {
        self.foods = foods
        self.totals = totals
        self.timestamp = timestamp
    }
}
