import SwiftUI

@main
public struct ExpandiApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var store = SnippetStore.shared
    @StateObject private var appState = AppState.shared
    
    private var swiftUIColorScheme: ColorScheme? {
        switch store.settings.colorScheme {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
    
    public init() {
        if CommandLine.arguments.contains("--test") {
            TestRunner.runAllTests()
            exit(0)
        }
    }
    
    public var body: some Scene {
        WindowGroup("Expandi", id: "main") {
            MainWindowView()
                .frame(minWidth: 850, minHeight: 520)
                .preferredColorScheme(swiftUIColorScheme)
                .environmentObject(store)
                .environmentObject(appState)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Snippet") {
                    let fallback = store.ensureDefaultGroupExists()
                    let currentGroupId: UUID
                    if case .group(let gid) = appState.selectedSidebarItem, store.groups.contains(where: { $0.id == gid }) {
                        currentGroupId = gid
                    } else {
                        currentGroupId = fallback.id
                    }
                    let prefix = store.group(for: currentGroupId)?.prefix ?? ";"
                    let newSnippet = Snippet(
                        title: "New Snippet",
                        abbreviation: "\(prefix)abbr\(Int.random(in: 10...99))",
                        content: "",
                        groupId: currentGroupId
                    )
                    store.addSnippet(newSnippet)
                    appState.selectedSnippetId = newSnippet.id
                }
                .keyboardShortcut("n", modifiers: .command)
                
                Button("Quick Search Snippets...") {
                    appDelegate.toggleQuickSearchHUD()
                }
                .keyboardShortcut(" ", modifiers: .option)
            }
            
            CommandGroup(replacing: .appInfo) {
                Button("About Expandi") {
                    NSApp.orderFrontStandardAboutPanel(
                        options: [
                            NSApplication.AboutPanelOptionKey.applicationName: "Expandi",
                            NSApplication.AboutPanelOptionKey.version: "1.0.0",
                            NSApplication.AboutPanelOptionKey(rawValue: "Copyright"): "Copyright © 2026 Expandi Labs. All rights reserved."
                        ]
                    )
                }
                
                Divider()
                
                Button("Typing Analytics...") {
                    appState.activeSheet = .stats
                }
                
                Button("Preferences...") {
                    appState.activeSheet = .settings
                }
                .keyboardShortcut(",", modifiers: .command)
                
                Divider()
                
                Button("Factory Reset...") {
                    appDelegate.promptFactoryReset()
                }
            }
            
            CommandGroup(after: .importExport) {
                Button("Import & Export...") {
                    appState.activeSheet = .importExport
                }
            }
        }
    }
}
