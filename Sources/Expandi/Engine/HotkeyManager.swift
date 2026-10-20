import Foundation
import AppKit
import Carbon

public final class HotkeyManager: @unchecked Sendable {
    public static let shared = HotkeyManager()
    
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var action: (@Sendable () -> Void)?
    
    public init() {}
    
    public func register(shortcut: String, action: @escaping @Sendable () -> Void) {
        unregister()
        self.action = action
        
        let (keyCode, modifiers) = parseShortcut(shortcut)
        let hotKeyID = EventHotKeyID(signature: OSType(0x45585044), id: 1) // "EXPD"
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        let handlerCallback: EventHandlerUPP = { (_, event, _) -> OSStatus in
            HotkeyManager.shared.handleHotKey()
            return noErr
        }
        
        InstallEventHandler(GetApplicationEventTarget(), handlerCallback, 1, &eventType, nil, &eventHandler)
        RegisterEventHotKey(UInt32(keyCode), modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }
    
    public func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
    }
    
    private func handleHotKey() {
        DispatchQueue.main.async { [weak self] in
            self?.action?()
        }
    }
    
    private func parseShortcut(_ shortcut: String) -> (keyCode: Int, modifiers: UInt32) {
        var modifiers: UInt32 = 0
        let parts = shortcut.components(separatedBy: "+").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        var key = "space"
        
        for part in parts {
            switch part {
            case "cmd", "command":
                modifiers |= UInt32(cmdKey)
            case "option", "alt", "opt":
                modifiers |= UInt32(optionKey)
            case "shift":
                modifiers |= UInt32(shiftKey)
            case "control", "ctrl":
                modifiers |= UInt32(controlKey)
            default:
                key = part
            }
        }
        
        let keyCode: Int
        switch key {
        case "space": keyCode = kVK_Space
        case "e": keyCode = kVK_ANSI_E
        case "s": keyCode = kVK_ANSI_S
        case "k": keyCode = kVK_ANSI_K
        case "f": keyCode = kVK_ANSI_F
        case "t": keyCode = kVK_ANSI_T
        case "return", "enter": keyCode = kVK_Return
        default: keyCode = kVK_Space
        }
        
        return (keyCode, modifiers)
    }
}
