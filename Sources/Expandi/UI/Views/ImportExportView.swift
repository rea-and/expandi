import SwiftUI
import AppKit
import UniformTypeIdentifiers

public struct ImportExportView: View {
    @ObservedObject var store = SnippetStore.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var activeTab: Tab = .export
    @State private var exportFormat: ExportFormat = .json
    @State private var selectedGroupId: UUID? = nil
    
    @State private var importResolution: ImportResolutionMode = .keepBoth
    @State private var importStatusMessage: String? = nil
    @State private var isSuccess: Bool = true
    
    enum Tab: String, CaseIterable, Identifiable {
        case export = "Export"
        case `import` = "Import"
        var id: String { rawValue }
    }
    
    enum ExportFormat: String, CaseIterable, Identifiable {
        case json = "Expandi Archive (.json)"
        case csv = "Comma-Separated Values (.csv)"
        var id: String { rawValue }
    }
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Import & Export")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(16)
            .background(.bar)
            
            Divider()
            
            Picker("", selection: $activeTab) {
                ForEach(Tab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(16)
            
            if activeTab == .export {
                exportSection
            } else {
                importSection
            }
            
            Spacer()
        }
        .frame(width: 480, height: 380)
    }
    
    // MARK: - Export Section
    
    private var exportSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Export Format")
                    .font(.system(size: 12, weight: .semibold))
                Picker("", selection: $exportFormat) {
                    ForEach(ExportFormat.allCases) { fmt in
                        Text(fmt.rawValue).tag(fmt)
                    }
                }
                .pickerStyle(.radioGroup)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Scope")
                    .font(.system(size: 12, weight: .semibold))
                Picker("Group", selection: $selectedGroupId) {
                    Text("All Groups and Snippets").tag(UUID?.none)
                    Divider()
                    ForEach(store.groups) { group in
                        Label(group.name, systemImage: group.iconName).tag(UUID?.some(group.id))
                    }
                }
            }
            
            Spacer()
            
            HStack {
                Spacer()
                Button("Export...") {
                    performExport()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
    
    // MARK: - Import Section
    
    private var importSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Duplicate Resolution")
                    .font(.system(size: 12, weight: .semibold))
                Picker("", selection: $importResolution) {
                    ForEach(ImportResolutionMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)
            }
            
            if let msg = importStatusMessage {
                HStack(spacing: 8) {
                    Image(systemName: isSuccess ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .foregroundStyle(isSuccess ? .green : .red)
                    Text(msg)
                        .font(.system(size: 12))
                        .foregroundStyle(isSuccess ? .green : .red)
                }
                .padding(10)
                .background((isSuccess ? Color.green : Color.red).opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            
            Spacer()
            
            HStack {
                Spacer()
                Button("Choose File to Import...") {
                    performImport()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
    
    // MARK: - Export Logic
    
    private func performExport() {
        let snippetsToExport: [Snippet]
        let groupsToExport: [SnippetGroup]
        
        if let gid = selectedGroupId {
            snippetsToExport = store.snippets.filter { $0.groupId == gid && !$0.isDeleted }
            groupsToExport = store.groups.filter { $0.id == gid }
        } else {
            snippetsToExport = store.snippets.filter { !$0.isDeleted }
            groupsToExport = store.groups
        }
        
        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = true
        
        if exportFormat == .json {
            savePanel.nameFieldStringValue = "Expandi_Backup.json"
            savePanel.allowedContentTypes = [.json]
        } else {
            savePanel.nameFieldStringValue = "Expandi_Snippets.csv"
            savePanel.allowedContentTypes = [.commaSeparatedText]
        }
        
        savePanel.begin { response in
            guard response == .OK, let url = savePanel.url else { return }
            do {
                if exportFormat == .json {
                    let data = try Exporter.shared.exportJSON(groups: groupsToExport, snippets: snippetsToExport)
                    try data.write(to: url, options: .atomic)
                } else {
                    let csv = Exporter.shared.exportCSV(groups: groupsToExport, snippets: snippetsToExport)
                    try csv.write(to: url, atomically: true, encoding: .utf8)
                }
            } catch {
                print("Expandi: Export error: \(error)")
            }
        }
    }
    
    // MARK: - Import Logic
    
    private func performImport() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false
        openPanel.allowedContentTypes = [.json, .commaSeparatedText]
        
        openPanel.begin { response in
            guard response == .OK, let url = openPanel.url else { return }
            do {
                if url.pathExtension.lowercased() == "csv" {
                    let csvString = try String(contentsOf: url, encoding: .utf8)
                    var existingGroups = store.groups
                    var existingSnippets = store.snippets
                    let result = Importer.shared.importCSV(
                        csvString: csvString,
                        into: &existingGroups,
                        existingSnippets: &existingSnippets,
                        resolutionMode: importResolution
                    )
                    store.groups = existingGroups
                    store.snippets = existingSnippets
                    store.saveAll()
                    
                    self.isSuccess = true
                    self.importStatusMessage = "Successfully imported \(result.snippetsImported) snippets and \(result.groupsImported) new groups."
                } else {
                    let data = try Data(contentsOf: url)
                    var existingGroups = store.groups
                    var existingSnippets = store.snippets
                    let result = try Importer.shared.importJSON(
                        data: data,
                        into: &existingGroups,
                        existingSnippets: &existingSnippets,
                        resolutionMode: importResolution
                    )
                    store.groups = existingGroups
                    store.snippets = existingSnippets
                    store.saveAll()
                    
                    self.isSuccess = true
                    self.importStatusMessage = "Successfully imported \(result.snippetsImported) snippets and \(result.groupsImported) new groups."
                }
            } catch {
                self.isSuccess = false
                self.importStatusMessage = "Import failed: \(error.localizedDescription)"
            }
        }
    }
}
