import Foundation

public enum AppColorScheme: String, Codable, CaseIterable, Sendable {
    case system = "system"
    case light = "light"
    case dark = "dark"
    
    public var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
    
    public var iconName: String {
        switch self {
        case .system: return "laptopcomputer"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
}

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
    public var colorScheme: AppColorScheme
    
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
        hasCompletedOnboarding: Bool = false,
        colorScheme: AppColorScheme = .system
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
        self.colorScheme = colorScheme
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.isExpansionEnabled = try container.decodeIfPresent(Bool.self, forKey: .isExpansionEnabled) ?? true
        self.playSoundOnExpansion = try container.decodeIfPresent(Bool.self, forKey: .playSoundOnExpansion) ?? true
        self.soundName = try container.decodeIfPresent(String.self, forKey: .soundName) ?? "Tink"
        self.expansionDelayMs = try container.decodeIfPresent(Int.self, forKey: .expansionDelayMs) ?? 10
        self.quickSearchHotkey = try container.decodeIfPresent(String.self, forKey: .quickSearchHotkey) ?? "Option+Space"
        self.showMenuBarIcon = try container.decodeIfPresent(Bool.self, forKey: .showMenuBarIcon) ?? true
        self.showDockIcon = try container.decodeIfPresent(Bool.self, forKey: .showDockIcon) ?? true
        self.excludedAppBundleIds = try container.decodeIfPresent([String].self, forKey: .excludedAppBundleIds) ?? ["com.apple.SecurityAgent"]
        self.defaultDelimiterMode = try container.decodeIfPresent(String.self, forKey: .defaultDelimiterMode) ?? "immediate"
        self.defaultCaseSensitivity = try container.decodeIfPresent(String.self, forKey: .defaultCaseSensitivity) ?? "adaptCase"
        self.delimiters = try container.decodeIfPresent([String].self, forKey: .delimiters) ?? [" ", "\t", "\n", ",", ".", ";", ":", "!", "?", "/", "\\", "-", "(", ")", "[", "]", "{", "}"]
        self.hasCompletedOnboarding = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? false
        self.colorScheme = try container.decodeIfPresent(AppColorScheme.self, forKey: .colorScheme) ?? .system
    }
}
