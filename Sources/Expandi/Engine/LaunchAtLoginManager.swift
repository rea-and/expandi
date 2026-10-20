import Foundation
import ServiceManagement

@MainActor
public final class LaunchAtLoginManager: Sendable {
    public static let shared = LaunchAtLoginManager()
    
    public init() {}
    
    public var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }
    
    public func setEnabled(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                        logExpandi("LaunchAtLoginManager: Registered mainApp for login launch successfully")
                    }
                } else {
                    if SMAppService.mainApp.status == .enabled {
                        try SMAppService.mainApp.unregister()
                        logExpandi("LaunchAtLoginManager: Unregistered mainApp from login launch successfully")
                    }
                }
            } catch {
                logExpandi("LaunchAtLoginManager: Failed to update login item status: \(error)")
            }
        }
    }
    
    public func syncWithSettings() {
        let desired = SnippetStore.shared.settings.launchAtLogin
        setEnabled(desired)
    }
}
