import Foundation
import AppKit

public struct MacroEvaluationResult: Sendable {
    public let text: String
    public let cursorOffsetFromEnd: Int?
    public let keyPresses: [String]
    
    public init(text: String, cursorOffsetFromEnd: Int? = nil, keyPresses: [String] = []) {
        self.text = text
        self.cursorOffsetFromEnd = cursorOffsetFromEnd
        self.keyPresses = keyPresses
    }
}

public final class MacroEvaluator: Sendable {
    public static let shared = MacroEvaluator()
    
    public init() {}
    
    // MARK: - Fill-in Extraction
    
    /// Parses snippet content and returns all fill-in fields that require user interaction
    public func extractFillInFields(from content: String) -> [FillInField] {
        var fields: [FillInField] = []
        var seenIds = Set<String>()
        
        let pattern = #"\{\{(fill|multiline|datepicker|choice|opt):([^\}]+)\}\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }
        
        let nsString = content as NSString
        let matches = regex.matches(in: content, options: [], range: NSRange(location: 0, length: nsString.length))
        
        for match in matches {
            guard match.numberOfRanges >= 3 else { continue }
            let kind = nsString.substring(with: match.range(at: 1))
            let rawParams = nsString.substring(with: match.range(at: 2))
            
            switch kind {
            case "fill":
                let (label, defaultValue) = parseLabelAndDefault(rawParams)
                let id = "fill_\(label)"
                if !seenIds.contains(id) {
                    seenIds.insert(id)
                    fields.append(FillInField(id: id, label: label, type: .singleLine, defaultValue: defaultValue))
                }
                
            case "multiline":
                let (label, defaultValue) = parseLabelAndDefault(rawParams)
                let id = "multi_\(label)"
                if !seenIds.contains(id) {
                    seenIds.insert(id)
                    fields.append(FillInField(id: id, label: label, type: .multiLine, defaultValue: defaultValue))
                }
                
            case "datepicker":
                let parts = rawParams.components(separatedBy: ":")
                let label = parts[0].trimmingCharacters(in: .whitespaces)
                var format = "yyyy-MM-dd"
                for part in parts.dropFirst() {
                    let trimmed = part.trimmingCharacters(in: .whitespaces)
                    if trimmed.starts(with: "format=") {
                        format = Self.normalizeDateFormat(String(trimmed.dropFirst("format=".count)))
                    }
                }
                let id = "date_\(label)"
                if !seenIds.contains(id) {
                    seenIds.insert(id)
                    let formatter = DateFormatter()
                    formatter.dateFormat = format
                    let defaultStr = formatter.string(from: Date())
                    fields.append(FillInField(id: id, label: label, type: .datePicker, defaultValue: defaultStr, dateFormat: format))
                }
                
            case "choice":
                let parts = rawParams.components(separatedBy: ":")
                let label = parts[0].trimmingCharacters(in: .whitespaces)
                var options: [String] = []
                var defaultValue = ""
                
                if parts.count > 1 {
                    options = parts[1].components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                }
                
                for part in parts.dropFirst(2) {
                    let trimmed = part.trimmingCharacters(in: .whitespaces)
                    if trimmed.starts(with: "default=") {
                        defaultValue = String(trimmed.dropFirst("default=".count)).trimmingCharacters(in: .whitespaces)
                    }
                }
                if defaultValue.isEmpty, let first = options.first {
                    defaultValue = first
                }
                
                let id = "choice_\(label)"
                if !seenIds.contains(id) {
                    seenIds.insert(id)
                    fields.append(FillInField(id: id, label: label, type: .choice, defaultValue: defaultValue, options: options))
                }
                
            case "opt":
                let parts = rawParams.components(separatedBy: ":")
                let label: String
                let contentText: String
                if parts.count >= 2 {
                    label = parts[0].trimmingCharacters(in: .whitespaces)
                    contentText = parts.dropFirst().joined(separator: ":")
                } else {
                    label = "Include optional section"
                    contentText = rawParams
                }
                
                let id = "opt_\(label)"
                if !seenIds.contains(id) {
                    seenIds.insert(id)
                    fields.append(FillInField(id: id, label: label, type: .optionalSection, defaultValue: "true", optionalContent: contentText))
                }
                
            default:
                break
            }
        }
        
        return fields
    }
    
    private func parseLabelAndDefault(_ raw: String) -> (label: String, defaultValue: String) {
        let parts = raw.components(separatedBy: ":")
        let label = parts[0].trimmingCharacters(in: .whitespaces)
        var defaultValue = ""
        for part in parts.dropFirst() {
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            if trimmed.starts(with: "default=") {
                defaultValue = String(trimmed.dropFirst("default=".count))
            }
        }
        return (label, defaultValue)
    }
    
    // MARK: - Evaluation
    
    public func evaluate(
        snippet: Snippet,
        fillInValues: [String: String] = [:],
        allSnippets: [Snippet] = [],
        typedTrigger: String? = nil,
        depth: Int = 0
    ) -> MacroEvaluationResult {
        guard depth < 6 else {
            return MacroEvaluationResult(text: "[Recursion Limit]")
        }
        
        if snippet.type == .shellScript {
            let output = executeShellCommand(snippet.content)
            return MacroEvaluationResult(text: output)
        } else if snippet.type == .appleScript {
            let output = executeAppleScript(snippet.content)
            return MacroEvaluationResult(text: output)
        }
        
        var text = snippet.content
        var keyPresses: [String] = []
        
        // 1. Nested snippets: {{snippet:abbreviation}}
        let nestedPattern = #"\{\{snippet:([^\}]+)\}\}"#
        if let regex = try? NSRegularExpression(pattern: nestedPattern, options: []) {
            let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: (text as NSString).length))
            for match in matches.reversed() {
                let abbr = (text as NSString).substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces)
                if let targetSnippet = allSnippets.first(where: { $0.abbreviation == abbr && !$0.isDeleted }) {
                    let evaluatedTarget = evaluate(
                        snippet: targetSnippet,
                        fillInValues: fillInValues,
                        allSnippets: allSnippets,
                        depth: depth + 1
                    )
                    text = (text as NSString).replacingCharacters(in: match.range, with: evaluatedTarget.text)
                } else {
                    text = (text as NSString).replacingCharacters(in: match.range, with: "[Snippet '\(abbr)' not found]")
                }
            }
        }
        
        // 2. Shell execution: {{shell:command}}
        let shellPattern = #"\{\{shell:([^\}]+)\}\}"#
        if let regex = try? NSRegularExpression(pattern: shellPattern, options: []) {
            let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: (text as NSString).length))
            for match in matches.reversed() {
                let cmd = (text as NSString).substring(with: match.range(at: 1))
                let output = executeShellCommand(cmd)
                text = (text as NSString).replacingCharacters(in: match.range, with: output)
            }
        }
        
        // 3. AppleScript execution: {{applescript:code}}
        let appleScriptPattern = #"\{\{applescript:([^\}]+)\}\}"#
        if let regex = try? NSRegularExpression(pattern: appleScriptPattern, options: []) {
            let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: (text as NSString).length))
            for match in matches.reversed() {
                let script = (text as NSString).substring(with: match.range(at: 1))
                let output = executeAppleScript(script)
                text = (text as NSString).replacingCharacters(in: match.range, with: output)
            }
        }
        
        // 4. Clipboard: {{clipboard}}
        if text.contains("{{clipboard}}") {
            let clip = NSPasteboard.general.string(forType: .string) ?? ""
            text = text.replacingOccurrences(of: "{{clipboard}}", with: clip)
        }
        
        // 5. Fill-Ins & Multiline & DatePicker & Choice & Opt
        let fillInPattern = #"\{\{(fill|multiline|datepicker|choice|opt):([^\}]+)\}\}"#
        if let regex = try? NSRegularExpression(pattern: fillInPattern, options: []) {
            let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: (text as NSString).length))
            for match in matches.reversed() {
                let kind = (text as NSString).substring(with: match.range(at: 1))
                let rawParams = (text as NSString).substring(with: match.range(at: 2))
                var replacement = ""
                
                switch kind {
                case "fill":
                    let (label, def) = parseLabelAndDefault(rawParams)
                    replacement = fillInValues["fill_\(label)"] ?? (def.isEmpty ? label : def)
                    
                case "multiline":
                    let (label, def) = parseLabelAndDefault(rawParams)
                    replacement = fillInValues["multi_\(label)"] ?? (def.isEmpty ? "" : def)
                    
                case "datepicker":
                    let parts = rawParams.components(separatedBy: ":")
                    let label = parts[0].trimmingCharacters(in: .whitespaces)
                    var format = "yyyy-MM-dd"
                    for part in parts.dropFirst() {
                        let trimmed = part.trimmingCharacters(in: .whitespaces)
                        if trimmed.starts(with: "format=") {
                            format = Self.normalizeDateFormat(String(trimmed.dropFirst("format=".count)))
                        }
                    }
                    if let userVal = fillInValues["date_\(label)"] {
                        replacement = userVal
                    } else {
                        let formatter = DateFormatter()
                        formatter.dateFormat = format
                        replacement = formatter.string(from: Date())
                    }
                    
                case "choice":
                    let parts = rawParams.components(separatedBy: ":")
                    let label = parts[0].trimmingCharacters(in: .whitespaces)
                    var options: [String] = []
                    var def = ""
                    if parts.count > 1 {
                        options = parts[1].components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                    }
                    for part in parts.dropFirst(2) {
                        let trimmed = part.trimmingCharacters(in: .whitespaces)
                        if trimmed.starts(with: "default=") {
                            def = String(trimmed.dropFirst("default=".count)).trimmingCharacters(in: .whitespaces)
                        }
                    }
                    if def.isEmpty, let first = options.first { def = first }
                    replacement = fillInValues["choice_\(label)"] ?? def
                    
                case "opt":
                    let parts = rawParams.components(separatedBy: ":")
                    let label = parts.count >= 2 ? parts[0].trimmingCharacters(in: .whitespaces) : "Include optional section"
                    let optContent = parts.count >= 2 ? parts.dropFirst().joined(separator: ":") : rawParams
                    let isChecked = fillInValues["opt_\(label)"] ?? "true"
                    replacement = (isChecked.lowercased() == "true") ? optContent : ""
                    
                default:
                    break
                }
                
                text = (text as NSString).replacingCharacters(in: match.range, with: replacement)
            }
        }
        
        // 6. Dates and Times
        text = evaluateDateMacros(in: text)
        
        // 7. Simulated Key Presses: {{key:tab}}, {{key:enter}}
        let keyPattern = #"\{\{key:([^\}]+)\}\}"#
        if let regex = try? NSRegularExpression(pattern: keyPattern, options: []) {
            let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: (text as NSString).length))
            for match in matches.reversed() {
                let keyName = (text as NSString).substring(with: match.range(at: 1)).lowercased().trimmingCharacters(in: .whitespaces)
                keyPresses.append(keyName)
                text = (text as NSString).replacingCharacters(in: match.range, with: "")
            }
        }
        
        // 8. Case Adaptation
        if let typed = typedTrigger, snippet.caseSensitivity == .adaptCase {
            text = adaptCase(originalText: text, typedTrigger: typed)
        }
        
        // 9. Cursor repositioning: {{cursor}}
        var cursorOffsetFromEnd: Int? = nil
        if let cursorRange = text.range(of: "{{cursor}}") {
            let utf16Offset = text.distance(from: text.startIndex, to: cursorRange.lowerBound)
            text.removeSubrange(cursorRange)
            cursorOffsetFromEnd = text.count - utf16Offset
        }
        
        return MacroEvaluationResult(
            text: text,
            cursorOffsetFromEnd: cursorOffsetFromEnd,
            keyPresses: keyPresses
        )
    }
    
    // MARK: - Date Macro Evaluation
    
    private func evaluateDateMacros(in original: String) -> String {
        var result = original
        let now = Date()
        let calendar = Calendar.current
        
        // Unix Timestamp: {{timestamp}} or {{time:unix}}
        if result.contains("{{timestamp}}") {
            result = result.replacingOccurrences(of: "{{timestamp}}", with: String(Int(now.timeIntervalSince1970)))
        }
        if result.contains("{{time:unix}}") {
            result = result.replacingOccurrences(of: "{{time:unix}}", with: String(Int(now.timeIntervalSince1970)))
        }
        
        // Simple {{datetime}}
        if result.contains("{{datetime}}") {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            result = result.replacingOccurrences(of: "{{datetime}}", with: formatter.string(from: now))
        }
        
        // Date math offsets: {{date+7d}}, {{date-3d}}, {{date+1m}}, {{date+1y}}, {{date+2w}}, {{date+1bd}}
        let offsetSimplePattern = #"\{\{date([\+\-]\d+[a-z]+)\}\}"#
        if let regex = try? NSRegularExpression(pattern: offsetSimplePattern, options: [.caseInsensitive]) {
            let matches = regex.matches(in: result, options: [], range: NSRange(location: 0, length: (result as NSString).length))
            for match in matches.reversed() {
                let offsetStr = (result as NSString).substring(with: match.range(at: 1))
                let targetDate = applyDateOffset(offsetStr, to: now, calendar: calendar)
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .none
                result = (result as NSString).replacingCharacters(in: match.range, with: formatter.string(from: targetDate))
            }
        }
        
        // Detailed date macro: {{date:...}}
        let datePattern = #"\{\{date(?::([^\}]+))?\}\}"#
        if let regex = try? NSRegularExpression(pattern: datePattern, options: []) {
            let matches = regex.matches(in: result, options: [], range: NSRange(location: 0, length: (result as NSString).length))
            for match in matches.reversed() {
                var format = "yyyy-MM-dd"
                var targetDate = now
                
                if match.numberOfRanges > 1 && match.range(at: 1).location != NSNotFound {
                    let params = (result as NSString).substring(with: match.range(at: 1))
                    
                    if params.contains("=") {
                        let pairs = params.components(separatedBy: ",")
                        for pair in pairs {
                            let kv = pair.components(separatedBy: "=")
                            if kv.count == 2 {
                                let key = kv[0].trimmingCharacters(in: .whitespaces).lowercased()
                                let val = kv[1].trimmingCharacters(in: .whitespaces)
                                if key == "offset" {
                                    targetDate = applyDateOffset(val, to: now, calendar: calendar)
                                } else if key == "format" {
                                    format = Self.normalizeDateFormat(val)
                                }
                            }
                        }
                    } else {
                        format = Self.normalizeDateFormat(params)
                    }
                }
                
                let formatter = DateFormatter()
                formatter.dateFormat = format
                let formatted = formatter.string(from: targetDate)
                result = (result as NSString).replacingCharacters(in: match.range, with: formatted)
            }
        }
        
        // Time macro: {{time}} or {{time:format}}
        let timePattern = #"\{\{time(?::([^\}]+))?\}\}"#
        if let regex = try? NSRegularExpression(pattern: timePattern, options: []) {
            let matches = regex.matches(in: result, options: [], range: NSRange(location: 0, length: (result as NSString).length))
            for match in matches.reversed() {
                var format = "h:mm a"
                var targetDate = now
                
                if match.numberOfRanges > 1 && match.range(at: 1).location != NSNotFound {
                    let params = (result as NSString).substring(with: match.range(at: 1))
                    if params.contains("=") {
                        let pairs = params.components(separatedBy: ",")
                        for pair in pairs {
                            let kv = pair.components(separatedBy: "=")
                            if kv.count == 2 {
                                let key = kv[0].trimmingCharacters(in: .whitespaces).lowercased()
                                let val = kv[1].trimmingCharacters(in: .whitespaces)
                                if key == "offset" {
                                    targetDate = applyDateOffset(val, to: now, calendar: calendar)
                                } else if key == "format" {
                                    format = val
                                }
                            }
                        }
                    } else if !params.isEmpty {
                        format = params
                    }
                }
                let formatter = DateFormatter()
                formatter.dateFormat = format
                let formatted = formatter.string(from: targetDate)
                result = (result as NSString).replacingCharacters(in: match.range, with: formatted)
            }
        }
        
        // Support strftime date tokens fallback if present (%B, %d, %Y, %H, %M, etc.)
        if result.contains("%") {
            let strftimeMap: [(pattern: String, dateFormat: String)] = [
                ("%B", "MMMM"),
                ("%b", "MMM"),
                ("%A", "EEEE"),
                ("%a", "EEE"),
                ("%Y", "yyyy"),
                ("%y", "yy"),
                ("%m", "MM"),
                ("%d", "dd"),
                ("%e", "d"),
                ("%H", "HH"),
                ("%I", "hh"),
                ("%M", "mm"),
                ("%S", "ss"),
                ("%p", "a")
            ]
            for item in strftimeMap {
                if result.contains(item.pattern) {
                    let f = DateFormatter()
                    f.dateFormat = item.dateFormat
                    result = result.replacingOccurrences(of: item.pattern, with: f.string(from: now))
                }
            }
        }
        
        return result
    }
    
    public static func normalizeDateFormat(_ format: String) -> String {
        var norm = format
        norm = norm.replacingOccurrences(of: "YYYY", with: "yyyy")
        norm = norm.replacingOccurrences(of: "DD", with: "dd")
        return norm
    }
    
    private func applyDateOffset(_ offsetStr: String, to baseDate: Date, calendar: Calendar) -> Date {
        let trimmed = offsetStr.trimmingCharacters(in: .whitespaces).lowercased()
        guard trimmed.count >= 2 else { return baseDate }
        
        let sign = trimmed.starts(with: "-") ? -1 : 1
        let cleaned = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "+-"))
        
        // Business days: e.g. "1bd", "5bd"
        if cleaned.hasSuffix("bd") {
            let amountStr = cleaned.dropLast(2)
            if let amount = Int(amountStr) {
                var current = baseDate
                var daysRemaining = abs(amount)
                let step = sign
                while daysRemaining > 0 {
                    current = calendar.date(byAdding: .day, value: step, to: current) ?? current
                    let weekday = calendar.component(.weekday, from: current) // 1 = Sun, 7 = Sat
                    if weekday != 1 && weekday != 7 {
                        daysRemaining -= 1
                    }
                }
                return current
            }
        }
        
        // Minutes
        if cleaned.hasSuffix("min") {
            if let amount = Int(cleaned.dropLast(3)) {
                return calendar.date(byAdding: .minute, value: sign * amount, to: baseDate) ?? baseDate
            }
        }
        
        guard let unitChar = cleaned.last, let amount = Int(cleaned.dropLast()) else { return baseDate }
        let value = sign * amount
        switch unitChar {
        case "d":
            return calendar.date(byAdding: .day, value: value, to: baseDate) ?? baseDate
        case "w":
            return calendar.date(byAdding: .day, value: value * 7, to: baseDate) ?? baseDate
        case "m":
            return calendar.date(byAdding: .month, value: value, to: baseDate) ?? baseDate
        case "y":
            return calendar.date(byAdding: .year, value: value, to: baseDate) ?? baseDate
        case "h":
            return calendar.date(byAdding: .hour, value: value, to: baseDate) ?? baseDate
        default:
            return baseDate
        }
    }
    
    // MARK: - Case Adaptation
    
    private func adaptCase(originalText: String, typedTrigger: String) -> String {
        let lettersOnly = typedTrigger.filter { $0.isLetter }
        guard !lettersOnly.isEmpty else { return originalText }
        
        if lettersOnly.allSatisfy({ $0.isUppercase }) {
            return originalText.uppercased()
        } else if let first = lettersOnly.first, first.isUppercase {
            guard let firstChar = originalText.first else { return originalText }
            return String(firstChar).uppercased() + originalText.dropFirst()
        }
        
        return originalText
    }
    
    // MARK: - Script Execution
    
    private func executeShellCommand(_ command: String) -> String {
        let process = Process()
        let pipe = Pipe()
        
        process.standardOutput = pipe
        process.standardError = pipe
        process.arguments = ["-c", command]
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return output.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return "[Shell Execution Error: \(error.localizedDescription)]"
        }
    }
    
    private func executeAppleScript(_ script: String) -> String {
        var errorDict: NSDictionary?
        let appleScript = NSAppleScript(source: script)
        let resultDescriptor = appleScript?.executeAndReturnError(&errorDict)
        
        if let error = errorDict {
            let message = error[NSAppleScript.errorMessage] as? String ?? "AppleScript Error"
            return "[\(message)]"
        }
        
        return resultDescriptor?.stringValue ?? ""
    }
}
