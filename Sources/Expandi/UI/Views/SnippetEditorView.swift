import SwiftUI

public struct SnippetEditorView: View {
    @ObservedObject var store = SnippetStore.shared
    @ObservedObject var appState = AppState.shared
    
    @State private var bottomTab: BottomTab = .preview
    @State private var testInput: String = ""
    @State private var tagInput: String = ""
    @State private var activeFillInSheet: FillInInsertType? = nil
    
    enum BottomTab: String, CaseIterable, Identifiable {
        case preview = "Live Preview"
        case tester = "Interactive Tester"
        case notes = "Notes & Tags"
        var id: String { rawValue }
    }
    
    enum FillInInsertType: Identifiable {
        case singleLine
        case multiLine
        case datePicker
        case optionalSection
        case popupMenu
        
        var id: String {
            switch self {
            case .singleLine: return "singleLine"
            case .multiLine: return "multiLine"
            case .datePicker: return "datePicker"
            case .optionalSection: return "optionalSection"
            case .popupMenu: return "popupMenu"
            }
        }
    }
    
    public init() {}
    
    private var currentSnippet: Snippet? {
        guard let id = appState.selectedSnippetId else { return nil }
        return store.snippets.first(where: { $0.id == id })
    }
    
    private var abbreviationConflict: Bool {
        guard let snippet = currentSnippet else { return false }
        return store.snippets.contains {
            $0.id != snippet.id &&
            !$0.isDeleted &&
            $0.abbreviation.caseInsensitiveCompare(snippet.abbreviation) == .orderedSame
        }
    }
    
    public var body: some View {
        if let snippet = currentSnippet {
            VStack(spacing: 0) {
                // Top Bar: Content Type & Action Buttons
                HStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Text("Content Type")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                        
                        Picker("", selection: Binding(
                            get: { snippet.type },
                            set: { newType in
                                var updated = snippet
                                updated.type = newType
                                store.updateSnippet(updated)
                            }
                        )) {
                            ForEach(SnippetType.allCases, id: \.self) { t in
                                Text(t.displayName).tag(t)
                            }
                        }
                        .frame(width: 140)
                    }
                    
                    Spacer()
                    
                    // Favorite Toggle
                    Button {
                        var updated = snippet
                        updated.isFavorite.toggle()
                        store.updateSnippet(updated)
                    } label: {
                        Image(systemName: snippet.isFavorite ? "star.fill" : "star")
                            .foregroundStyle(snippet.isFavorite ? .yellow : .secondary)
                            .font(.system(size: 13))
                    }
                    .buttonStyle(.plain)
                    .help("Favorite Snippet")
                    
                    // Duplicate Button
                    Button {
                        let dup = store.duplicateSnippet(snippet)
                        appState.selectedSnippetId = dup.id
                    } label: {
                        Image(systemName: "plus.square.on.square")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 13))
                    }
                    .buttonStyle(.plain)
                    .help("Duplicate Snippet")
                    
                    // Delete Button
                    Button(role: .destructive) {
                        store.deleteSnippet(id: snippet.id)
                        appState.selectedSnippetId = nil
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                            .font(.system(size: 13))
                    }
                    .buttonStyle(.plain)
                    .help("Move to Trash")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.bar)
                
                Divider()
                
                // Icon Macro Toolbar (Matches the exact layout from screenshot)
                HStack(spacing: 14) {
                    // 1. Calendar (Date)
                    Menu {
                        Button("Today (YYYY-MM-DD)") { insertMacro("{{date:YYYY-MM-dd}}", into: snippet) }
                        Button("Long Date (Month Day, Year)") { insertMacro("{{date:MMMM d, YYYY}}", into: snippet) }
                        Button("Day of Week (e.g. Tuesday)") { insertMacro("{{date:EEEE}}", into: snippet) }
                        Button("ISO 8601 Timestamp") { insertMacro("{{date:YYYY-MM-dd}}T{{time:HH:mm:ss}}Z", into: snippet) }
                    } label: {
                        Image(systemName: "calendar")
                            .font(.system(size: 14))
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 24)
                    .help("Insert Date Macro")
                    
                    // 2. Clock (Time)
                    Menu {
                        Button("12-Hour Time (h:mm a)") { insertMacro("{{time:h:mm a}}", into: snippet) }
                        Button("24-Hour Time (HH:mm)") { insertMacro("{{time:HH:mm}}", into: snippet) }
                        Button("With Seconds (HH:mm:ss)") { insertMacro("{{time:HH:mm:ss}}", into: snippet) }
                    } label: {
                        Image(systemName: "clock")
                            .font(.system(size: 14))
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 24)
                    .help("Insert Time Macro")
                    
                    // 3. Calculator / Date Math
                    Menu {
                        Button("+1 Day (Tomorrow)") { insertMacro("{{date:offset=+1d,format=YYYY-MM-dd}}", into: snippet) }
                        Button("-1 Day (Yesterday)") { insertMacro("{{date:offset=-1d,format=YYYY-MM-dd}}", into: snippet) }
                        Button("+7 Days (Next Week)") { insertMacro("{{date:offset=+7d,format=YYYY-MM-dd}}", into: snippet) }
                        Button("+1 Month") { insertMacro("{{date:offset=+1m,format=YYYY-MM-dd}}", into: snippet) }
                        Button("+1 Year") { insertMacro("{{date:offset=+1y,format=YYYY-MM-dd}}", into: snippet) }
                    } label: {
                        Image(systemName: "plus.forwardslash.minus")
                            .font(.system(size: 14))
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 24)
                    .help("Date & Time Math")
                    
                    // 4. Keyboard Key Simulation
                    Menu {
                        Button("Tab Key") { insertMacro("{{key:tab}}", into: snippet) }
                        Button("Return / Enter Key") { insertMacro("{{key:return}}", into: snippet) }
                        Button("Escape Key") { insertMacro("{{key:esc}}", into: snippet) }
                    } label: {
                        Image(systemName: "keyboard")
                            .font(.system(size: 14))
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 24)
                    .help("Insert Simulated Key Press")
                    
                    // 5. Cursor Placement Marker
                    Button {
                        insertMacro("{{cursor}}", into: snippet)
                    } label: {
                        Image(systemName: "character.cursor.ibeam")
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                    .help("Set Cursor Position After Expansion ({{cursor}})")
                    
                    // 6. Fill-In Dropdown Menu (Exact match to screenshot!)
                    Menu {
                        Button {
                            activeFillInSheet = .singleLine
                        } label: {
                            Label("Single Line Field", systemImage: "minus")
                        }
                        
                        Button {
                            activeFillInSheet = .multiLine
                        } label: {
                            Label("Multi Line Field", systemImage: "text.alignleft")
                        }
                        
                        Button {
                            activeFillInSheet = .datePicker
                        } label: {
                            Label("Date Picker", systemImage: "calendar")
                        }
                        
                        Button {
                            activeFillInSheet = .optionalSection
                        } label: {
                            Label("Optional Section", systemImage: "arrow.triangle.2.circlepath")
                        }
                        
                        Button {
                            activeFillInSheet = .popupMenu
                        } label: {
                            Label("Popup Menu", systemImage: "arrow.up.right.square")
                        }
                        
                        Divider()
                        
                        Button {
                            insertMacro("{{show_at_top}}", into: snippet)
                        } label: {
                            Label("Show at Top", systemImage: "square")
                        }
                    } label: {
                        HStack(spacing: 2) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 14))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8, weight: .bold))
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 44)
                    .help("Insert Fill-In Field (Single Line, Multi Line, Date Picker, Optional, Popup Menu)")
                    
                    // 7. Shell Script execution
                    Button {
                        insertMacro("{{shell:echo \"Result\"}}", into: snippet)
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .buttonStyle(.plain)
                    .help("Insert Shell Script Macro ({{shell:...}})")
                    
                    // Clipboard Macro
                    Button {
                        insertMacro("{{clipboard}}", into: snippet)
                    } label: {
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 13))
                    }
                    .buttonStyle(.plain)
                    .help("Insert Current Clipboard ({{clipboard}})")
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(0.04))
                
                Divider()
                
                // Content TextEditor
                TextEditor(text: Binding(
                    get: { snippet.content },
                    set: { newContent in
                        var updated = snippet
                        updated.content = newContent
                        store.updateSnippet(updated)
                    }
                ))
                .font(.system(size: 13, design: .monospaced))
                .lineSpacing(4)
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                Divider()
                
                // Bottom Metadata & Configuration (Matches screenshot layout)
                VStack(spacing: 8) {
                    // Row 1: Label
                    HStack(spacing: 12) {
                        Text("Label")
                            .font(.system(size: 12, weight: .medium))
                            .frame(width: 80, alignment: .leading)
                            .foregroundStyle(.secondary)
                        
                        TextField("Label / Title", text: Binding(
                            get: { snippet.title },
                            set: { newTitle in
                                var updated = snippet
                                updated.title = newTitle
                                store.updateSnippet(updated)
                            }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13))
                    }
                    
                    // Row 2: Abbreviation & Case Sensitivity
                    HStack(spacing: 12) {
                        Text("Abbreviation")
                            .font(.system(size: 12, weight: .medium))
                            .frame(width: 80, alignment: .leading)
                            .foregroundStyle(.secondary)
                        
                        TextField("Abbreviation", text: Binding(
                            get: { snippet.abbreviation },
                            set: { newAbbr in
                                var updated = snippet
                                updated.abbreviation = newAbbr
                                store.updateSnippet(updated)
                            }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .frame(maxWidth: 200)
                        
                        if abbreviationConflict {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .help("Duplicate abbreviation in another snippet")
                        }
                        
                        Picker("", selection: Binding(
                            get: { snippet.caseSensitivity },
                            set: { newCase in
                                var updated = snippet
                                updated.caseSensitivity = newCase
                                store.updateSnippet(updated)
                            }
                        )) {
                            Text("Case Sensitive (aB, Ab, ab differ)").tag(CaseSensitivity.exactMatch)
                            Text("Adapt to Case").tag(CaseSensitivity.adaptCase)
                            Text("Case-Insensitive").tag(CaseSensitivity.ignoreCase)
                        }
                        .frame(maxWidth: 240)
                        
                        Spacer()
                    }
                    
                    // Row 3: Group & Trigger Delimiter
                    HStack(spacing: 12) {
                        Text("Group")
                            .font(.system(size: 12, weight: .medium))
                            .frame(width: 80, alignment: .leading)
                            .foregroundStyle(.secondary)
                        
                        Picker("", selection: Binding(
                            get: { snippet.groupId },
                            set: { newGroupId in
                                var updated = snippet
                                updated.groupId = newGroupId
                                store.updateSnippet(updated)
                            }
                        )) {
                            ForEach(store.groups) { group in
                                Label(group.name, systemImage: group.iconName).tag(group.id)
                            }
                        }
                        .frame(maxWidth: 200)
                        
                        Picker("", selection: Binding(
                            get: { snippet.delimiterMode.isImmediate ? "immediate" : "delimiter" },
                            set: { mode in
                                var updated = snippet
                                updated.delimiterMode = (mode == "immediate") ? .immediate : .afterDelimiter(keepDelimiter: true)
                                store.updateSnippet(updated)
                            }
                        )) {
                            Text("Expand Immediately").tag("immediate")
                            Text("Expand After Delimiter").tag("delimiter")
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 240)
                        
                        Spacer()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.secondary.opacity(0.04))
                
                Divider()
                
                // Bottom Tabbed Area (Live Preview / Interactive Tester / Notes & Tags)
                VStack(spacing: 0) {
                    HStack {
                        Picker("", selection: $bottomTab) {
                            ForEach(BottomTab.allCases) { tab in
                                Text(tab.rawValue).tag(tab)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 340)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(.bar)
                    
                    Divider()
                    
                    Group {
                        switch bottomTab {
                        case .preview:
                            let evaluated = MacroEvaluator.shared.evaluate(
                                snippet: snippet,
                                allSnippets: store.snippets
                            )
                            ScrollView {
                                Text(evaluated.text.isEmpty ? "(Empty output)" : evaluated.text)
                                    .font(.system(size: 12, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .textSelection(.enabled)
                                    .padding(10)
                            }
                            
                        case .tester:
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Test typing your abbreviation '\(snippet.abbreviation)' in this field:")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                
                                HStack {
                                    TextField("Type here to test...", text: $testInput)
                                        .textFieldStyle(.roundedBorder)
                                        .font(.system(size: 13))
                                    Button("Clear") { testInput = "" }
                                        .controlSize(.small)
                                }
                                
                                if testInput.contains(snippet.abbreviation) {
                                    HStack {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                        Text("Abbreviation matched! Expandi expands this globally.")
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundStyle(.green)
                                    }
                                }
                            }
                            .padding(10)
                            
                        case .notes:
                            VStack(alignment: .leading, spacing: 6) {
                                TextField("Notes or description for this snippet...", text: Binding(
                                    get: { snippet.notes },
                                    set: { newNotes in
                                        var updated = snippet
                                        updated.notes = newNotes
                                        store.updateSnippet(updated)
                                    }
                                ))
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12))
                                
                                HStack {
                                    Text("Tags:")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                    
                                    ForEach(snippet.tags, id: \.self) { tag in
                                        HStack(spacing: 3) {
                                            Text(tag).font(.system(size: 11))
                                            Button {
                                                var updated = snippet
                                                updated.tags.removeAll { $0 == tag }
                                                store.updateSnippet(updated)
                                            } label: {
                                                Image(systemName: "xmark").font(.system(size: 8))
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1)
                                        .background(Color.secondary.opacity(0.15))
                                        .clipShape(RoundedRectangle(cornerRadius: 3))
                                    }
                                    
                                    TextField("+ Tag", text: $tagInput)
                                        .textFieldStyle(.plain)
                                        .font(.system(size: 11))
                                        .frame(width: 60)
                                        .onSubmit {
                                            let trimmed = tagInput.trimmingCharacters(in: .whitespaces)
                                            if !trimmed.isEmpty && !snippet.tags.contains(trimmed) {
                                                var updated = snippet
                                                updated.tags.append(trimmed)
                                                store.updateSnippet(updated)
                                                tagInput = ""
                                            }
                                        }
                                }
                            }
                            .padding(10)
                        }
                    }
                    .frame(height: 85)
                    .background(Color.secondary.opacity(0.02))
                }
            }
            .sheet(item: $activeFillInSheet) { sheetType in
                FillInBuilderSheet(type: sheetType) { macro in
                    insertMacro(macro, into: snippet)
                }
            }
        } else {
            VStack(spacing: 12) {
                Image(systemName: "text.alignleft")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary.opacity(0.4))
                Text("Select a Snippet to View or Edit")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    private func insertMacro(_ macroString: String, into snippet: Snippet) {
        var updated = snippet
        updated.content.append(macroString)
        store.updateSnippet(updated)
    }
}

// MARK: - Fill-In Builder Sheet

public struct FillInBuilderSheet: View {
    let type: SnippetEditorView.FillInInsertType
    let onInsert: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var label: String = ""
    @State private var defaultValue: String = ""
    @State private var optionsString: String = "Option 1, Option 2, Option 3"
    @State private var optionalContent: String = "Content to include when checked"
    @State private var dateFormat: String = "YYYY-MM-dd"
    
    public var body: some View {
        VStack(spacing: 16) {
            Text(sheetTitle)
                .font(.headline)
            
            Form {
                TextField("Field Label / Name:", text: $label)
                
                switch type {
                case .singleLine:
                    TextField("Default Value (optional):", text: $defaultValue)
                case .multiLine:
                    TextField("Default Notes (optional):", text: $defaultValue)
                case .datePicker:
                    TextField("Date Format (e.g. YYYY-MM-dd):", text: $dateFormat)
                case .popupMenu:
                    TextField("Menu Choices (comma-separated):", text: $optionsString)
                    TextField("Default Selection:", text: $defaultValue)
                case .optionalSection:
                    TextField("Text to include when checked:", text: $optionalContent)
                }
            }
            .formStyle(.grouped)
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Insert Field") {
                    let fieldLabel = label.trimmingCharacters(in: .whitespaces).isEmpty ? "Field" : label
                    let macro: String
                    
                    switch type {
                    case .singleLine:
                        if defaultValue.isEmpty {
                            macro = "{{fill:\(fieldLabel)}}"
                        } else {
                            macro = "{{fill:\(fieldLabel):default=\(defaultValue)}}"
                        }
                    case .multiLine:
                        if defaultValue.isEmpty {
                            macro = "{{multiline:\(fieldLabel)}}"
                        } else {
                            macro = "{{multiline:\(fieldLabel):default=\(defaultValue)}}"
                        }
                    case .datePicker:
                        macro = "{{datepicker:\(fieldLabel):format=\(dateFormat)}}"
                    case .popupMenu:
                        let cleanOptions = optionsString.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.joined(separator: ",")
                        if defaultValue.isEmpty {
                            macro = "{{choice:\(fieldLabel):\(cleanOptions)}}"
                        } else {
                            macro = "{{choice:\(fieldLabel):\(cleanOptions):default=\(defaultValue)}}"
                        }
                    case .optionalSection:
                        macro = "{{opt:\(fieldLabel):\(optionalContent)}}"
                    }
                    
                    onInsert(macro)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 420, height: 280)
        .onAppear {
            switch type {
            case .singleLine: label = "Name"
            case .multiLine: label = "Notes"
            case .datePicker: label = "Date"
            case .popupMenu: label = "Department"
            case .optionalSection: label = "Include Signature"
            }
        }
    }
    
    private var sheetTitle: String {
        switch type {
        case .singleLine: return "Insert Single Line Field"
        case .multiLine: return "Insert Multi Line Field"
        case .datePicker: return "Insert Date Picker Field"
        case .popupMenu: return "Insert Popup Menu (Dropdown)"
        case .optionalSection: return "Insert Optional Section"
        }
    }
}
