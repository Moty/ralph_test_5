import Foundation

public struct MealAnalysis: Codable {
    public let backendId: String?  // Backend ID for sync operations
    public let foods: [FoodItem]
    public let totals: NutritionData
    public let timestamp: Date
    
    public init(backendId: String? = nil, foods: [FoodItem], totals: NutritionData, timestamp: Date) {
        self.backendId = backendId
        self.foods = foods
        self.totals = totals
        self.timestamp = timestamp
    }
}
