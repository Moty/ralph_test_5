import Foundation

public struct UserStats: Decodable {
    public let today: PeriodStats
    public let week: PeriodStats
    public let allTime: PeriodStats
    public let hasProfile: Bool?
    public let dietInfo: DietInfo?

    enum CodingKeys: String, CodingKey {
        case today, week, allTime, hasProfile, dietInfo
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        today = try container.decode(PeriodStats.self, forKey: .today)
        week = try container.decode(PeriodStats.self, forKey: .week)
        allTime = try container.decode(PeriodStats.self, forKey: .allTime)
        hasProfile = try container.decodeIfPresent(Bool.self, forKey: .hasProfile)
        dietInfo = try container.decodeIfPresent(DietInfo.self, forKey: .dietInfo)
    }
}

public struct PeriodStats: Codable {
    public let count: Int
    public let avgCalories: Int
    public let totalCalories: Int
    public let totalProtein: Int
    public let totalCarbs: Int
    public let totalFat: Int
}
