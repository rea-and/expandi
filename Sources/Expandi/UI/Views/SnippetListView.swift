import SwiftUI

public struct SnippetListView: View {
    @ObservedObject var store = SnippetStore.shared
    @ObservedObject var appState = AppState.shared
    @State private var filterSnippetType: SnippetType? = nil
    
    public init() {}
    
    private var isTrashView: Bool {
        if case .trash = appState.selectedSidebarItem { return true }
        return false
    }
    
    private var baseSnippets: [Snippet] {
        switch appState.selectedSidebarItem {
        case .all:
            return store.snippets.filter { !$0.isDeleted }
        case .favorites:
            return store.snippets.filter { !$0.isDeleted && $0.isFavorite }
        case .recent:
            return store.snippets.filter { !$0.isDeleted && $0.lastUsedAt != nil }
                .sorted { ($0.lastUsedAt ?? .distantPast) > ($1.lastUsedAt ?? .distantPast) }
        case .templates:
            return store.snippets.filter { !$0.isDeleted && $0.hasFillIns }
        case .group(let groupId):
            return store.snippets.filter { !$0.isDeleted && $0.groupId == groupId }
        case .tag(let tag):
            return store.snippets.filter { !$0.isDeleted && $0.tags.contains(tag) }
        case .trash:
            return store.snippets.filter { $0.isDeleted }
        }
    }
    
    private var filteredSnippets: [Snippet] {
        var list = baseSnippets
        
        // Type filter
        if let typeFilter = filterSnippetType {
            list = list.filter { $0.type == typeFilter }
        }
        
        // Search filter
        let query = appState.searchText.trimmingCharacters(in: .whitespaces).lowercased()
        if !query.isEmpty {
            list = list.filter {
                $0.abbreviation.lowercased().contains(query) ||
                $0.title.lowercased().contains(query) ||
                $0.content.lowercased().contains(query) ||
                $0.notes.lowercased().contains(query) ||
                $0.tags.contains { $0.lowercased().contains(query) }
            }
        }
        
        // Sort
        switch appState.sortOrder {
        case .abbreviation:
            list.sort { $0.abbreviation.localizedCaseInsensitiveCompare($1.abbreviation) == .orderedAscending }
        case .title:
            list.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .mostUsed:
            list.sort { $0.usageCount > $1.usageCount }
        case .recentlyUsed:
            list.sort { ($0.lastUsedAt ?? .distantPast) > ($1.lastUsedAt ?? .distantPast) }
        case .dateCreated:
            list.sort { $0.createdAt > $1.createdAt }
        }
        
        return list
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header Search & Filter Bar
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 12))
                    TextField("Search snippets...", text: $appState.searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                    if !appState.searchText.isEmpty {
                        Button {
                            appState.searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                
                Menu {
                    Picker("Sort by", selection: $appState.sortOrder) {
                        ForEach(AppState.SortOrder.allCases) { order in
                            Text(order.rawValue).tag(order)
                        }
                    }
                    Divider()
                    Picker("Type Filter", selection: $filterSnippetType) {
                        Text("All Types").tag(SnippetType?.none)
                        ForEach(SnippetType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(SnippetType?.some(type))
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 14))
                }
                .menuStyle(.borderlessButton)
                .frame(width: 28)
                
                if isTrashView {
                    Button(role: .destructive) {
                        store.emptyTrash()
                    } label: {
                        Text("Empty")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                } else {
                    Button {
                        createNewSnippet()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .keyboardShortcut("n", modifiers: .command)
                    .help("Create New Snippet (⌘N)")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar)
            
            Divider()
            
            // Snippets List
            if filteredSnippets.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: isTrashView ? "trash" : "text.badge.plus")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary.opacity(0.5))
                    Text(isTrashView ? "Trash is Empty" : (appState.searchText.isEmpty ? "No Snippets Found" : "No Matching Snippets"))
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    if !isTrashView && appState.searchText.isEmpty {
                        Button("Create Snippet") {
                            createNewSnippet()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $appState.selectedSnippetId) {
                    ForEach(filteredSnippets) { snippet in
                        SnippetRowView(snippet: snippet, isTrashView: isTrashView)
                            .tag(snippet.id)
                            .contextMenu {
                                if isTrashView {
                                    Button("Restore Snippet") {
                                        store.restoreSnippet(id: snippet.id)
                                    }
                                    Button(role: .destructive) {
                                        store.permanentlyDeleteSnippet(id: snippet.id)
                                    } label: {
                                        Text("Delete Permanently")
                                    }
                                } else {
                                    Button(snippet.isFavorite ? "Unfavorite" : "Favorite") {
                                        var copy = snippet
                                        copy.isFavorite.toggle()
                                        store.updateSnippet(copy)
                                    }
                                    Button("Duplicate Snippet") {
                                        let dup = store.duplicateSnippet(snippet)
                                        appState.selectedSnippetId = dup.id
                                    }
                                    Divider()
                                    Button(role: .destructive) {
                                        store.deleteSnippet(id: snippet.id)
                                    } label: {
                                        Text("Move to Trash")
                                    }
                                }
                            }
                    }
                }
                .listStyle(.inset)
            }
        }
    }
    
    private func createNewSnippet() {
        let currentGroupId: UUID
        if case .group(let gid) = appState.selectedSidebarItem {
            currentGroupId = gid
        } else {
            currentGroupId = store.groups.first?.id ?? UUID()
        }
        
        let prefix = store.group(for: currentGroupId)?.prefix ?? ";"
        let newSnippet = Snippet(
            title: "New Snippet",
            abbreviation: "\(prefix)abbr\(Int.random(in: 10...99))",
            content: "Content goes here...",
            groupId: currentGroupId
        )
        store.addSnippet(newSnippet)
        appState.selectedSnippetId = newSnippet.id
    }
}

// MARK: - Snippet Row View

public struct SnippetRowView: View {
    let snippet: Snippet
    let isTrashView: Bool
    @ObservedObject var store = SnippetStore.shared
    
    private var group: SnippetGroup? {
        store.group(for: snippet.groupId)
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                // Abbreviation Badge
                Text(snippet.abbreviation)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.15))
                    .foregroundStyle(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                
                // Title
                Text(snippet.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                
                Spacer()
                
                // Favorite indicator
                if snippet.isFavorite && !isTrashView {
                    Image(systemName: "star.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.yellow)
                }
            }
            
            // Content Preview
            Text(snippet.content.replacingOccurrences(of: "\n", with: " "))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(2)
            
            // Badges row
            HStack(spacing: 6) {
                if let grp = group {
                    HStack(spacing: 3) {
                        Image(systemName: grp.iconName)
                            .font(.system(size: 9))
                            .foregroundStyle(Color(hex: grp.colorHex))
                        Text(grp.name)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                
                if snippet.hasFillIns {
                    HStack(spacing: 3) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 9))
                        Text("Fill-in")
                            .font(.system(size: 9, weight: .medium))
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.green.opacity(0.15))
                    .foregroundStyle(.green)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                
                if snippet.usageCount > 0 {
                    Text("\(snippet.usageCount)x")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }
}
