import Foundation

public struct SnippetGroup: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var iconName: String
    public var colorHex: String
    public var prefix: String
    public var isEnabled: Bool
    public var excludedApps: [String]
    public var orderIndex: Int
    public var createdAt: Date
    
    public init(
        id: UUID = UUID(),
        name: String,
        iconName: String = "folder.fill",
        colorHex: String = "#0A84FF",
        prefix: String = "",
        isEnabled: Bool = true,
        excludedApps: [String] = [],
        orderIndex: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.colorHex = colorHex
        self.prefix = prefix
        self.isEnabled = isEnabled
        self.excludedApps = excludedApps
        self.orderIndex = orderIndex
        self.createdAt = createdAt
    }
    
    public static let defaultGroups: [SnippetGroup] = [
        SnippetGroup(name: "Dates & Times", iconName: "calendar", colorHex: "#FF9F0A", prefix: ";", orderIndex: 0),
        SnippetGroup(name: "Personal & Contact", iconName: "person.crop.circle.fill", colorHex: "#30D158", prefix: ";", orderIndex: 1),
        SnippetGroup(name: "Email & Communication", iconName: "envelope.fill", colorHex: "#0A84FF", prefix: ";", orderIndex: 2),
        SnippetGroup(name: "Code & Development", iconName: "curlybraces", colorHex: "#BF5AF2", prefix: ";", orderIndex: 3),
        SnippetGroup(name: "Customer Support", iconName: "bubble.left.and.bubble.right.fill", colorHex: "#FF375F", prefix: ";", orderIndex: 4),
        SnippetGroup(name: "Symbols & Emojis", iconName: "face.smiling.fill", colorHex: "#FFD60A", prefix: ";", orderIndex: 5)
    ]
}
