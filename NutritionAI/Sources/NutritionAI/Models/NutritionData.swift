import Foundation

public struct NutritionData: Codable {
    public let calories: Double
    public let protein: Double
    public let carbs: Double
    public let fat: Double
    
    public init(calories: Double, protein: Double, carbs: Double, fat: Double) {
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
    }
    
    var macroPercentages: MacroPercentages {
        let totalCalories = (protein * 4) + (carbs * 4) + (fat * 9)
        guard totalCalories > 0 else {
            return MacroPercentages(protein: 0, carbs: 0, fat: 0)
        }
        
        return MacroPercentages(
            protein: (protein * 4) / totalCalories * 100,
            carbs: (carbs * 4) / totalCalories * 100,
            fat: (fat * 9) / totalCalories * 100
        )
    }
    
    public struct MacroPercentages {
        public let protein: Double
        public let carbs: Double
        public let fat: Double
    }
}
