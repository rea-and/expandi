import Foundation
import SwiftUI
import Combine

public enum SidebarSelection: Hashable, Sendable {
    case all
    case favorites
    case recent
    case templates
    case group(UUID)
    case tag(String)
    case trash
}

@MainActor
public final class AppState: ObservableObject {
    public static let shared = AppState()
    
    @Published public var selectedSidebarItem: SidebarSelection = .all
    @Published public var selectedSnippetId: UUID? = nil
    @Published public var searchText: String = ""
    @Published public var sortOrder: SortOrder = .abbreviation
    @Published public var activeSheet: ActiveSheet? = nil
    
    public enum SortOrder: String, CaseIterable, Identifiable {
        case abbreviation = "Abbreviation"
        case title = "Title"
        case mostUsed = "Most Used"
        case recentlyUsed = "Recently Used"
        case dateCreated = "Date Created"
        
        public var id: String { rawValue }
    }
    
    public enum ActiveSheet: Identifiable {
        case newSnippet(groupId: UUID?)
        case newGroup
        case editGroup(SnippetGroup)
        case settings
        case stats
        case importExport
        case permissions
        
        public var id: String {
            switch self {
            case .newSnippet: return "newSnippet"
            case .newGroup: return "newGroup"
            case .editGroup(let g): return "editGroup_\(g.id)"
            case .settings: return "settings"
            case .stats: return "stats"
            case .importExport: return "importExport"
            case .permissions: return "permissions"
            }
        }
    }
    
    public init() {}
}
