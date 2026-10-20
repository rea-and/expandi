import Foundation
import AppKit
import CoreGraphics
import ApplicationServices

public struct SnippetMatch: Sendable {
    public let snippet: Snippet
    public let typedAbbreviation: String
    public let backspaceCount: Int
    public let keepDelimiter: Bool
}

public protocol KeyboardMonitorDelegate: AnyObject, Sendable {
    func keyboardMonitorDidMatchSnippet(_ match: SnippetMatch)
}

public final class KeyboardMonitor: @unchecked Sendable {
    public static let shared = KeyboardMonitor()
    
    public weak var delegate: KeyboardMonitorDelegate?
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var globalNSEventMonitor: Any?
    
    private var buffer = ""
    private let bufferLock = NSLock()
    private let maxBufferSize = 80
    
    public private(set) var isMonitoring = false
    public private(set) var isAccessibilityGranted = false
    
    // Cached snapshot of active snippets & settings for lightning-fast matching inside the tap callback
    private var cachedSnippets: [Snippet] = []
    private var cachedGroups: [SnippetGroup] = []
    private var cachedSettings: AppSettings = AppSettings()
    private let cacheLock = NSLock()
    
    public init() {
        checkAccessibilityPermissions()
        setupAppSwitchObserver()
    }
    
    // MARK: - Snapshot Sync
    
    public func updateCache(snippets: [Snippet], groups: [SnippetGroup], settings: AppSettings) {
        cacheLock.lock()
        self.cachedSnippets = snippets
        self.cachedGroups = groups
        self.cachedSettings = settings
        cacheLock.unlock()
    }
    
    // MARK: - Permissions
    
    @discardableResult
    public func checkAccessibilityPermissions(promptIfNeeded: Bool = false) -> Bool {
        let promptKey = "AXTrustedCheckOptionPrompt" as CFString
        let options = [promptKey: promptIfNeeded] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        self.isAccessibilityGranted = trusted
        return trusted
    }
    
    public func promptForAccessibility() {
        checkAccessibilityPermissions(promptIfNeeded: true)
    }
    
    public func openSystemSettingsAccessibility() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
    
    // MARK: - Lifecycle
    
    public func start() {
        guard !isMonitoring else { return }
        checkAccessibilityPermissions()
        
        startEventTap()
        startNSEventFallback()
        isMonitoring = true
    }
    
    public func stop() {
        guard isMonitoring else { return }
        stopEventTap()
        stopNSEventFallback()
        isMonitoring = false
    }
    
    public func clearBuffer() {
        bufferLock.lock()
        buffer.removeAll()
        bufferLock.unlock()
    }
    
    private func setupAppSwitchObserver() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.clearBuffer()
        }
    }
    
    // MARK: - CGEventTap
    
    private func startEventTap() {
        let eventMask = (1 << CGEventType.keyDown.rawValue)
        let observer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }
                let monitor = Unmanaged<KeyboardMonitor>.fromOpaque(refcon).takeUnretainedValue()
                return monitor.handleEventTap(proxy: proxy, type: type, event: event)
            },
            userInfo: observer
        ) else {
            return
        }
        
        self.eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }
    
    private func stopEventTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
                self.runLoopSource = nil
            }
            self.eventTap = nil
        }
    }
    
    private func handleEventTap(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passRetained(event)
        }
        
        guard type == .keyDown else {
            return Unmanaged.passRetained(event)
        }
        
        // Skip keystrokes synthesized by Expandi's text injector
        if TextInjector.shared.isInjecting {
            return Unmanaged.passRetained(event)
        }
        
        let flags = event.flags
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        
        // If Cmd or Ctrl is held down, clear buffer (shortcuts like Cmd+C, Cmd+V shouldn't trigger snippets)
        if flags.contains(.maskCommand) || flags.contains(.maskControl) {
            clearBuffer()
            return Unmanaged.passRetained(event)
        }
        
        // Handle Backspace (keyCode 51)
        if keyCode == 51 {
            bufferLock.lock()
            if !buffer.isEmpty {
                buffer.removeLast()
            }
            bufferLock.unlock()
            return Unmanaged.passRetained(event)
        }
        
        // Handle Escape (keyCode 53), Arrows (123...126)
        if keyCode == 53 || (keyCode >= 123 && keyCode <= 126) {
            clearBuffer()
            return Unmanaged.passRetained(event)
        }
        
        // Extract Unicode string from event
        var length = 0
        event.keyboardGetUnicodeString(maxStringLength: 0, actualStringLength: &length, unicodeString: nil)
        guard length > 0 else { return Unmanaged.passRetained(event) }
        
        var chars = [UniChar](repeating: 0, count: length)
        event.keyboardGetUnicodeString(maxStringLength: length, actualStringLength: &length, unicodeString: &chars)
        let typedString = String(utf16CodeUnits: chars, count: length)
        
        guard !typedString.isEmpty else { return Unmanaged.passRetained(event) }
        
        // Append typed characters to buffer
        bufferLock.lock()
        buffer.append(typedString)
        if buffer.count > maxBufferSize {
            buffer = String(buffer.suffix(maxBufferSize))
        }
        let currentBuffer = buffer
        bufferLock.unlock()
        
        // Check for matching snippets
        if let match = checkForMatch(in: currentBuffer, lastTyped: typedString) {
            clearBuffer()
            delegate?.keyboardMonitorDidMatchSnippet(match)
        }
        
        return Unmanaged.passRetained(event)
    }
    
    // MARK: - NSEvent Fallback Monitor
    
    private func startNSEventFallback() {
        globalNSEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self = self else { return }
            if self.eventTap == nil {
                self.processNSEvent(event)
            }
        }
    }
    
    private func stopNSEventFallback() {
        if let monitor = globalNSEventMonitor {
            NSEvent.removeMonitor(monitor)
            globalNSEventMonitor = nil
        }
    }
    
    private func processNSEvent(_ event: NSEvent) {
        if TextInjector.shared.isInjecting { return }
        if event.modifierFlags.contains(.command) || event.modifierFlags.contains(.control) {
            clearBuffer()
            return
        }
        if event.keyCode == 51 {
            bufferLock.lock()
            if !buffer.isEmpty { buffer.removeLast() }
            bufferLock.unlock()
            return
        }
        if event.keyCode == 53 || (event.keyCode >= 123 && event.keyCode <= 126) {
            clearBuffer()
            return
        }
        guard let chars = event.characters, !chars.isEmpty else { return }
        
        bufferLock.lock()
        buffer.append(chars)
        if buffer.count > maxBufferSize {
            buffer = String(buffer.suffix(maxBufferSize))
        }
        let currentBuffer = buffer
        bufferLock.unlock()
        
        if let match = checkForMatch(in: currentBuffer, lastTyped: chars) {
            clearBuffer()
            delegate?.keyboardMonitorDidMatchSnippet(match)
        }
    }
    
    // MARK: - Matching Logic
    
    private func checkForMatch(in currentBuffer: String, lastTyped: String) -> SnippetMatch? {
        cacheLock.lock()
        let settings = self.cachedSettings
        let snippets = self.cachedSnippets
        let groups = self.cachedGroups
        cacheLock.unlock()
        
        guard settings.isExpansionEnabled else { return nil }
        
        // Check frontmost app exclusion
        if let frontmostApp = NSWorkspace.shared.frontmostApplication?.bundleIdentifier {
            if settings.excludedAppBundleIds.contains(frontmostApp) {
                return nil
            }
        }
        
        let groupsMap = Dictionary(uniqueKeysWithValues: groups.map { ($0.id, $0) })
        let delimiters = settings.delimiters
        let isLastCharDelimiter = delimiters.contains(lastTyped)
        
        for snippet in snippets {
            guard !snippet.isDeleted else { continue }
            guard let group = groupsMap[snippet.groupId], group.isEnabled else { continue }
            
            if let frontmostApp = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
               group.excludedApps.contains(frontmostApp) {
                continue
            }
            
            let fullAbbr = snippet.effectiveAbbreviation(withGroupPrefix: group.prefix)
            guard !fullAbbr.isEmpty else { continue }
            
            switch snippet.delimiterMode {
            case .immediate:
                if let match = matchAbbreviation(fullAbbr: fullAbbr, in: currentBuffer, caseSensitivity: snippet.caseSensitivity) {
                    return SnippetMatch(
                        snippet: snippet,
                        typedAbbreviation: match.matchedString,
                        backspaceCount: match.matchedString.count,
                        keepDelimiter: false
                    )
                }
                
            case .afterDelimiter(let keepDelimiter):
                if isLastCharDelimiter {
                    let bufferWithoutDelimiter = String(currentBuffer.dropLast(lastTyped.count))
                    if let match = matchAbbreviation(fullAbbr: fullAbbr, in: bufferWithoutDelimiter, caseSensitivity: snippet.caseSensitivity) {
                        return SnippetMatch(
                            snippet: snippet,
                            typedAbbreviation: match.matchedString,
                            backspaceCount: keepDelimiter ? match.matchedString.count : (match.matchedString.count + lastTyped.count),
                            keepDelimiter: keepDelimiter
                        )
                    }
                }
            }
        }
        
        return nil
    }
    
    private func matchAbbreviation(
        fullAbbr: String,
        in buffer: String,
        caseSensitivity: CaseSensitivity
    ) -> (matchedString: String, length: Int)? {
        guard buffer.count >= fullAbbr.count else { return nil }
        let suffix = String(buffer.suffix(fullAbbr.count))
        
        switch caseSensitivity {
        case .exactMatch:
            if suffix == fullAbbr {
                return (suffix, fullAbbr.count)
            }
        case .adaptCase, .ignoreCase:
            if suffix.caseInsensitiveCompare(fullAbbr) == .orderedSame {
                return (suffix, fullAbbr.count)
            }
        }
        
        return nil
    }
}
