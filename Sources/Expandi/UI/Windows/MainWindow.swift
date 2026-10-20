import SwiftUI

public struct MainWindowView: View {
    @ObservedObject var store = SnippetStore.shared
    @ObservedObject var appState = AppState.shared
    
    public init() {}
    
    public var body: some View {
        NavigationSplitView {
            SidebarView()
                .frame(minWidth: 200, idealWidth: 230, maxWidth: 300)
        } content: {
            SnippetListView()
                .frame(minWidth: 240, idealWidth: 280, maxWidth: 360)
        } detail: {
            SnippetEditorView()
                .frame(minWidth: 450)
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    store.settings.isExpansionEnabled.toggle()
                    store.saveSettings()
                } label: {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(store.settings.isExpansionEnabled ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)
                        Text(store.settings.isExpansionEnabled ? "Active" : "Paused")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Toggle snippet expansion system-wide")
            }
            
            ToolbarItem(placement: .automatic) {
                Menu {
                    Button("System Appearance") {
                        store.settings.colorScheme = .system
                        store.saveSettings()
                        AppDelegate.shared?.applyAppearance()
                    }
                    Button("Light Mode") {
                        store.settings.colorScheme = .light
                        store.saveSettings()
                        AppDelegate.shared?.applyAppearance()
                    }
                    Button("Dark Mode") {
                        store.settings.colorScheme = .dark
                        store.saveSettings()
                        AppDelegate.shared?.applyAppearance()
                    }
                } label: {
                    Image(systemName: store.settings.colorScheme == .light ? "sun.max.fill" : (store.settings.colorScheme == .dark ? "moon.fill" : "circle.righthalf.filled"))
                }
                .help("Switch Appearance (System / Light / Dark)")
            }
            
            ToolbarItem(placement: .automatic) {
                Button {
                    AppDelegate.shared?.toggleQuickSearchHUD()
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .help("Open Quick Search HUD (\(store.settings.quickSearchHotkey))")
            }
        }
        .onAppear {
            if !store.settings.hasCompletedOnboarding {
                appState.activeSheet = .onboarding
            }
        }
        .onChange(of: store.settings.hasCompletedOnboarding) { _, completed in
            if !completed {
                appState.activeSheet = .onboarding
            } else if case .onboarding = appState.activeSheet {
                appState.activeSheet = nil
            }
        }
        .sheet(item: $appState.activeSheet) { sheet in
            switch sheet {
            case .onboarding:
                OnboardingWelcomeView(
                    onChooseStarterPack: {
                        store.loadStarterSnippets()
                        appState.activeSheet = nil
                    },
                    onChooseEmpty: {
                        store.startEmptyLibrary()
                        appState.activeSheet = nil
                    }
                )
                .interactiveDismissDisabled(true)
            case .stats:
                StatsView()
            case .settings:
                SettingsView()
            case .importExport:
                ImportExportView()
            case .permissions:
                PermissionsView()
            default:
                EmptyView()
            }
        }
    }
}
