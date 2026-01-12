import Foundation

struct NutritionData: Codable {
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    
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
    
    struct MacroPercentages {
        let protein: Double
        let carbs: Double
        let fat: Double
    }
}
