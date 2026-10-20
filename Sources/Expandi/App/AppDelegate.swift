import Cocoa
import SwiftUI
import ApplicationServices

// MARK: - Key-Focusable Panel for HUD and Dialogs

public final class FocusablePanel: NSPanel {
    public override var canBecomeKey: Bool { true }
    public override var canBecomeMain: Bool { true }
}

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate, KeyboardMonitorDelegate {
    public static private(set) var shared: AppDelegate?
    
    private var statusItem: NSStatusItem?
    private var quickSearchPanel: NSPanel?
    private var fillInPanel: NSPanel?
    private var targetAppBeforeHUD: NSRunningApplication?
    
    public override init() {
        super.init()
        AppDelegate.shared = self
    }
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        applyAppearance()
        
        // Setup Keyboard Monitor
        KeyboardMonitor.shared.delegate = self
        KeyboardMonitor.shared.start()
        
        // Setup Global Hotkey for Quick Search HUD
        let hotkey = SnippetStore.shared.settings.quickSearchHotkey
        HotkeyManager.shared.register(shortcut: hotkey) { [weak self] in
            Task { @MainActor in
                self?.toggleQuickSearchHUD()
            }
        }
        
        // Setup Status Bar Menu Item
        setupStatusBarItem()
        
        // Setup App Activation Observer to auto-recover tap when user returns from System Settings
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            if KeyboardMonitor.shared.checkAccessibilityPermissions() {
                KeyboardMonitor.shared.start()
            }
        }
        
        // Check Accessibility Permissions
        if !KeyboardMonitor.shared.isAccessibilityGranted {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                // If onboarding is not active, present permissions sheet
                if SnippetStore.shared.settings.hasCompletedOnboarding {
                    AppState.shared.activeSheet = .permissions
                }
            }
        }
    }
    
    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            openMainWindow()
        }
        return true
    }
    
    // MARK: - Appearance (Light / Dark)
    
    public func applyAppearance() {
        let scheme = SnippetStore.shared.settings.colorScheme
        switch scheme {
        case .system:
            NSApp.appearance = nil
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
    
    // MARK: - Status Bar Item
    
    private func setupStatusBarItem() {
        guard SnippetStore.shared.settings.showMenuBarIcon else { return }
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem?.button else { return }
        
        let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        if let image = NSImage(systemSymbolName: "text.badge.star", accessibilityDescription: "Expandi")?.withSymbolConfiguration(config) {
            image.isTemplate = true
            button.image = image
        } else {
            button.title = "✦"
        }
        
        rebuildStatusBarMenu()
    }
    
    public func rebuildStatusBarMenu() {
        guard let statusItem = statusItem else { return }
        
        let menu = NSMenu(title: "Expandi")
        let isEnabled = SnippetStore.shared.settings.isExpansionEnabled
        
        // Status indicator
        let statusTitle = isEnabled ? "● Expansion Active" : "○ Expansion Paused"
        let statusMenuItem = NSMenuItem(title: statusTitle, action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)
        
        let toggleTitle = isEnabled ? "Pause Expandi" : "Resume Expandi"
        let toggleItem = NSMenuItem(title: toggleTitle, action: #selector(toggleExpansion), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let searchItem = NSMenuItem(title: "Quick Search Snippets...", action: #selector(handleSearchMenuClick), keyEquivalent: " ")
        searchItem.keyEquivalentModifierMask = .option
        searchItem.target = self
        menu.addItem(searchItem)
        
        let openItem = NSMenuItem(title: "Open Expandi...", action: #selector(openMainWindow), keyEquivalent: "o")
        openItem.target = self
        menu.addItem(openItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Recent Snippets submenu
        let recentSnippets = SnippetStore.shared.snippets
            .filter { !$0.isDeleted && $0.lastUsedAt != nil }
            .sorted { ($0.lastUsedAt ?? .distantPast) > ($1.lastUsedAt ?? .distantPast) }
            .prefix(8)
        
        if !recentSnippets.isEmpty {
            let recentMenu = NSMenu(title: "Recent Snippets")
            for snippet in recentSnippets {
                let item = NSMenuItem(
                    title: "\(snippet.abbreviation) — \(snippet.title)",
                    action: #selector(handleRecentSnippetClick(_:)),
                    keyEquivalent: ""
                )
                item.representedObject = snippet
                item.target = self
                recentMenu.addItem(item)
            }
            let recentSubmenuItem = NSMenuItem(title: "Recent Snippets", action: nil, keyEquivalent: "")
            recentSubmenuItem.submenu = recentMenu
            menu.addItem(recentSubmenuItem)
        }
        
        // Stats summary
        let stats = SnippetStore.shared.stats
        let statsSummary = "\(stats.totalExpansions) expansions • \(stats.totalKeystrokesSaved) keys saved"
        let statsItem = NSMenuItem(title: statsSummary, action: #selector(openStats), keyEquivalent: "")
        statsItem.target = self
        menu.addItem(statsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let prefsItem = NSMenuItem(title: "Preferences...", action: #selector(openPreferences), keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)
        
        let permsItem = NSMenuItem(title: "Check Accessibility Permissions...", action: #selector(openPermissions), keyEquivalent: "")
        permsItem.target = self
        menu.addItem(permsItem)
        
        let resetItem = NSMenuItem(title: "Factory Reset...", action: #selector(promptFactoryReset), keyEquivalent: "")
        resetItem.target = self
        menu.addItem(resetItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit Expandi", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
        
        statusItem.menu = menu
    }
    
    @objc private func toggleExpansion() {
        SnippetStore.shared.settings.isExpansionEnabled.toggle()
        SnippetStore.shared.saveSettings()
        rebuildStatusBarMenu()
    }
    
    @objc private func handleSearchMenuClick() {
        toggleQuickSearchHUD()
    }
    
    @objc public func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { !($0 is NSPanel) && $0.canBecomeMain }) {
            window.makeKeyAndOrderFront(nil)
        }
    }
    
    @objc private func openPreferences() {
        openMainWindow()
        AppState.shared.activeSheet = .settings
    }
    
    @objc private func openStats() {
        openMainWindow()
        AppState.shared.activeSheet = .stats
    }
    
    @objc private func openPermissions() {
        openMainWindow()
        AppState.shared.activeSheet = .permissions
    }
    
    @objc public func promptFactoryReset() {
        openMainWindow()
        let alert = NSAlert()
        alert.messageText = "Factory Reset Expandi?"
        alert.informativeText = "Choose whether to reset your library to the default sample snippet pack, or wipe everything and start completely fresh."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Reset to Default Starter Pack")
        alert.addButton(withTitle: "Wipe All & Start Fresh")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            SnippetStore.shared.resetToDefaults()
        } else if response == .alertSecondButtonReturn {
            SnippetStore.shared.wipeEverything(reOnboard: true)
        }
    }
    
    @objc private func handleRecentSnippetClick(_ sender: NSMenuItem) {
        guard let snippet = sender.representedObject as? Snippet else { return }
        let evaluated = MacroEvaluator.shared.evaluate(snippet: snippet, allSnippets: SnippetStore.shared.snippets)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(evaluated.text, forType: .string)
    }
    
    // MARK: - KeyboardMonitorDelegate
    
    public nonisolated func keyboardMonitorDidMatchSnippet(_ match: SnippetMatch) {
        Task { @MainActor in
            self.handleSnippetExpansion(match: match)
        }
    }
    
    private func handleSnippetExpansion(match: SnippetMatch) {
        let snippet = match.snippet
        
        // If snippet has dynamic fill-ins, bring up the Fill-In HUD dialog
        if snippet.hasFillIns {
            showFillInModal(snippet: snippet, match: match)
            return
        }
        
        // Immediate expansion without fill-ins
        let result = MacroEvaluator.shared.evaluate(
            snippet: snippet,
            allSnippets: SnippetStore.shared.snippets,
            typedTrigger: match.typedAbbreviation
        )
        
        // Play sound if configured
        if SnippetStore.shared.settings.playSoundOnExpansion {
            SoundPlayer.shared.playExpansionSound(soundName: SnippetStore.shared.settings.soundName)
        }
        
        // Inject replacement
        TextInjector.shared.inject(
            text: result.text,
            backspaceCount: match.backspaceCount,
            cursorOffsetFromEnd: result.cursorOffsetFromEnd,
            keyPresses: result.keyPresses,
            delayMs: SnippetStore.shared.settings.expansionDelayMs
        ) {
            // Track statistics
            Task { @MainActor in
                SnippetStore.shared.recordSnippetUsage(
                    snippetId: snippet.id,
                    abbreviationLength: match.backspaceCount,
                    expandedLength: result.text.count
                )
                self.rebuildStatusBarMenu()
            }
        }
    }
    
    // MARK: - Quick Search HUD
    
    public func toggleQuickSearchHUD() {
        if let panel = quickSearchPanel, panel.isVisible {
            panel.orderOut(nil)
            return
        }
        
        targetAppBeforeHUD = NSWorkspace.shared.frontmostApplication
        
        let panel = FocusablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 380),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hasShadow = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.center()
        
        let quickSearchView = QuickSearchView(
            onSelectSnippet: { [weak self] snippet in
                self?.quickSearchPanel?.orderOut(nil)
                self?.insertSnippetFromHUD(snippet)
            },
            onCancel: { [weak self] in
                self?.quickSearchPanel?.orderOut(nil)
            }
        )
        
        panel.contentView = NSHostingView(rootView: quickSearchView)
        self.quickSearchPanel = panel
        
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func insertSnippetFromHUD(_ snippet: Snippet) {
        // Reactivate target application
        targetAppBeforeHUD?.activate()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self = self else { return }
            
            if snippet.hasFillIns {
                let match = SnippetMatch(snippet: snippet, typedAbbreviation: snippet.abbreviation, backspaceCount: 0, keepDelimiter: false)
                self.showFillInModal(snippet: snippet, match: match)
            } else {
                let evaluated = MacroEvaluator.shared.evaluate(snippet: snippet, allSnippets: SnippetStore.shared.snippets)
                
                if SnippetStore.shared.settings.playSoundOnExpansion {
                    SoundPlayer.shared.playExpansionSound(soundName: SnippetStore.shared.settings.soundName)
                }
                
                TextInjector.shared.inject(
                    text: evaluated.text,
                    backspaceCount: 0,
                    cursorOffsetFromEnd: evaluated.cursorOffsetFromEnd,
                    keyPresses: evaluated.keyPresses,
                    delayMs: SnippetStore.shared.settings.expansionDelayMs
                ) {
                    Task { @MainActor in
                        SnippetStore.shared.recordSnippetUsage(
                            snippetId: snippet.id,
                            abbreviationLength: 0,
                            expandedLength: evaluated.text.count
                        )
                        self.rebuildStatusBarMenu()
                    }
                }
            }
        }
    }
    
    // MARK: - Fill-in Modal
    
    private func showFillInModal(snippet: Snippet, match: SnippetMatch) {
        let previousApp = NSWorkspace.shared.frontmostApplication
        
        let panel = FocusablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 420),
            styleMask: [.titled, .closable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "Expandi — Fill in Variables"
        panel.level = .floating
        panel.hasShadow = true
        panel.center()
        
        let dialogView = FillInDialogView(
            snippet: snippet,
            allSnippets: SnippetStore.shared.snippets,
            onConfirm: { [weak self, weak panel] fillInValues in
                panel?.orderOut(nil)
                previousApp?.activate()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    guard let self = self else { return }
                    let evaluated = MacroEvaluator.shared.evaluate(
                        snippet: snippet,
                        fillInValues: fillInValues,
                        allSnippets: SnippetStore.shared.snippets,
                        typedTrigger: match.typedAbbreviation
                    )
                    
                    if SnippetStore.shared.settings.playSoundOnExpansion {
                        SoundPlayer.shared.playExpansionSound(soundName: SnippetStore.shared.settings.soundName)
                    }
                    
                    TextInjector.shared.inject(
                        text: evaluated.text,
                        backspaceCount: match.backspaceCount,
                        cursorOffsetFromEnd: evaluated.cursorOffsetFromEnd,
                        keyPresses: evaluated.keyPresses,
                        delayMs: SnippetStore.shared.settings.expansionDelayMs
                    ) {
                        Task { @MainActor in
                            SnippetStore.shared.recordSnippetUsage(
                                snippetId: snippet.id,
                                abbreviationLength: match.backspaceCount,
                                expandedLength: evaluated.text.count
                            )
                            self.rebuildStatusBarMenu()
                        }
                    }
                }
            },
            onCancel: { [weak panel] in
                panel?.orderOut(nil)
            }
        )
        
        panel.contentView = NSHostingView(rootView: dialogView)
        self.fillInPanel = panel
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
