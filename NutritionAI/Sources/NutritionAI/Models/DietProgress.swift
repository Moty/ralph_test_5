import Foundation

// MARK: - Daily Progress
public struct DailyProgress: Codable, Identifiable {
    public var id: String { date }
    public let userId: String?
    public let date: String
    public let totalCalories: Int
    public let totalProtein: Int
    public let totalCarbs: Int
    public let totalFat: Int
    public let totalFiber: Int
    public let totalSugar: Int
    public let goalCalories: Int
    public let goalProtein: Int
    public let goalCarbs: Int
    public let goalFat: Int
    public let goalFiber: Int?
    public let goalSugar: Int?
    public let mealCount: Int
    public let isOnTrack: Bool
    public let netCarbs: Int?
    
    // Compliance fields from backend
    public let carbsCompliance: Double?
    public let proteinCompliance: Double?
    public let fatCompliance: Double?
    
    // Computed compliance score (average of the three)
    public var complianceScore: Double {
        let carbs = carbsCompliance ?? 1.0
        let protein = proteinCompliance ?? 1.0
        let fat = fatCompliance ?? 1.0
        return (carbs + protein + fat) / 3.0
    }
    
    enum CodingKeys: String, CodingKey {
        case userId, date, totalCalories, totalProtein, totalCarbs, totalFat
        case totalFiber, totalSugar, goalCalories, goalProtein, goalCarbs, goalFat
        case goalFiber, goalSugar, mealCount, isOnTrack, netCarbs
        case carbsCompliance, proteinCompliance, fatCompliance
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        userId = try container.decodeIfPresent(String.self, forKey: .userId)
        
        // Handle date as either String or Date
        if let dateString = try? container.decode(String.self, forKey: .date) {
            // If it's an ISO date string, extract just the date part
            if dateString.contains("T") {
                date = String(dateString.prefix(10))
            } else {
                date = dateString
            }
        } else {
            // Fallback to today's date
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            date = formatter.string(from: Date())
        }
        
        totalCalories = try container.decode(Int.self, forKey: .totalCalories)
        totalProtein = try container.decode(Int.self, forKey: .totalProtein)
        totalCarbs = try container.decode(Int.self, forKey: .totalCarbs)
        totalFat = try container.decode(Int.self, forKey: .totalFat)
        totalFiber = try container.decode(Int.self, forKey: .totalFiber)
        totalSugar = try container.decode(Int.self, forKey: .totalSugar)
        goalCalories = try container.decode(Int.self, forKey: .goalCalories)
        goalProtein = try container.decode(Int.self, forKey: .goalProtein)
        goalCarbs = try container.decode(Int.self, forKey: .goalCarbs)
        goalFat = try container.decode(Int.self, forKey: .goalFat)
        goalFiber = try container.decodeIfPresent(Int.self, forKey: .goalFiber)
        goalSugar = try container.decodeIfPresent(Int.self, forKey: .goalSugar)
        mealCount = try container.decode(Int.self, forKey: .mealCount)
        isOnTrack = try container.decode(Bool.self, forKey: .isOnTrack)
        netCarbs = try container.decodeIfPresent(Int.self, forKey: .netCarbs)
        carbsCompliance = try container.decodeIfPresent(Double.self, forKey: .carbsCompliance)
        proteinCompliance = try container.decodeIfPresent(Double.self, forKey: .proteinCompliance)
        fatCompliance = try container.decodeIfPresent(Double.self, forKey: .fatCompliance)
    }
}

// MARK: - Remaining Budget
public struct RemainingBudget: Codable {
    public let calories: Int
    public let protein: Int
    public let carbs: Int
    public let fat: Int
    public let fiber: Int?
    public let sugar: Int?
}

// MARK: - Meal Suggestion
public struct MealSuggestion: Codable {
    public let type: String
    public let description: String
    public let targetCalories: Int
    public let targetProtein: Int
    public let targetCarbs: Int
    public let targetFat: Int
}

// MARK: - Today Progress Response
public struct TodayProgressResponse: Codable {
    public let progress: DailyProgress
    public let remaining: RemainingBudget
    public let suggestions: [String]
    public let dietType: String
    public let template: DietTemplate
}

// MARK: - Weekly Summary
public struct WeeklySummary: Codable, Identifiable {
    public var id: String { weekStart }
    public let weekStart: String
    public let weekEnd: String?
    public let avgCalories: Double
    public let avgProtein: Double
    public let avgCarbs: Double
    public let avgFat: Double
    public let avgFiber: Double?
    public let avgSugar: Double?
    public let totalMeals: Int
    public let daysTracked: Int
    public let complianceRate: Double
    public let bestDay: String?
    public let worstDay: String?
    
    enum CodingKeys: String, CodingKey {
        case weekStart, weekEnd, avgCalories, avgProtein, avgCarbs, avgFat
        case avgFiber, avgSugar, totalMeals, daysTracked, complianceRate
        case bestDay, worstDay
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Handle weekStart as string
        if let ws = try? container.decode(String.self, forKey: .weekStart) {
            weekStart = ws.contains("T") ? String(ws.prefix(10)) : ws
        } else {
            weekStart = ""
        }
        
        // Handle optional weekEnd
        if let we = try? container.decode(String.self, forKey: .weekEnd) {
            weekEnd = we.contains("T") ? String(we.prefix(10)) : we
        } else {
            weekEnd = nil
        }
        
        // Handle numeric types that could be Int or Double
        if let intVal = try? container.decode(Int.self, forKey: .avgCalories) {
            avgCalories = Double(intVal)
        } else {
            avgCalories = try container.decodeIfPresent(Double.self, forKey: .avgCalories) ?? 0
        }
        
        if let intVal = try? container.decode(Int.self, forKey: .avgProtein) {
            avgProtein = Double(intVal)
        } else {
            avgProtein = try container.decodeIfPresent(Double.self, forKey: .avgProtein) ?? 0
        }
        
        if let intVal = try? container.decode(Int.self, forKey: .avgCarbs) {
            avgCarbs = Double(intVal)
        } else {
            avgCarbs = try container.decodeIfPresent(Double.self, forKey: .avgCarbs) ?? 0
        }
        
        if let intVal = try? container.decode(Int.self, forKey: .avgFat) {
            avgFat = Double(intVal)
        } else {
            avgFat = try container.decodeIfPresent(Double.self, forKey: .avgFat) ?? 0
        }
        
        if let intVal = try? container.decode(Int.self, forKey: .avgFiber) {
            avgFiber = Double(intVal)
        } else {
            avgFiber = try container.decodeIfPresent(Double.self, forKey: .avgFiber)
        }
        
        if let intVal = try? container.decode(Int.self, forKey: .avgSugar) {
            avgSugar = Double(intVal)
        } else {
            avgSugar = try container.decodeIfPresent(Double.self, forKey: .avgSugar)
        }
        
        totalMeals = try container.decode(Int.self, forKey: .totalMeals)
        daysTracked = try container.decode(Int.self, forKey: .daysTracked)
        complianceRate = try container.decode(Double.self, forKey: .complianceRate)
        bestDay = try container.decodeIfPresent(String.self, forKey: .bestDay)
        worstDay = try container.decodeIfPresent(String.self, forKey: .worstDay)
    }
}

// MARK: - Week Progress Response
public struct WeekProgressResponse: Codable {
    public let weekStart: String
    public let weekEnd: String
    public let days: [DailyProgress]
    public let summary: WeeklySummary?
    public let dietType: String
}

// MARK: - Monthly Progress Response
public struct MonthlyProgressResponse: Codable {
    public let weeks: [WeeklySummary]
    public let summary: MonthlySummary
    public let dietType: String
}

public struct MonthlySummary: Codable {
    public let totalWeeks: Int
    public let avgComplianceRate: Double
    public let trend: String
}

// MARK: - Diet Info (for UserStats)
public struct DietInfo: Codable {
    public let dietType: String
    public let dietName: String
    public let goals: DietGoals
    public let todayCompliance: TodayCompliance
}

public struct DietGoals: Codable {
    public let dailyCalories: Int
    public let dailyProtein: Int
    public let dailyCarbs: Int
    public let dailyFat: Int
    public let dailyFiber: Int?
    public let dailySugarLimit: Int?
}

public struct TodayCompliance: Codable {
    public let isOnTrack: Bool
    public let carbsCompliance: Double
    public let proteinCompliance: Double
    public let fatCompliance: Double
    public let overallCompliance: Double
    public let issues: [String]
    public let suggestions: [String]
}
