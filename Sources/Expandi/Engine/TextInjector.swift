import Foundation
import AppKit
import CoreGraphics

public final class TextInjector: @unchecked Sendable {
    public static let shared = TextInjector()
    
    /// Flag indicating whether the injector is currently generating synthetic events
    public private(set) var isInjecting = false
    
    private let queue = DispatchQueue(label: "app.expandi.injector", qos: .userInteractive)
    
    public init() {}
    
    public func inject(
        text: String,
        backspaceCount: Int,
        cursorOffsetFromEnd: Int? = nil,
        keyPresses: [String] = [],
        delayMs: Int = 10,
        completion: (@Sendable () -> Void)? = nil
    ) {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.isInjecting = true
            defer {
                // Allow a brief moment before re-enabling buffer capture
                usleep(useconds_t(max(delayMs * 1000, 30_000)))
                self.isInjecting = false
                completion?()
            }
            
            let source = CGEventSource(stateID: .hidSystemState)
            
            // 1. Send backspaces to delete trigger
            if backspaceCount > 0 {
                for _ in 0..<backspaceCount {
                    self.postKey(keyCode: 0x33, flags: [], source: source)
                    usleep(useconds_t(delayMs * 800))
                }
            }
            
            // Brief pause between deletion and paste
            usleep(useconds_t(delayMs * 2000))
            
            // 2. Paste expansion text via pasteboard
            self.pasteText(text: text, source: source, delayMs: delayMs)
            
            // 3. Handle cursor repositioning
            if let offset = cursorOffsetFromEnd, offset > 0 {
                usleep(useconds_t(delayMs * 3000))
                for _ in 0..<offset {
                    self.postKey(keyCode: 0x7B, flags: [], source: source) // Left arrow
                    usleep(useconds_t(1000))
                }
            }
            
            // 4. Handle additional key presses (e.g. Tab, Return)
            if !keyPresses.isEmpty {
                usleep(useconds_t(delayMs * 2000))
                for key in keyPresses {
                    switch key {
                    case "tab":
                        self.postKey(keyCode: 0x30, flags: [], source: source)
                    case "return", "enter":
                        self.postKey(keyCode: 0x24, flags: [], source: source)
                    case "esc", "escape":
                        self.postKey(keyCode: 0x35, flags: [], source: source)
                    default:
                        break
                    }
                    usleep(useconds_t(delayMs * 1000))
                }
            }
        }
    }
    
    private func pasteText(text: String, source: CGEventSource?, delayMs: Int) {
        // Save previous pasteboard content
        let pasteboard = NSPasteboard.general
        let previousString = pasteboard.string(forType: .string)
        
        // Put expansion text onto pasteboard
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        // Synthesize Cmd + V
        postKey(keyCode: 0x09, flags: .maskCommand, source: source)
        
        // Wait for target application to read from pasteboard
        usleep(useconds_t(max(delayMs * 4000, 45_000)))
        
        // Restore previous pasteboard content so user clipboard history remains intact
        if let old = previousString {
            pasteboard.clearContents()
            pasteboard.setString(old, forType: .string)
        }
    }
    
    private func postKey(keyCode: CGKeyCode, flags: CGEventFlags, source: CGEventSource?) {
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            return
        }
        
        down.flags = flags
        up.flags = flags
        
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}
