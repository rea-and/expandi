import SwiftUI

public struct FillInDialogView: View {
    let snippet: Snippet
    let allSnippets: [Snippet]
    let onConfirm: ([String: String]) -> Void
    let onCancel: () -> Void
    
    @State private var values: [String: String] = [:]
    @State private var dateValues: [String: Date] = [:]
    private let fields: [FillInField]
    
    public init(
        snippet: Snippet,
        allSnippets: [Snippet],
        onConfirm: @escaping ([String: String]) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.snippet = snippet
        self.allSnippets = allSnippets
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        
        let extracted = MacroEvaluator.shared.extractFillInFields(from: snippet.content)
        self.fields = extracted
        
        var initialValues: [String: String] = [:]
        var initialDates: [String: Date] = [:]
        
        for f in extracted {
            initialValues[f.id] = f.defaultValue
            if f.type == .datePicker {
                initialDates[f.id] = Date()
            }
        }
        
        _values = State(initialValue: initialValues)
        _dateValues = State(initialValue: initialDates)
    }
    
    private var liveEvaluatedText: String {
        var currentMap = values
        // Merge date picker formatted strings
        for field in fields where field.type == .datePicker {
            if let date = dateValues[field.id] {
                let formatter = DateFormatter()
                formatter.dateFormat = field.dateFormat
                currentMap[field.id] = formatter.string(from: date)
            }
        }
        let result = MacroEvaluator.shared.evaluate(
            snippet: snippet,
            fillInValues: currentMap,
            allSnippets: allSnippets
        )
        return result.text
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(snippet.title)
                        .font(.headline)
                    Text("Fill in fields to expand '\(snippet.abbreviation)'")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding(16)
            .background(.bar)
            
            Divider()
            
            // Dynamic Form Fields
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(fields) { field in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(field.label)
                                    .font(.system(size: 12, weight: .semibold))
                                Spacer()
                                fieldTypeBadge(for: field.type)
                            }
                            
                            switch field.type {
                            case .singleLine:
                                TextField(field.label, text: Binding(
                                    get: { values[field.id] ?? field.defaultValue },
                                    set: { values[field.id] = $0 }
                                ))
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 13))
                                
                            case .multiLine:
                                TextEditor(text: Binding(
                                    get: { values[field.id] ?? field.defaultValue },
                                    set: { values[field.id] = $0 }
                                ))
                                .font(.system(size: 12))
                                .frame(height: 70)
                                .padding(4)
                                .background(Color.secondary.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                                )
                                
                            case .datePicker:
                                HStack {
                                    DatePicker(
                                        "",
                                        selection: Binding(
                                            get: { dateValues[field.id] ?? Date() },
                                            set: { newDate in
                                                dateValues[field.id] = newDate
                                                let formatter = DateFormatter()
                                                formatter.dateFormat = field.dateFormat
                                                values[field.id] = formatter.string(from: newDate)
                                            }
                                        ),
                                        displayedComponents: [.date]
                                    )
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
                                    
                                    Spacer()
                                    
                                    let formatter = DateFormatter()
                                    let _ = formatter.dateFormat = field.dateFormat
                                    let preview = formatter.string(from: dateValues[field.id] ?? Date())
                                    Text("Format: \(preview)")
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                }
                                
                            case .choice:
                                Picker("", selection: Binding(
                                    get: { values[field.id] ?? field.defaultValue },
                                    set: { values[field.id] = $0 }
                                )) {
                                    ForEach(field.options, id: \.self) { opt in
                                        Text(opt).tag(opt)
                                    }
                                }
                                .pickerStyle(.menu)
                                
                            case .optionalSection:
                                Toggle(isOn: Binding(
                                    get: { (values[field.id] ?? "true").lowercased() == "true" },
                                    set: { values[field.id] = $0 ? "true" : "false" }
                                )) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(field.label)
                                            .font(.system(size: 12))
                                        if !field.optionalContent.isEmpty {
                                            Text(field.optionalContent.replacingOccurrences(of: "\n", with: " "))
                                                .font(.system(size: 10))
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                }
                                .toggleStyle(.checkbox)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding(16)
            }
            .frame(maxHeight: 260)
            
            Divider()
            
            // Live Output Preview
            VStack(alignment: .leading, spacing: 4) {
                Text("Result Preview:")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                
                ScrollView {
                    Text(liveEvaluatedText)
                        .font(.system(size: 11, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundStyle(.primary)
                }
                .frame(height: 70)
                .padding(8)
                .background(Color.secondary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            
            Divider()
            
            // Footer Action Buttons
            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Expand & Insert") {
                    var finalValues = values
                    for field in fields where field.type == .datePicker {
                        if let date = dateValues[field.id] {
                            let formatter = DateFormatter()
                            formatter.dateFormat = field.dateFormat
                            finalValues[field.id] = formatter.string(from: date)
                        }
                    }
                    onConfirm(finalValues)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding(14)
            .background(.bar)
        }
        .frame(width: 500)
        .background(
            ZStack {
                VisualEffectView(material: .popover, blendingMode: .behindWindow)
                Color(NSColor.windowBackgroundColor).opacity(0.85)
            }
        )
    }
    
    @ViewBuilder
    private func fieldTypeBadge(for type: FillInField.FieldType) -> some View {
        switch type {
        case .singleLine:
            Text("Single Line")
                .font(.system(size: 9, weight: .medium))
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(Color.blue.opacity(0.12))
                .foregroundStyle(.blue)
                .clipShape(RoundedRectangle(cornerRadius: 3))
        case .multiLine:
            Text("Multi Line")
                .font(.system(size: 9, weight: .medium))
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(Color.teal.opacity(0.12))
                .foregroundStyle(.teal)
                .clipShape(RoundedRectangle(cornerRadius: 3))
        case .datePicker:
            Text("Date Picker")
                .font(.system(size: 9, weight: .medium))
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(Color.orange.opacity(0.12))
                .foregroundStyle(.orange)
                .clipShape(RoundedRectangle(cornerRadius: 3))
        case .choice:
            Text("Popup Menu")
                .font(.system(size: 9, weight: .medium))
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(Color.purple.opacity(0.12))
                .foregroundStyle(.purple)
                .clipShape(RoundedRectangle(cornerRadius: 3))
        case .optionalSection:
            Text("Optional Section")
                .font(.system(size: 9, weight: .medium))
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(Color.green.opacity(0.12))
                .foregroundStyle(.green)
                .clipShape(RoundedRectangle(cornerRadius: 3))
        }
    }
}
