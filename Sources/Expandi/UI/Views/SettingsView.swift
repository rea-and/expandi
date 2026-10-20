import SwiftUI
import AppKit

public struct SettingsView: View {
    @ObservedObject var store = SnippetStore.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTab: SettingsTab = .general
    @State private var isAccessibilityGranted: Bool = KeyboardMonitor.shared.isAccessibilityGranted
    @State private var newExcludedApp: String = ""
    @State private var showingDeleteAllAlert = false
    @State private var showingResetDefaultsAlert = false
    @State private var showingFactoryResetAlert = false
    
    enum SettingsTab: String, CaseIterable, Identifiable {
        case general = "General"
        case expansion = "Expansion"
        case hotkeys = "Hotkeys"
        case excludedApps = "Excluded"
        case permissions = "Permissions"
        case advanced = "Advanced"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .general: return "gearshape.fill"
            case .expansion: return "bolt.fill"
            case .hotkeys: return "command"
            case .excludedApps: return "app.badge.xmark"
            case .permissions: return "hand.raised.fill"
            case .advanced: return "slider.horizontal.3"
            }
        }
        
        var fullTitle: String {
            switch self {
            case .excludedApps: return "Excluded Applications"
            default: return rawValue
            }
        }
    }
    
    private let availableSounds = [
        "Tink", "Pop", "Blow", "Bottle", "Frog", "Funk",
        "Glass", "Hero", "Morse", "Ping", "Purr", "Sosumi", "Submarine"
    ]
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Expandi Preferences")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)
            .background(.bar)
            
            Divider()
            
            // Native Tab Bar with SF Symbols
            HStack(spacing: 6) {
                ForEach(SettingsTab.allCases) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(selectedTab == tab ? Color.accentColor : Color.secondary)
                            
                            Text(tab.rawValue)
                                .font(.system(size: 11, weight: selectedTab == tab ? .semibold : .regular))
                                .foregroundStyle(selectedTab == tab ? Color.primary : Color.secondary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .padding(.horizontal, 4)
                        .background(
                            selectedTab == tab
                                ? Color.accentColor.opacity(0.12)
                                : Color.secondary.opacity(0.04)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .help(tab.fullTitle)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.bar)
            
            Divider()
            
            // Tab Contents
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    switch selectedTab {
                    case .general:
                        generalSection
                    case .expansion:
                        expansionSection
                    case .hotkeys:
                        hotkeysSection
                    case .excludedApps:
                        excludedAppsSection
                    case .permissions:
                        permissionsSection
                    case .advanced:
                        advancedSection
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
            
            Spacer()
        }
        .frame(width: 580, height: 480)
        .onAppear {
            isAccessibilityGranted = KeyboardMonitor.shared.checkAccessibilityPermissions()
        }
    }
    
    // MARK: - General
    
    @ViewBuilder
    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle("Enable Text Expansion", isOn: Binding(
                get: { store.settings.isExpansionEnabled },
                set: {
                    store.settings.isExpansionEnabled = $0
                    store.saveSettings()
                }
            ))
            .font(.system(size: 13, weight: .semibold))
            
            Divider()
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Color Scheme / Appearance:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                
                Picker("", selection: Binding(
                    get: { store.settings.colorScheme },
                    set: { newScheme in
                        store.settings.colorScheme = newScheme
                        store.saveSettings()
                        AppDelegate.shared?.applyAppearance()
                    }
                )) {
                    ForEach(AppColorScheme.allCases, id: \.self) { scheme in
                        Label(scheme.displayName, systemImage: scheme.iconName).tag(scheme)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 280)
            }
            
            Divider()
            
            Toggle("Play Sound Effect on Expansion", isOn: Binding(
                get: { store.settings.playSoundOnExpansion },
                set: {
                    store.settings.playSoundOnExpansion = $0
                    store.saveSettings()
                }
            ))
            
            if store.settings.playSoundOnExpansion {
                HStack(spacing: 12) {
                    Text("Sound Effect:")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    
                    Picker("", selection: Binding(
                        get: { store.settings.soundName },
                        set: {
                            store.settings.soundName = $0
                            store.saveSettings()
                            SoundPlayer.shared.playExpansionSound(soundName: $0)
                        }
                    )) {
                        ForEach(availableSounds, id: \.self) { sound in
                            Text(sound).tag(sound)
                        }
                    }
                    .frame(width: 140)
                    
                    Button("Test Sound") {
                        SoundPlayer.shared.playExpansionSound(soundName: store.settings.soundName)
                    }
                    .controlSize(.small)
                }
                .padding(.leading, 20)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Expansion Keystroke Delay:")
                        .font(.system(size: 12))
                    Spacer()
                    Text("\(store.settings.expansionDelayMs) ms")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                }
                
                Slider(
                    value: Binding(
                        get: { Double(store.settings.expansionDelayMs) },
                        set: {
                            store.settings.expansionDelayMs = Int($0)
                            store.saveSettings()
                        }
                    ),
                    in: 5...40,
                    step: 1
                )
                Text("Controls the brief delay between keystrokes when injecting text. 10ms is optimal for most modern Macs.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Divider()
            
            Divider()
            
            VStack(alignment: .leading, spacing: 10) {
                Text("System & Startup")
                    .font(.system(size: 13, weight: .semibold))
                
                Toggle("Launch Expandi automatically on login", isOn: Binding(
                    get: { store.settings.launchAtLogin },
                    set: { newValue in
                        store.settings.launchAtLogin = newValue
                        store.saveSettings()
                        LaunchAtLoginManager.shared.setEnabled(newValue)
                    }
                ))
                Text("Expandi starts automatically when you log into your Mac so abbreviations work immediately.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 20)
                
                Toggle("Hide app from Dock when window is closed", isOn: Binding(
                    get: { store.settings.hideFromDockWhenClosed },
                    set: { newValue in
                        store.settings.hideFromDockWhenClosed = newValue
                        store.saveSettings()
                        AppDelegate.shared?.updateDockVisibility()
                    }
                ))
                Text("When closed, Expandi hides from the Dock and stays active in your menu bar. Reopen anytime from the menu bar.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 20)
                
                Toggle("Show Icon in Menu Bar", isOn: Binding(
                    get: { store.settings.showMenuBarIcon },
                    set: {
                        store.settings.showMenuBarIcon = $0
                        store.saveSettings()
                    }
                ))
            }
        }
    }
    
    // MARK: - Expansion
    
    @ViewBuilder
    private var expansionSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Default Behavior for New Snippets")
                .font(.system(size: 13, weight: .semibold))
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Default Trigger Mode:")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Picker("", selection: Binding(
                    get: { store.settings.defaultDelimiterMode },
                    set: {
                        store.settings.defaultDelimiterMode = $0
                        store.saveSettings()
                    }
                )) {
                    Text("Immediately upon typing abbreviation").tag("immediate")
                    Text("Only after delimiter (space, comma, etc.)").tag("afterDelimiter")
                }
                .pickerStyle(.radioGroup)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Default Case Sensitivity:")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Picker("", selection: Binding(
                    get: { store.settings.defaultCaseSensitivity },
                    set: {
                        store.settings.defaultCaseSensitivity = $0
                        store.saveSettings()
                    }
                )) {
                    Text("Adapt to Typed Case (e.g. typing ';DATE' expands in ALL CAPS)").tag("adaptCase")
                    Text("Exact Match Only").tag("exactMatch")
                    Text("Ignore Case").tag("ignoreCase")
                }
                .pickerStyle(.radioGroup)
            }
        }
    }
    
    // MARK: - Hotkeys
    
    @ViewBuilder
    private var hotkeysSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Global Shortcuts")
                .font(.system(size: 13, weight: .semibold))
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Quick Search HUD Hotkey:")
                        .font(.system(size: 12, weight: .medium))
                    Text("Opens the Spotlight-style snippet search anywhere in macOS")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Picker("", selection: Binding(
                    get: { store.settings.quickSearchHotkey },
                    set: {
                        store.settings.quickSearchHotkey = $0
                        store.saveSettings()
                        HotkeyManager.shared.register(shortcut: $0) {
                            Task { @MainActor in
                                AppDelegate.shared?.toggleQuickSearchHUD()
                            }
                        }
                    }
                )) {
                    Text("⌥ Space (Option + Space)").tag("Option+Space")
                    Text("⇧⌘E (Cmd + Shift + E)").tag("Cmd+Shift+E")
                    Text("⇧⌘K (Cmd + Shift + K)").tag("Cmd+Shift+K")
                    Text("⌥⌘E (Option + Cmd + E)").tag("Option+Cmd+E")
                }
                .frame(width: 220)
            }
        }
    }
    
    // MARK: - Excluded Apps
    
    @ViewBuilder
    private var excludedAppsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Exclude Applications")
                .font(.system(size: 13, weight: .semibold))
            Text("Expandi will never monitor or expand snippets when typing inside these apps (e.g. password managers or terminal):")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack {
                TextField("e.g. com.1password.1password or Terminal", text: $newExcludedApp)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                
                Button("Add App") {
                    let trimmed = newExcludedApp.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty && !store.settings.excludedAppBundleIds.contains(trimmed) {
                        store.settings.excludedAppBundleIds.append(trimmed)
                        store.saveSettings()
                        newExcludedApp = ""
                    }
                }
                .controlSize(.small)
            }
            
            VStack(spacing: 4) {
                ForEach(store.settings.excludedAppBundleIds, id: \.self) { bundleId in
                    HStack {
                        Image(systemName: "app.badge.xmark")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 11))
                        Text(bundleId)
                            .font(.system(size: 12, design: .monospaced))
                        Spacer()
                        Button {
                            store.settings.excludedAppBundleIds.removeAll { $0 == bundleId }
                            store.saveSettings()
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.secondary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }
    
    // MARK: - Permissions
    
    @ViewBuilder
    private var permissionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: isAccessibilityGranted ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(isAccessibilityGranted ? .green : .orange)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(isAccessibilityGranted ? "Accessibility Permission Granted" : "Accessibility Permission Required")
                        .font(.headline)
                    Text(isAccessibilityGranted ? "Expandi is fully authorized to monitor keystrokes and expand snippets system-wide." : "macOS requires Accessibility access so Expandi can detect abbreviations and insert expanded text.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .background((isAccessibilityGranted ? Color.green : Color.orange).opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            Button("Open macOS Accessibility Settings...") {
                KeyboardMonitor.shared.openSystemSettingsAccessibility()
            }
            .buttonStyle(.borderedProminent)
            
            Button("Re-check Permission Status") {
                isAccessibilityGranted = KeyboardMonitor.shared.checkAccessibilityPermissions()
            }
            .controlSize(.small)
        }
    }
    
    // MARK: - Advanced
    
    @ViewBuilder
    private var advancedSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Library Status Card
            VStack(alignment: .leading, spacing: 6) {
                Text("Library Summary")
                    .font(.system(size: 13, weight: .semibold))
                
                HStack(spacing: 16) {
                    Label("\(store.snippets.filter { !$0.isDeleted }.count) active snippets", systemImage: "text.alignleft")
                        .font(.caption)
                    Label("\(store.groups.count) groups", systemImage: "folder")
                        .font(.caption)
                    Label("\(store.snippets.filter { $0.isDeleted }.count) in trash", systemImage: "trash")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            Divider()
            
            // Delete All Snippets
            VStack(alignment: .leading, spacing: 6) {
                Text("Delete Snippets")
                    .font(.system(size: 13, weight: .semibold))
                
                Button(role: .destructive) {
                    showingDeleteAllAlert = true
                } label: {
                    Text("Delete All Saved Snippets...")
                }
                .buttonStyle(.bordered)
                
                Text("Permanently deletes all active and trashed snippets while preserving your group structure and settings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Divider()
            
            // Reset to Starter Library
            VStack(alignment: .leading, spacing: 6) {
                Text("Starter Snippets")
                    .font(.system(size: 13, weight: .semibold))
                
                Button {
                    showingResetDefaultsAlert = true
                } label: {
                    Text("Restore Default Starter Snippets...")
                }
                .buttonStyle(.bordered)
                
                Text("Replaces all current snippets and groups with the pre-loaded sample library (Dates, Emojis, Templates, Math).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Divider()
            
            // Danger Zone: Factory Reset
            VStack(alignment: .leading, spacing: 6) {
                Text("Danger Zone: Factory Reset")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.red)
                
                HStack(spacing: 12) {
                    Button(role: .destructive) {
                        showingFactoryResetAlert = true
                    } label: {
                        Text("Factory Reset Expandi...")
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Re-run Welcome Setup...") {
                        store.settings.hasCompletedOnboarding = false
                        store.saveSettings()
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                }
                
                Text("Factory reset completely clears all snippets, groups, statistics, and resets preferences back to clean initial state.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .alert("Delete All Snippets?", isPresented: $showingDeleteAllAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete All Snippets", role: .destructive) {
                store.deleteAllSnippets()
            }
        } message: {
            Text("Are you sure you want to permanently delete all \(store.snippets.count) snippets? This action cannot be undone.")
        }
        .alert("Restore Starter Snippets?", isPresented: $showingResetDefaultsAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Restore Starter Pack") {
                store.resetToDefaults()
            }
        } message: {
            Text("This will replace your current library with the default sample snippets and starter groups.")
        }
        .alert("Factory Reset Expandi?", isPresented: $showingFactoryResetAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Factory Reset (Wipe All)", role: .destructive) {
                store.wipeEverything(reOnboard: true)
                dismiss()
            }
            Button("Reset to Default Library") {
                store.resetToDefaults()
            }
        } message: {
            Text("This will completely reset Expandi. You can choose to wipe everything and see the Welcome setup, or restore the starter library.")
        }
    }
}
