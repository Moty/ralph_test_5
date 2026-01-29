import Foundation

// MARK: - Diet Template
public struct DietTemplate: Codable, Identifiable {
    public let dietType: String
    public let name: String
    public let description: String
    public let proteinRatio: Double
    public let carbsRatio: Double
    public let fatRatio: Double
    public let baselineCalories: Int
    public let baselineProtein: Int
    public let baselineCarbs: Int
    public let baselineFat: Int
    public let fiberMinimum: Int?
    public let sugarMaximum: Int?
    
    // Extra fields from backend (optional)
    public let carbsTolerance: Int?
    public let proteinTolerance: Int?
    public let fatTolerance: Int?

    public var id: String { dietType }
    
    enum CodingKeys: String, CodingKey {
        case dietType, name, description
        case proteinRatio, carbsRatio, fatRatio
        case baselineCalories, baselineProtein, baselineCarbs, baselineFat
        case fiberMinimum, sugarMaximum
        case carbsTolerance, proteinTolerance, fatTolerance
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        dietType = try container.decode(String.self, forKey: .dietType)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        
        // Handle ratios as either Int or Double
        if let intVal = try? container.decode(Int.self, forKey: .proteinRatio) {
            proteinRatio = Double(intVal)
        } else {
            proteinRatio = try container.decode(Double.self, forKey: .proteinRatio)
        }
        
        if let intVal = try? container.decode(Int.self, forKey: .carbsRatio) {
            carbsRatio = Double(intVal)
        } else {
            carbsRatio = try container.decode(Double.self, forKey: .carbsRatio)
        }
        
        if let intVal = try? container.decode(Int.self, forKey: .fatRatio) {
            fatRatio = Double(intVal)
        } else {
            fatRatio = try container.decode(Double.self, forKey: .fatRatio)
        }
        
        baselineCalories = try container.decode(Int.self, forKey: .baselineCalories)
        baselineProtein = try container.decode(Int.self, forKey: .baselineProtein)
        baselineCarbs = try container.decode(Int.self, forKey: .baselineCarbs)
        baselineFat = try container.decode(Int.self, forKey: .baselineFat)
        fiberMinimum = try container.decodeIfPresent(Int.self, forKey: .fiberMinimum)
        sugarMaximum = try container.decodeIfPresent(Int.self, forKey: .sugarMaximum)
        carbsTolerance = try container.decodeIfPresent(Int.self, forKey: .carbsTolerance)
        proteinTolerance = try container.decodeIfPresent(Int.self, forKey: .proteinTolerance)
        fatTolerance = try container.decodeIfPresent(Int.self, forKey: .fatTolerance)
    }
}

// MARK: - User Profile
public struct UserProfile: Codable {
    public let id: String
    public let userId: String
    public let dietType: String
    public let dailyCalorieGoal: Int
    public let dailyProteinGoal: Int
    public let dailyCarbsGoal: Int
    public let dailyFatGoal: Int
    public let dailyFiberGoal: Int?
    public let dailySugarLimit: Int?
    public let weight: Double?
    public let height: Double?
    public let age: Int?
    public let gender: String?
    public let activityLevel: String?
    public let dietaryRestrictions: [String]?
}

// MARK: - Profile Response
public struct ProfileResponse: Codable {
    public let profile: UserProfile
    public let template: ProfileTemplateInfo
}

public struct ProfileTemplateInfo: Codable {
    public let name: String
    public let description: String
    public let proteinRatio: Double?
    public let carbsRatio: Double?
    public let fatRatio: Double?
}

// MARK: - Diet Templates Response
public struct DietTemplatesResponse: Codable {
    public let templates: [DietTemplate]
}

// MARK: - Calculate Goals Request/Response
public struct CalculateGoalsRequest: Codable {
    public let weight: Double
    public let height: Double
    public let age: Int
    public let gender: String
    public let activityLevel: String
    public let dietType: String
}

public struct CalculateGoalsResponse: Codable {
    public let goals: CalculatedGoals
    public let template: ProfileTemplateInfo
}

public struct CalculatedGoals: Codable {
    public let calories: Int
    public let protein: Int
    public let carbs: Int
    public let fat: Int
}

// MARK: - Profile Update Request
public struct ProfileUpdateRequest: Codable {
    public var dietType: String?
    public var dailyCalorieGoal: Int?
    public var dailyProteinGoal: Int?
    public var dailyCarbsGoal: Int?
    public var dailyFatGoal: Int?
    public var dailyFiberGoal: Int?
    public var dailySugarLimit: Int?
    public var weight: Double?
    public var height: Double?
    public var age: Int?
    public var gender: String?
    public var activityLevel: String?
    public var dietaryRestrictions: [String]?

    public init() {}
}
