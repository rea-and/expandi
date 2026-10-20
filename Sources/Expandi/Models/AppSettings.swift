import Foundation

public struct AppSettings: Codable, Sendable {
    public var isExpansionEnabled: Bool
    public var playSoundOnExpansion: Bool
    public var soundName: String
    public var expansionDelayMs: Int
    public var quickSearchHotkey: String
    public var showMenuBarIcon: Bool
    public var showDockIcon: Bool
    public var excludedAppBundleIds: [String]
    public var defaultDelimiterMode: String
    public var defaultCaseSensitivity: String
    public var delimiters: [String]
    public var hasCompletedOnboarding: Bool
    
    public init(
        isExpansionEnabled: Bool = true,
        playSoundOnExpansion: Bool = true,
        soundName: String = "Tink",
        expansionDelayMs: Int = 10,
        quickSearchHotkey: String = "Option+Space",
        showMenuBarIcon: Bool = true,
        showDockIcon: Bool = true,
        excludedAppBundleIds: [String] = ["com.apple.SecurityAgent"],
        defaultDelimiterMode: String = "immediate",
        defaultCaseSensitivity: String = "adaptCase",
        delimiters: [String] = [" ", "\t", "\n", ",", ".", ";", ":", "!", "?", "/", "\\", "-", "(", ")", "[", "]", "{", "}"],
        hasCompletedOnboarding: Bool = false
    ) {
        self.isExpansionEnabled = isExpansionEnabled
        self.playSoundOnExpansion = playSoundOnExpansion
        self.soundName = soundName
        self.expansionDelayMs = expansionDelayMs
        self.quickSearchHotkey = quickSearchHotkey
        self.showMenuBarIcon = showMenuBarIcon
        self.showDockIcon = showDockIcon
        self.excludedAppBundleIds = excludedAppBundleIds
        self.defaultDelimiterMode = defaultDelimiterMode
        self.defaultCaseSensitivity = defaultCaseSensitivity
        self.delimiters = delimiters
        self.hasCompletedOnboarding = hasCompletedOnboarding
    }
}
