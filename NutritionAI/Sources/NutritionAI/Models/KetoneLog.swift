import Foundation

// MARK: - Ketone Log
public struct KetoneLog: Codable, Identifiable {
    public let id: String
    public let ketoneLevel: Double
    public let measurementType: String
    public let notes: String?
    public let timestamp: Date

    enum CodingKeys: String, CodingKey {
        case id, ketoneLevel, measurementType, notes, timestamp
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        ketoneLevel = try container.decode(Double.self, forKey: .ketoneLevel)
        measurementType = try container.decode(String.self, forKey: .measurementType)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)

        // Handle timestamp as either Date or String
        if let date = try? container.decode(Date.self, forKey: .timestamp) {
            timestamp = date
        } else if let dateString = try? container.decode(String.self, forKey: .timestamp) {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: dateString) {
                timestamp = date
            } else {
                formatter.formatOptions = [.withInternetDateTime]
                timestamp = formatter.date(from: dateString) ?? Date()
            }
        } else {
            timestamp = Date()
        }
    }
}

// MARK: - Ketosis Status
public struct KetosisStatus: Codable {
    public let isInKetosis: Bool
    public let level: String
    public let message: String
}

// MARK: - Ketone Log Response
public struct KetoneLogResponse: Codable {
    public let log: KetoneLog
    public let ketosisStatus: KetosisStatus
}

// MARK: - Ketone Stats
public struct KetoneStats: Codable {
    public let avgLevel: Double
    public let minLevel: Double
    public let maxLevel: Double
    public let daysInKetosis: Int
    public let totalDays: Int
    public let ketosisRate: Double
    public let trend: String
}

// MARK: - Ketone Recent Response
public struct KetoneRecentResponse: Codable {
    public let logs: [KetoneLog]
    public let stats: KetoneStats
}

// MARK: - Ketone Latest Response
public struct KetoneLatestResponse: Codable {
    public let log: KetoneLog?
    public let ketosisStatus: KetosisStatus?
}
