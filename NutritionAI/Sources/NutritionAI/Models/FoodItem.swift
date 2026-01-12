import Foundation

struct FoodItem: Codable {
    let name: String
    let portion: String
    let nutrition: NutritionData
    let confidence: Double
}
