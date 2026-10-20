import SwiftUI

public struct SidebarView: View {
    @ObservedObject var store = SnippetStore.shared
    @ObservedObject var appState = AppState.shared
    @State private var showingAddGroupSheet = false
    @State private var editingGroup: SnippetGroup? = nil
    
    public init() {}
    
    private var allActiveSnippets: [Snippet] {
        store.snippets.filter { !$0.isDeleted }
    }
    
    private var favoriteCount: Int {
        allActiveSnippets.filter { $0.isFavorite }.count
    }
    
    private var recentCount: Int {
        allActiveSnippets.filter { $0.lastUsedAt != nil }.count
    }
    
    private var templateCount: Int {
        allActiveSnippets.filter { $0.hasFillIns }.count
    }
    
    private var trashCount: Int {
        store.snippets.filter { $0.isDeleted }.count
    }
    
    private var allTags: [(tag: String, count: Int)] {
        var counts: [String: Int] = [:]
        for s in allActiveSnippets {
            for t in s.tags {
                counts[t, default: 0] += 1
            }
        }
        return counts.map { (tag: $0.key, count: $0.value) }.sorted { $0.tag < $1.tag }
    }
    
    public var body: some View {
        List(selection: $appState.selectedSidebarItem) {
            // MARK: - Library Section
            Section("Library") {
                NavigationLink(value: SidebarSelection.all) {
                    Label {
                        Text("All Snippets")
                    } icon: {
                        Image(systemName: "tray.full.fill")
                            .foregroundStyle(.blue)
                    }
                    .badge(allActiveSnippets.count)
                }
                
                NavigationLink(value: SidebarSelection.favorites) {
                    Label {
                        Text("Favorites")
                    } icon: {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                    }
                    .badge(favoriteCount)
                }
                
                NavigationLink(value: SidebarSelection.recent) {
                    Label {
                        Text("Recently Used")
                    } icon: {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundStyle(.purple)
                    }
                    .badge(recentCount)
                }
                
                NavigationLink(value: SidebarSelection.templates) {
                    Label {
                        Text("Fill-In Templates")
                    } icon: {
                        Image(systemName: "square.and.pencil")
                            .foregroundStyle(.green)
                    }
                    .badge(templateCount)
                }
            }
            
            // MARK: - Groups Section
            Section {
                ForEach(store.groups.sorted(by: { $0.orderIndex < $1.orderIndex })) { group in
                    NavigationLink(value: SidebarSelection.group(group.id)) {
                        HStack(spacing: 8) {
                            Image(systemName: group.iconName)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color(hex: group.colorHex))
                                .frame(width: 18)
                            
                            Text(group.name)
                                .lineLimit(1)
                            
                            if !group.prefix.isEmpty {
                                Text(group.prefix)
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Color.secondary.opacity(0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                            }
                            
                            Spacer()
                        }
                        .badge(snippetsCount(for: group.id))
                    }
                    .contextMenu {
                        Button("New Snippet in Group") {
                            appState.selectedSidebarItem = .group(group.id)
                            appState.activeSheet = .newSnippet(groupId: group.id)
                        }
                        Button("Edit Group...") {
                            editingGroup = group
                        }
                        Divider()
                        Button(role: .destructive) {
                            store.deleteGroup(id: group.id)
                        } label: {
                            Text("Delete Group")
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Groups")
                    Spacer()
                    Button {
                        showingAddGroupSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Add New Group")
                }
            }
            
            // MARK: - Tags Section
            if !allTags.isEmpty {
                Section("Tags") {
                    ForEach(allTags, id: \.tag) { item in
                        NavigationLink(value: SidebarSelection.tag(item.tag)) {
                            Label {
                                Text(item.tag)
                            } icon: {
                                Image(systemName: "tag.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            .badge(item.count)
                        }
                    }
                }
            }
            
            // MARK: - Trash Section
            Section {
                NavigationLink(value: SidebarSelection.trash) {
                    Label {
                        Text("Trash")
                    } icon: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                    .badge(trashCount)
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()
                HStack(spacing: 12) {
                    Button {
                        appState.activeSheet = .stats
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "chart.bar.xaxis")
                            Text("Stats")
                                .font(.system(size: 12, weight: .medium))
                        }
                    }
                    .buttonStyle(.plain)
                    .help("View Typing Analytics")
                    
                    Spacer()
                    
                    Button {
                        appState.activeSheet = .importExport
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    .help("Import / Export Snippets")
                    
                    Button {
                        appState.activeSheet = .settings
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    .help("Expandi Preferences")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.bar)
            }
        }
        .sheet(isPresented: $showingAddGroupSheet) {
            GroupEditSheet(group: nil) { newGroup in
                store.addGroup(newGroup)
            }
        }
        .sheet(item: $editingGroup) { group in
            GroupEditSheet(group: group) { updated in
                store.updateGroup(updated)
            }
        }
    }
    
    private func snippetsCount(for groupId: UUID) -> Int {
        allActiveSnippets.filter { $0.groupId == groupId }.count
    }
}

// MARK: - Group Edit Sheet

public struct GroupEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var iconName: String
    @State private var colorHex: String
    @State private var prefix: String
    
    private let groupToEdit: SnippetGroup?
    private let onSave: (SnippetGroup) -> Void
    
    private let icons = [
        "folder.fill", "calendar", "person.crop.circle.fill", "envelope.fill",
        "curlybraces", "bubble.left.and.bubble.right.fill", "face.smiling.fill",
        "doc.text.fill", "tag.fill", "bolt.fill", "star.fill", "briefcase.fill"
    ]
    
    private let colors = [
        "#0A84FF", "#30D158", "#FF9F0A", "#FF375F", "#BF5AF2",
        "#FFD60A", "#64D2FF", "#AC8E68", "#98989D"
    ]
    
    public init(group: SnippetGroup?, onSave: @escaping (SnippetGroup) -> Void) {
        self.groupToEdit = group
        self.onSave = onSave
        _name = State(initialValue: group?.name ?? "")
        _iconName = State(initialValue: group?.iconName ?? "folder.fill")
        _colorHex = State(initialValue: group?.colorHex ?? "#0A84FF")
        _prefix = State(initialValue: group?.prefix ?? ";")
    }
    
    public var body: some View {
        VStack(spacing: 20) {
            Text(groupToEdit == nil ? "New Snippet Group" : "Edit Snippet Group")
                .font(.headline)
            
            Form {
                TextField("Group Name", text: $name)
                
                TextField("Trigger Prefix (optional, e.g. ';')", text: $prefix)
                    .help("Automatically prepended to snippet abbreviations in this group")
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Icon:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 8) {
                        ForEach(icons, id: \.self) { icon in
                            Button {
                                iconName = icon
                            } label: {
                                Image(systemName: icon)
                                    .font(.system(size: 16))
                                    .frame(width: 32, height: 32)
                                    .background(iconName == icon ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
                                    .foregroundStyle(iconName == icon ? Color.accentColor : Color.primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(iconName == icon ? Color.accentColor : Color.clear, lineWidth: 1.5)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Color:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                        ForEach(colors, id: \.self) { hex in
                            Button {
                                colorHex = hex
                            } label: {
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 22, height: 22)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.primary, lineWidth: colorHex == hex ? 2 : 0)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Save") {
                    let group = SnippetGroup(
                        id: groupToEdit?.id ?? UUID(),
                        name: name.trimmingCharacters(in: .whitespaces).isEmpty ? "Untitled Group" : name,
                        iconName: iconName,
                        colorHex: colorHex,
                        prefix: prefix,
                        isEnabled: groupToEdit?.isEnabled ?? true,
                        excludedApps: groupToEdit?.excludedApps ?? [],
                        orderIndex: groupToEdit?.orderIndex ?? 0
                    )
                    onSave(group)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 380, height: 380)
    }
}

// MARK: - Color Hex Extension

extension Color {
    public init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 10, 132, 255)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
