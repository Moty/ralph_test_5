import Foundation

struct UserStats: Codable {
    let today: PeriodStats
    let week: PeriodStats
    let allTime: PeriodStats
}

struct PeriodStats: Codable {
    let count: Int
    let avgCalories: Int
    let totalCalories: Int
    let totalProtein: Int
    let totalCarbs: Int
    let totalFat: Int
}
