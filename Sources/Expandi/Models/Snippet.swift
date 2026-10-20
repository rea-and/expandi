import Foundation

public enum SnippetType: String, Codable, CaseIterable, Sendable {
    case plainText = "plain"
    case formatted = "formatted"
    case shellScript = "shell"
    case appleScript = "applescript"
    
    public var displayName: String {
        switch self {
        case .plainText: return "Plain Text"
        case .formatted: return "Rich Text"
        case .shellScript: return "Shell Script"
        case .appleScript: return "AppleScript"
        }
    }
    
    public var iconName: String {
        switch self {
        case .plainText: return "text.alignleft"
        case .formatted: return "text.badge.star"
        case .shellScript: return "terminal"
        case .appleScript: return "applescript"
        }
    }
}

public enum DelimiterMode: Codable, Equatable, Hashable, Sendable {
    case immediate
    case afterDelimiter(keepDelimiter: Bool)
    
    enum CodingKeys: CodingKey {
        case type
        case keepDelimiter
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        if type == "immediate" {
            self = .immediate
        } else {
            let keep = try container.decodeIfPresent(Bool.self, forKey: .keepDelimiter) ?? true
            self = .afterDelimiter(keepDelimiter: keep)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .immediate:
            try container.encode("immediate", forKey: .type)
        case .afterDelimiter(let keep):
            try container.encode("afterDelimiter", forKey: .type)
            try container.encode(keep, forKey: .keepDelimiter)
        }
    }
    
    public var isImmediate: Bool {
        if case .immediate = self { return true }
        return false
    }
}

public enum CaseSensitivity: String, Codable, CaseIterable, Sendable {
    case adaptCase = "adapt"
    case exactMatch = "exact"
    case ignoreCase = "ignore"
    
    public var displayName: String {
        switch self {
        case .adaptCase: return "Adapt to Typed Case"
        case .exactMatch: return "Exact Match Only"
        case .ignoreCase: return "Ignore Case"
        }
    }
    
    public var summary: String {
        switch self {
        case .adaptCase: return "Typing 'abbr' -> 'text', 'Abbr' -> 'Text', 'ABBR' -> 'TEXT'"
        case .exactMatch: return "Only matches the exact letter casing typed"
        case .ignoreCase: return "Matches regardless of case and expands as stored"
        }
    }
}

public struct Snippet: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var abbreviation: String
    public var content: String
    public var notes: String
    public var groupId: UUID
    public var tags: [String]
    public var type: SnippetType
    public var delimiterMode: DelimiterMode
    public var caseSensitivity: CaseSensitivity
    public var isFavorite: Bool
    public var isDeleted: Bool
    public var createdAt: Date
    public var updatedAt: Date
    public var lastUsedAt: Date?
    public var usageCount: Int
    
    public init(
        id: UUID = UUID(),
        title: String,
        abbreviation: String,
        content: String,
        notes: String = "",
        groupId: UUID,
        tags: [String] = [],
        type: SnippetType = .plainText,
        delimiterMode: DelimiterMode = .immediate,
        caseSensitivity: CaseSensitivity = .adaptCase,
        isFavorite: Bool = false,
        isDeleted: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        lastUsedAt: Date? = nil,
        usageCount: Int = 0
    ) {
        self.id = id
        self.title = title
        self.abbreviation = abbreviation
        self.content = content
        self.notes = notes
        self.groupId = groupId
        self.tags = tags
        self.type = type
        self.delimiterMode = delimiterMode
        self.caseSensitivity = caseSensitivity
        self.isFavorite = isFavorite
        self.isDeleted = isDeleted
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastUsedAt = lastUsedAt
        self.usageCount = usageCount
    }
    
    /// Checks whether this snippet contains any dynamic fill-in fields that require user input
    public var hasFillIns: Bool {
        content.contains("{{fill:") ||
        content.contains("{{multiline:") ||
        content.contains("{{datepicker:") ||
        content.contains("{{choice:") ||
        content.contains("{{opt:")
    }
    
    /// Returns the trigger abbreviation including group prefix if any
    public func effectiveAbbreviation(withGroupPrefix prefix: String) -> String {
        if abbreviation.hasPrefix(prefix) {
            return abbreviation
        }
        return prefix + abbreviation
    }
}
