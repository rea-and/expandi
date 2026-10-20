import Foundation
import Combine

@MainActor
public final class SnippetStore: ObservableObject {
    public static let shared = SnippetStore()
    
    @Published public var snippets: [Snippet] = []
    @Published public var groups: [SnippetGroup] = []
    @Published public var settings: AppSettings = AppSettings()
    @Published public var stats: ExpansionStats = ExpansionStats()
    
    private let fileManager = FileManager.default
    private let appSupportDir: URL
    private let snippetsURL: URL
    private let groupsURL: URL
    private let settingsURL: URL
    private let statsURL: URL
    
    public init() {
        // Setup Application Support directory
        let baseDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.appSupportDir = baseDir.appendingPathComponent("Expandi", isDirectory: true)
        self.snippetsURL = appSupportDir.appendingPathComponent("snippets.json")
        self.groupsURL = appSupportDir.appendingPathComponent("groups.json")
        self.settingsURL = appSupportDir.appendingPathComponent("settings.json")
        self.statsURL = appSupportDir.appendingPathComponent("stats.json")
        
        createDirectoryIfNeeded()
        loadData()
    }
    
    private func createDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: appSupportDir.path) {
            try? fileManager.createDirectory(at: appSupportDir, withIntermediateDirectories: true)
        }
    }
    
    // MARK: - Persistence
    
    public func loadData() {
        // Load Settings
        if let settingsData = try? Data(contentsOf: settingsURL),
           let decodedSettings = try? JSONDecoder().decode(AppSettings.self, from: settingsData) {
            self.settings = decodedSettings
        } else {
            self.settings = AppSettings()
            saveSettings()
        }
        
        // Load Stats
        if let statsData = try? Data(contentsOf: statsURL),
           let decodedStats = try? JSONDecoder().decode(ExpansionStats.self, from: statsData) {
            self.stats = decodedStats
        } else {
            self.stats = ExpansionStats()
            saveStats()
        }
        
        // Load Groups & Snippets
        var loadedGroups: [SnippetGroup]? = nil
        var loadedSnippets: [Snippet]? = nil
        
        if let groupsData = try? Data(contentsOf: groupsURL),
           let decodedGroups = try? JSONDecoder().decode([SnippetGroup].self, from: groupsData) {
            loadedGroups = decodedGroups
        }
        
        if let snippetsData = try? Data(contentsOf: snippetsURL),
           let decodedSnippets = try? JSONDecoder().decode([Snippet].self, from: snippetsData) {
            loadedSnippets = decodedSnippets
        }
        
        if let groups = loadedGroups, let snippets = loadedSnippets {
            self.groups = groups
            self.snippets = snippets
            syncKeyboardMonitorCache()
        } else {
            // First run: load default library
            let defaults = DefaultSnippets.generateDefaultData()
            self.groups = defaults.groups
            self.snippets = defaults.snippets
            saveAll()
        }
    }
    
    public func saveAll() {
        syncKeyboardMonitorCache()
        saveGroups()
        saveSnippets()
        saveSettings()
        saveStats()
    }
    
    public func syncKeyboardMonitorCache() {
        KeyboardMonitor.shared.updateCache(snippets: snippets, groups: groups, settings: settings)
    }
    
    public func saveGroups() {
        syncKeyboardMonitorCache()
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(groups)
            try data.write(to: groupsURL, options: .atomic)
        } catch {
            print("Expandi: Failed to save groups: \(error)")
        }
    }
    
    public func saveSnippets() {
        syncKeyboardMonitorCache()
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(snippets)
            try data.write(to: snippetsURL, options: .atomic)
        } catch {
            print("Expandi: Failed to save snippets: \(error)")
        }
    }
    
    public func saveSettings() {
        syncKeyboardMonitorCache()
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(settings)
            try data.write(to: settingsURL, options: .atomic)
        } catch {
            print("Expandi: Failed to save settings: \(error)")
        }
    }
    
    public func saveStats() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(stats)
            try data.write(to: statsURL, options: .atomic)
        } catch {
            print("Expandi: Failed to save stats: \(error)")
        }
    }
    
    // MARK: - Snippet Management
    
    public func addSnippet(_ snippet: Snippet) {
        snippets.append(snippet)
        saveSnippets()
    }
    
    public func updateSnippet(_ snippet: Snippet) {
        if let index = snippets.firstIndex(where: { $0.id == snippet.id }) {
            var updated = snippet
            updated.updatedAt = Date()
            snippets[index] = updated
            saveSnippets()
        }
    }
    
    public func deleteSnippet(id: UUID) {
        if let index = snippets.firstIndex(where: { $0.id == id }) {
            snippets[index].isDeleted = true
            snippets[index].updatedAt = Date()
            saveSnippets()
        }
    }
    
    public func restoreSnippet(id: UUID) {
        if let index = snippets.firstIndex(where: { $0.id == id }) {
            snippets[index].isDeleted = false
            snippets[index].updatedAt = Date()
            saveSnippets()
        }
    }
    
    public func permanentlyDeleteSnippet(id: UUID) {
        snippets.removeAll { $0.id == id }
        saveSnippets()
    }
    
    public func emptyTrash() {
        snippets.removeAll { $0.isDeleted }
        saveSnippets()
    }
    
    public func duplicateSnippet(_ snippet: Snippet) -> Snippet {
        var duplicate = snippet
        duplicate.id = UUID()
        duplicate.title = "\(snippet.title) (Copy)"
        duplicate.abbreviation = "\(snippet.abbreviation)2"
        duplicate.createdAt = Date()
        duplicate.updatedAt = Date()
        duplicate.usageCount = 0
        duplicate.lastUsedAt = nil
        snippets.append(duplicate)
        saveSnippets()
        return duplicate
    }
    
    public func recordSnippetUsage(snippetId: UUID, abbreviationLength: Int, expandedLength: Int) {
        if let index = snippets.firstIndex(where: { $0.id == snippetId }) {
            snippets[index].usageCount += 1
            snippets[index].lastUsedAt = Date()
            let groupId = snippets[index].groupId
            stats.recordExpansion(
                snippetId: snippetId,
                groupId: groupId,
                abbreviationLength: abbreviationLength,
                expandedLength: expandedLength
            )
            saveSnippets()
            saveStats()
        }
    }
    
    // MARK: - Group Management
    
    public func addGroup(_ group: SnippetGroup) {
        groups.append(group)
        saveGroups()
    }
    
    public func updateGroup(_ group: SnippetGroup) {
        if let index = groups.firstIndex(where: { $0.id == group.id }) {
            groups[index] = group
            saveGroups()
        }
    }
    
    public func deleteGroup(id: UUID) {
        // Move snippets to another group or delete them
        let remainingGroups = groups.filter { $0.id != id }
        if let fallbackGroup = remainingGroups.first {
            for i in 0..<snippets.count {
                if snippets[i].groupId == id {
                    snippets[i].groupId = fallbackGroup.id
                }
            }
        }
        groups.removeAll { $0.id == id }
        saveGroups()
        saveSnippets()
    }
    
    public func resetToDefaults() {
        let defaults = DefaultSnippets.generateDefaultData()
        self.groups = defaults.groups
        self.snippets = defaults.snippets
        self.settings = AppSettings()
        self.stats = ExpansionStats()
        saveAll()
    }
    
    // MARK: - Helper Queries
    
    public func group(for id: UUID) -> SnippetGroup? {
        groups.first { $0.id == id }
    }
    
    public func activeSnippets() -> [Snippet] {
        let enabledGroupIds = Set(groups.filter { $0.isEnabled }.map { $0.id })
        return snippets.filter { !$0.isDeleted && enabledGroupIds.contains($0.groupId) }
    }
}
