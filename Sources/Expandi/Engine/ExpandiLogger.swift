import Foundation

public final class ExpandiLogger: @unchecked Sendable {
    public static let shared = ExpandiLogger()
    private let logURL = URL(fileURLWithPath: "/tmp/expandi_debug.log")
    private let lock = NSLock()
    
    public init() {}
    
    public func log(_ message: String) {
        lock.lock()
        defer { lock.unlock() }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        let timestamp = formatter.string(from: Date())
        let line = "[\(timestamp)] \(message)\n"
        
        NSLog("Expandi: %@", message)
        
        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logURL.path) {
                if let handle = try? FileHandle(forWritingTo: logURL) {
                    handle.seekToEndOfFile()
                    handle.write(data)
                    try? handle.close()
                }
            } else {
                try? data.write(to: logURL)
            }
        }
    }
}

public func logExpandi(_ message: String) {
    ExpandiLogger.shared.log(message)
}
