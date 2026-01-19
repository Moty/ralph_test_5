import Foundation

public struct FoodItem: Codable {
    public let name: String
    public let portion: String
    public let nutrition: NutritionData
    public let confidence: Double
    
    public init(name: String, portion: String, nutrition: NutritionData, confidence: Double) {
        self.name = name
        self.portion = portion
        self.nutrition = nutrition
        self.confidence = confidence
    }
}
