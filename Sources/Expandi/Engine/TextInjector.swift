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
            logExpandi("TextInjector: Starting injection (backspaces=\(backspaceCount), textLen=\(text.count), cursorOffset=\(String(describing: cursorOffsetFromEnd)))")
            
            defer {
                // Allow a brief moment before re-enabling buffer capture
                usleep(useconds_t(max(delayMs * 1500, 40_000)))
                self.isInjecting = false
                logExpandi("TextInjector: Finished injection")
                completion?()
            }
            
            let source = CGEventSource(stateID: .combinedSessionState)
            
            // 1. Send EXACT number of backspaces to delete the trigger abbreviation
            if backspaceCount > 0 {
                for _ in 0..<backspaceCount {
                    self.postBackspace(source: source)
                    usleep(useconds_t(max(delayMs * 800, 6_000)))
                }
            }
            
            // 2. Pause to allow the active text editor to update its caret position
            usleep(useconds_t(max(delayMs * 3000, 35_000)))
            
            // 3. Paste the expansion text via pasteboard
            self.pasteText(text: text, source: source, delayMs: delayMs)
            
            // 4. Handle cursor repositioning if {{cursor}} macro was present
            if let offset = cursorOffsetFromEnd, offset > 0 {
                usleep(useconds_t(max(delayMs * 3000, 40_000)))
                for _ in 0..<offset {
                    self.postKey(keyCode: 0x7B, flags: [], source: source) // Left arrow
                    usleep(useconds_t(2000))
                }
            }
            
            // 5. Handle additional simulated key presses (e.g. Tab, Return)
            if !keyPresses.isEmpty {
                usleep(useconds_t(max(delayMs * 2000, 25_000)))
                for key in keyPresses {
                    switch key.lowercased() {
                    case "tab":
                        self.postKey(keyCode: 0x30, flags: [], source: source)
                    case "return", "enter":
                        self.postKey(keyCode: 0x24, flags: [], source: source)
                    case "esc", "escape":
                        self.postKey(keyCode: 0x35, flags: [], source: source)
                    default:
                        break
                    }
                    usleep(useconds_t(max(delayMs * 1000, 10_000)))
                }
            }
        }
    }
    
    // MARK: - Clipboard Paste Injection
    
    private func pasteText(text: String, source: CGEventSource?, delayMs: Int) {
        let pasteboard = NSPasteboard.general
        let previousString = pasteboard.string(forType: .string)
        
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        // Post Cmd+V sequence cleanly to hardware event stream
        postCmdV(source: source)
        
        // Restore previous pasteboard content safely after target app has read it (0.6s)
        if let old = previousString, old != text {
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.6) {
                if NSPasteboard.general.string(forType: .string) == text {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(old, forType: .string)
                }
            }
        }
    }
    
    // MARK: - Synthetic Key Events
    
    private func postBackspace(source: CGEventSource?) {
        // Virtual key 0x33 is Delete / Backspace
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: 0x33, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 0x33, keyDown: false) else {
            return
        }
        down.flags = []
        up.flags = []
        
        // Post exactly once to the system hardware event tap
        down.post(tap: .cghidEventTap)
        usleep(1_500)
        up.post(tap: .cghidEventTap)
    }
    
    private func postCmdV(source: CGEventSource?) {
        // 1. Command down (virtual key 0x37 = Left Command)
        if let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true) {
            cmdDown.flags = .maskCommand
            cmdDown.post(tap: .cghidEventTap)
        }
        usleep(4_000)
        
        // 2. 'V' down (virtual key 0x09 = 'V')
        if let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) {
            vDown.flags = .maskCommand
            vDown.post(tap: .cghidEventTap)
        }
        usleep(12_000)
        
        // 3. 'V' up
        if let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false) {
            vUp.flags = .maskCommand
            vUp.post(tap: .cghidEventTap)
        }
        usleep(4_000)
        
        // 4. Command up
        if let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false) {
            cmdUp.flags = []
            cmdUp.post(tap: .cghidEventTap)
        }
    }
    
    private func postKey(keyCode: CGKeyCode, flags: CGEventFlags, source: CGEventSource?) {
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            return
        }
        
        down.flags = flags
        up.flags = flags
        
        // Post exactly once to system hardware event tap
        down.post(tap: .cghidEventTap)
        usleep(2_000)
        up.post(tap: .cghidEventTap)
    }
}
