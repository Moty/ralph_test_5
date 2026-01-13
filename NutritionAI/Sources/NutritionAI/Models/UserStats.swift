import Foundation

public struct UserStats: Codable {
    public let today: PeriodStats
    public let week: PeriodStats
    public let allTime: PeriodStats
}

public struct PeriodStats: Codable {
    public let count: Int
    public let avgCalories: Int
    public let totalCalories: Int
    public let totalProtein: Int
    public let totalCarbs: Int
    public let totalFat: Int
}
