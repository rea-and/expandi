import Foundation

public enum ImportResolutionMode: String, CaseIterable, Sendable {
    case keepBoth = "Keep Both (Create Copy)"
    case overwrite = "Overwrite Existing"
    case skipDuplicates = "Skip Duplicates"
}

public struct ImportResult: Sendable {
    public let snippetsImported: Int
    public let groupsImported: Int
    public let duplicatesSkipped: Int
    
    public init(snippetsImported: Int, groupsImported: Int, duplicatesSkipped: Int) {
        self.snippetsImported = snippetsImported
        self.groupsImported = groupsImported
        self.duplicatesSkipped = duplicatesSkipped
    }
}

public final class Importer: Sendable {
    public static let shared = Importer()
    
    public init() {}
    
    // MARK: - JSON Import
    
    public func importJSON(
        data: Data,
        into existingGroups: inout [SnippetGroup],
        existingSnippets: inout [Snippet],
        resolutionMode: ImportResolutionMode
    ) throws -> ImportResult {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        var importedSnippets: [Snippet] = []
        var importedGroups: [SnippetGroup] = []
        
        if let package = try? decoder.decode(ExpandiPackage.self, from: data) {
            importedGroups = package.groups
            importedSnippets = package.snippets
        } else if let snippetsOnly = try? decoder.decode([Snippet].self, from: data) {
            importedSnippets = snippetsOnly
        } else {
            throw NSError(domain: "Expandi", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON format"])
        }
        
        var groupMap: [UUID: UUID] = [:]
        var groupsAdded = 0
        
        for impGroup in importedGroups {
            if let existing = existingGroups.first(where: { $0.name.lowercased() == impGroup.name.lowercased() }) {
                groupMap[impGroup.id] = existing.id
            } else {
                var newGroup = impGroup
                newGroup.id = UUID()
                groupMap[impGroup.id] = newGroup.id
                existingGroups.append(newGroup)
                groupsAdded += 1
            }
        }
        
        let defaultGroupId = existingGroups.first?.id ?? UUID()
        var snippetsAdded = 0
        var skipped = 0
        
        for var snippet in importedSnippets {
            let targetGroupId = groupMap[snippet.groupId] ?? defaultGroupId
            snippet.groupId = targetGroupId
            
            if let existingIndex = existingSnippets.firstIndex(where: { $0.abbreviation == snippet.abbreviation && !$0.isDeleted }) {
                switch resolutionMode {
                case .skipDuplicates:
                    skipped += 1
                    continue
                case .overwrite:
                    snippet.id = existingSnippets[existingIndex].id
                    snippet.updatedAt = Date()
                    existingSnippets[existingIndex] = snippet
                    snippetsAdded += 1
                case .keepBoth:
                    snippet.id = UUID()
                    snippet.title = "\(snippet.title) (Imported)"
                    snippet.abbreviation = "\(snippet.abbreviation)_imp"
                    snippet.updatedAt = Date()
                    existingSnippets.append(snippet)
                    snippetsAdded += 1
                }
            } else {
                snippet.id = UUID()
                existingSnippets.append(snippet)
                snippetsAdded += 1
            }
        }
        
        return ImportResult(snippetsImported: snippetsAdded, groupsImported: groupsAdded, duplicatesSkipped: skipped)
    }
    
    // MARK: - CSV Import
    
    public func importCSV(
        csvString: String,
        defaultGroupName: String = "Imported",
        into existingGroups: inout [SnippetGroup],
        existingSnippets: inout [Snippet],
        resolutionMode: ImportResolutionMode
    ) -> ImportResult {
        let cleanedCSV = csvString.trimmingCharacters(in: CharacterSet(charactersIn: "\u{FEFF}"))
        let rows = parseCSV(cleanedCSV)
        guard !rows.isEmpty else {
            return ImportResult(snippetsImported: 0, groupsImported: 0, duplicatesSkipped: 0)
        }
        
        let firstRow = rows[0].map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
        let isHeadered = firstRow.contains("abbreviation") || firstRow.contains("content") || firstRow.contains("title")
        
        if isHeadered {
            return importHeaderedCSV(
                rows: rows,
                defaultGroupName: defaultGroupName,
                into: &existingGroups,
                existingSnippets: &existingSnippets,
                resolutionMode: resolutionMode
            )
        } else {
            // Standard 3-column CSV format: [Abbreviation, Content, Label]
            return importThreeColumnCSV(
                rows: rows,
                groupName: defaultGroupName,
                into: &existingGroups,
                existingSnippets: &existingSnippets,
                resolutionMode: resolutionMode
            )
        }
    }
    
    private func importThreeColumnCSV(
        rows: [[String]],
        groupName: String,
        into existingGroups: inout [SnippetGroup],
        existingSnippets: inout [Snippet],
        resolutionMode: ImportResolutionMode
    ) -> ImportResult {
        let group: SnippetGroup
        var groupsAdded = 0
        if let found = existingGroups.first(where: { $0.name.lowercased() == groupName.lowercased() }) {
            group = found
        } else {
            let newGroup = SnippetGroup(name: groupName, iconName: "folder.fill", prefix: ";")
            existingGroups.append(newGroup)
            group = newGroup
            groupsAdded += 1
        }
        
        var snippetsAdded = 0
        var skipped = 0
        var autoIndex = 1
        
        for row in rows {
            guard !row.isEmpty else { continue }
            var rawAbbr = row.count > 0 ? row[0].trimmingCharacters(in: .whitespaces) : ""
            let rawContent = row.count > 1 ? row[1] : ""
            var rawTitle = row.count > 2 ? row[2].trimmingCharacters(in: .whitespaces) : ""
            
            // Skip entirely empty rows
            if rawAbbr.isEmpty && rawContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && rawTitle.isEmpty {
                continue
            }
            
            if rawAbbr.isEmpty {
                if rawTitle.isEmpty {
                    let firstLine = rawContent
                        .components(separatedBy: .newlines)
                        .map { $0.trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: "*#-_"))) }
                        .first { !$0.isEmpty } ?? "Snippet \(autoIndex)"
                    rawTitle = String(firstLine.prefix(40))
                }
                
                let cleanWord = rawTitle
                    .filter { $0.isLetter || $0.isNumber }
                    .lowercased()
                rawAbbr = cleanWord.isEmpty ? ";snip\(autoIndex)" : ";\(cleanWord.prefix(8))"
                autoIndex += 1
            }
            
            if rawTitle.isEmpty {
                rawTitle = rawAbbr
            }
            
            let convertedContent = convertLegacyMacros(rawContent)
            let isFormatted = rawContent.contains("<span") || rawContent.contains("<div") || rawContent.contains("<br")
            let snippetType: SnippetType = isFormatted ? .formatted : .plainText
            
            if let existingIndex = existingSnippets.firstIndex(where: { $0.abbreviation == rawAbbr && !$0.isDeleted }) {
                switch resolutionMode {
                case .skipDuplicates:
                    skipped += 1
                    continue
                case .overwrite:
                    existingSnippets[existingIndex].title = rawTitle
                    existingSnippets[existingIndex].content = convertedContent
                    existingSnippets[existingIndex].groupId = group.id
                    existingSnippets[existingIndex].type = snippetType
                    existingSnippets[existingIndex].updatedAt = Date()
                    snippetsAdded += 1
                case .keepBoth:
                    let newSnippet = Snippet(
                        title: "\(rawTitle) (Copy)",
                        abbreviation: "\(rawAbbr)_imp",
                        content: convertedContent,
                        groupId: group.id,
                        type: snippetType
                    )
                    existingSnippets.append(newSnippet)
                    snippetsAdded += 1
                }
            } else {
                let newSnippet = Snippet(
                    title: rawTitle,
                    abbreviation: rawAbbr,
                    content: convertedContent,
                    groupId: group.id,
                    type: snippetType
                )
                existingSnippets.append(newSnippet)
                snippetsAdded += 1
            }
        }
        
        return ImportResult(snippetsImported: snippetsAdded, groupsImported: groupsAdded, duplicatesSkipped: skipped)
    }
    
    private func importHeaderedCSV(
        rows: [[String]],
        defaultGroupName: String,
        into existingGroups: inout [SnippetGroup],
        existingSnippets: inout [Snippet],
        resolutionMode: ImportResolutionMode
    ) -> ImportResult {
        let headers = rows[0].map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
        let abbrIdx = headers.firstIndex(of: "abbreviation") ?? 0
        let titleIdx = headers.firstIndex(of: "title") ?? 1
        let contentIdx = headers.firstIndex(of: "content") ?? 2
        let groupIdx = headers.firstIndex(of: "group")
        let tagsIdx = headers.firstIndex(of: "tags")
        let typeIdx = headers.firstIndex(of: "type")
        let delimIdx = headers.firstIndex(of: "delimitermode")
        let caseIdx = headers.firstIndex(of: "casesensitivity")
        let notesIdx = headers.firstIndex(of: "notes")
        
        var groupsAdded = 0
        var snippetsAdded = 0
        var skipped = 0
        
        for row in rows.dropFirst() {
            guard row.count > max(abbrIdx, titleIdx, contentIdx) else { continue }
            let abbr = row[abbrIdx].trimmingCharacters(in: .whitespaces)
            let title = row[titleIdx].trimmingCharacters(in: .whitespaces)
            let rawContent = row[contentIdx]
            guard !abbr.isEmpty, !rawContent.isEmpty else { continue }
            
            let groupName = (groupIdx != nil && row.count > groupIdx!) ? row[groupIdx!].trimmingCharacters(in: .whitespaces) : defaultGroupName
            let finalGroupName = groupName.isEmpty ? defaultGroupName : groupName
            
            let group: SnippetGroup
            if let found = existingGroups.first(where: { $0.name.lowercased() == finalGroupName.lowercased() }) {
                group = found
            } else {
                let newGroup = SnippetGroup(name: finalGroupName, iconName: "folder.fill", prefix: ";")
                existingGroups.append(newGroup)
                group = newGroup
                groupsAdded += 1
            }
            
            var tags: [String] = []
            if let tIdx = tagsIdx, row.count > tIdx {
                tags = row[tIdx].components(separatedBy: CharacterSet(charactersIn: ";,")).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            }
            
            var type: SnippetType = .plainText
            if let tyIdx = typeIdx, row.count > tyIdx {
                type = SnippetType(rawValue: row[tyIdx].lowercased()) ?? .plainText
            }
            
            var delimMode: DelimiterMode = .immediate
            if let dIdx = delimIdx, row.count > dIdx {
                if row[dIdx].lowercased().contains("delim") {
                    delimMode = .afterDelimiter(keepDelimiter: true)
                }
            }
            
            var caseMode: CaseSensitivity = .adaptCase
            if let cIdx = caseIdx, row.count > cIdx {
                caseMode = CaseSensitivity(rawValue: row[cIdx].lowercased()) ?? .adaptCase
            }
            
            let notes = (notesIdx != nil && row.count > notesIdx!) ? row[notesIdx!] : ""
            let convertedContent = convertLegacyMacros(rawContent)
            
            if let existingIndex = existingSnippets.firstIndex(where: { $0.abbreviation == abbr && !$0.isDeleted }) {
                switch resolutionMode {
                case .skipDuplicates:
                    skipped += 1
                    continue
                case .overwrite:
                    existingSnippets[existingIndex].title = title
                    existingSnippets[existingIndex].content = convertedContent
                    existingSnippets[existingIndex].groupId = group.id
                    existingSnippets[existingIndex].tags = tags
                    existingSnippets[existingIndex].type = type
                    existingSnippets[existingIndex].delimiterMode = delimMode
                    existingSnippets[existingIndex].caseSensitivity = caseMode
                    existingSnippets[existingIndex].notes = notes
                    existingSnippets[existingIndex].updatedAt = Date()
                    snippetsAdded += 1
                case .keepBoth:
                    let newSnippet = Snippet(
                        title: "\(title) (Copy)",
                        abbreviation: "\(abbr)_imp",
                        content: convertedContent,
                        notes: notes,
                        groupId: group.id,
                        tags: tags,
                        type: type,
                        delimiterMode: delimMode,
                        caseSensitivity: caseMode
                    )
                    existingSnippets.append(newSnippet)
                    snippetsAdded += 1
                }
            } else {
                let newSnippet = Snippet(
                    title: title.isEmpty ? abbr : title,
                    abbreviation: abbr,
                    content: convertedContent,
                    notes: notes,
                    groupId: group.id,
                    tags: tags,
                    type: type,
                    delimiterMode: delimMode,
                    caseSensitivity: caseMode
                )
                existingSnippets.append(newSnippet)
                snippetsAdded += 1
            }
        }
        
        return ImportResult(snippetsImported: snippetsAdded, groupsImported: groupsAdded, duplicatesSkipped: skipped)
    }
    
    // MARK: - Legacy Macro Conversion
    
    public func convertLegacyMacros(_ text: String) -> String {
        var result = text
        
        // 1. %filltext:name=Label(:width=\d+)?(:default=Val)?% -> {{fill:Label}}
        let fillPattern = #"%filltext:([^%]+)%"#
        if let regex = try? NSRegularExpression(pattern: fillPattern, options: []) {
            let nsStr = result as NSString
            let matches = regex.matches(in: result, options: [], range: NSRange(location: 0, length: nsStr.length))
            for match in matches.reversed() {
                let params = nsStr.substring(with: match.range(at: 1))
                let (name, def) = parseLegacyFillParams(params)
                let replacement: String
                if def.isEmpty {
                    replacement = "{{fill:\(name)}}"
                } else {
                    replacement = "{{fill:\(name):default=\(def)}}"
                }
                result = (result as NSString).replacingCharacters(in: match.range, with: replacement)
            }
        }
        
        // 2. %fillarea:name=Label(:default=Val)?% -> {{multiline:Label}}
        let multilinePattern = #"%fillarea:([^%]+)%"#
        if let regex = try? NSRegularExpression(pattern: multilinePattern, options: []) {
            let nsStr = result as NSString
            let matches = regex.matches(in: result, options: [], range: NSRange(location: 0, length: nsStr.length))
            for match in matches.reversed() {
                let params = nsStr.substring(with: match.range(at: 1))
                let (name, def) = parseLegacyFillParams(params)
                let replacement: String
                if def.isEmpty {
                    replacement = "{{multiline:\(name)}}"
                } else {
                    replacement = "{{multiline:\(name):default=\(def)}}"
                }
                result = (result as NSString).replacingCharacters(in: match.range, with: replacement)
            }
        }
        
        // 3. %fillpopup:name=Label:options=A,B,C% -> {{choice:Label:A,B,C}}
        let popupPattern = #"%fillpopup:([^%]+)%"#
        if let regex = try? NSRegularExpression(pattern: popupPattern, options: []) {
            let nsStr = result as NSString
            let matches = regex.matches(in: result, options: [], range: NSRange(location: 0, length: nsStr.length))
            for match in matches.reversed() {
                let params = nsStr.substring(with: match.range(at: 1))
                let parts = params.components(separatedBy: ":")
                var name = "Choice"
                var options: [String] = []
                for p in parts {
                    if p.starts(with: "name=") {
                        name = String(p.dropFirst("name=".count))
                    } else if !p.contains("=") {
                        options.append(p)
                    }
                }
                let opts = options.joined(separator: ",")
                result = (result as NSString).replacingCharacters(in: match.range, with: "{{choice:\(name):\(opts)}}")
            }
        }
        
        // 4. Clipboard and Cursor
        result = result.replacingOccurrences(of: "%clipboard%", with: "{{clipboard}}")
        result = result.replacingOccurrences(of: "%clipboard", with: "{{clipboard}}")
        result = result.replacingOccurrences(of: "%cursor%", with: "{{cursor}}")
        result = result.replacingOccurrences(of: "%|", with: "{{cursor}}")
        result = result.replacingOccurrences(of: "%key:tab%", with: "{{key:tab}}")
        result = result.replacingOccurrences(of: "%key:return%", with: "{{key:return}}")
        
        // 5. Date conversions (common patterns from legacy exports)
        result = result.replacingOccurrences(of: "%B %d, %Y", with: "{{date:MMMM d, yyyy}}")
        result = result.replacingOccurrences(of: "%A %B %e", with: "{{date:EEEE MMMM d}}")
        result = result.replacingOccurrences(of: "%d/%m", with: "{{date:dd/MM}}")
        result = result.replacingOccurrences(of: "%H:%M", with: "{{time:HH:mm}}")
        result = result.replacingOccurrences(of: "%Y-%m-%d", with: "{{date:yyyy-MM-dd}}")
        result = result.replacingOccurrences(of: "%m/%d/%Y", with: "{{date:MM/dd/yyyy}}")
        result = result.replacingOccurrences(of: "%m/%d/%y", with: "{{date:MM/dd/yy}}")
        
        return result
    }
    
    private func parseLegacyFillParams(_ params: String) -> (name: String, defaultValue: String) {
        let parts = params.components(separatedBy: ":")
        var name = "Field"
        var defaultValue = ""
        for p in parts {
            if p.starts(with: "name=") {
                name = String(p.dropFirst("name=".count))
            } else if p.starts(with: "default=") {
                defaultValue = String(p.dropFirst("default=".count))
            }
        }
        return (name, defaultValue)
    }
    
    // MARK: - RFC 4180 CSV Tokenizer
    
    public func parseCSVForDebug(_ text: String) -> [[String]] {
        return parseCSV(text)
    }
    
    private func parseCSV(_ text: String) -> [[String]] {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: CharacterSet(charactersIn: "\u{FEFF}"))
        
        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var inQuotes = false
        let chars = Array(normalized)
        var i = 0
        let count = chars.count
        
        while i < count {
            let c = chars[i]
            
            if inQuotes {
                if c == "\"" {
                    if i + 1 < count && chars[i + 1] == "\"" {
                        currentField.append("\"")
                        i += 2
                        continue
                    } else {
                        inQuotes = false
                        i += 1
                        continue
                    }
                } else {
                    currentField.append(c)
                    i += 1
                }
            } else {
                if c == "\"" {
                    inQuotes = true
                    i += 1
                } else if c == "," {
                    currentRow.append(currentField)
                    currentField = ""
                    i += 1
                } else if c == "\n" {
                    currentRow.append(currentField)
                    currentField = ""
                    rows.append(currentRow)
                    currentRow = []
                    i += 1
                } else {
                    currentField.append(c)
                    i += 1
                }
            }
        }
        
        if !currentField.isEmpty || !currentRow.isEmpty {
            currentRow.append(currentField)
            rows.append(currentRow)
        }
        
        return rows
    }
}
