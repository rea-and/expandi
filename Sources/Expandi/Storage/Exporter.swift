import Foundation

public struct ExpandiPackage: Codable, Sendable {
    public let app: String
    public let version: String
    public let exportedAt: Date
    public let groups: [SnippetGroup]
    public let snippets: [Snippet]
    
    public init(groups: [SnippetGroup], snippets: [Snippet]) {
        self.app = "Expandi"
        self.version = "1.0.0"
        self.exportedAt = Date()
        self.groups = groups
        self.snippets = snippets
    }
}

public final class Exporter: Sendable {
    public static let shared = Exporter()
    
    public init() {}
    
    /// Exports all groups and non-deleted snippets as a JSON package
    public func exportJSON(groups: [SnippetGroup], snippets: [Snippet]) throws -> Data {
        let activeSnippets = snippets.filter { !$0.isDeleted }
        let package = ExpandiPackage(groups: groups, snippets: activeSnippets)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(package)
    }
    
    /// Exports snippets and their group names as a CSV string
    public func exportCSV(groups: [SnippetGroup], snippets: [Snippet]) -> String {
        let groupMap = Dictionary(uniqueKeysWithValues: groups.map { ($0.id, $0.name) })
        let activeSnippets = snippets.filter { !$0.isDeleted }
        
        var csv = "Abbreviation,Title,Content,Group,Tags,Type,DelimiterMode,CaseSensitivity,Notes\n"
        
        for snippet in activeSnippets {
            let groupName = groupMap[snippet.groupId] ?? "Default"
            let tags = snippet.tags.joined(separator: ";")
            let delimMode = snippet.delimiterMode.isImmediate ? "immediate" : "delimiter"
            
            let row = [
                escapeCSV(snippet.abbreviation),
                escapeCSV(snippet.title),
                escapeCSV(snippet.content),
                escapeCSV(groupName),
                escapeCSV(tags),
                escapeCSV(snippet.type.rawValue),
                escapeCSV(delimMode),
                escapeCSV(snippet.caseSensitivity.rawValue),
                escapeCSV(snippet.notes)
            ].joined(separator: ",")
            
            csv.append(row + "\n")
        }
        
        return csv
    }
    
    private func escapeCSV(_ value: String) -> String {
        var escaped = value
        if escaped.contains("\"") || escaped.contains(",") || escaped.contains("\n") || escaped.contains("\r") {
            escaped = escaped.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return escaped
    }
}
