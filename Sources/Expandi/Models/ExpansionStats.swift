import Foundation

public struct ExpansionStats: Codable, Sendable {
    public var totalExpansions: Int
    public var totalKeystrokesSaved: Int
    public var estimatedTimeSavedMinutes: Double
    public var dailyExpansions: [String: Int]
    public var snippetUsage: [String: Int]
    public var groupUsage: [String: Int]
    
    public init(
        totalExpansions: Int = 0,
        totalKeystrokesSaved: Int = 0,
        estimatedTimeSavedMinutes: Double = 0.0,
        dailyExpansions: [String: Int] = [:],
        snippetUsage: [String: Int] = [:],
        groupUsage: [String: Int] = [:]
    ) {
        self.totalExpansions = totalExpansions
        self.totalKeystrokesSaved = totalKeystrokesSaved
        self.estimatedTimeSavedMinutes = estimatedTimeSavedMinutes
        self.dailyExpansions = dailyExpansions
        self.snippetUsage = snippetUsage
        self.groupUsage = groupUsage
    }
    
    public mutating func recordExpansion(
        snippetId: UUID,
        groupId: UUID,
        abbreviationLength: Int,
        expandedLength: Int
    ) {
        totalExpansions += 1
        let saved = max(0, expandedLength - abbreviationLength)
        totalKeystrokesSaved += saved
        // Standard average typing speed: ~40 WPM (~200 characters per minute)
        estimatedTimeSavedMinutes += Double(saved) / 200.0
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateKey = formatter.string(from: Date())
        dailyExpansions[dateKey, default: 0] += 1
        
        snippetUsage[snippetId.uuidString, default: 0] += 1
        groupUsage[groupId.uuidString, default: 0] += 1
    }
}
