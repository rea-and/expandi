import SwiftUI
import AppKit

public struct QuickSearchView: View {
    @ObservedObject var store = SnippetStore.shared
    @State private var query: String = ""
    @State private var selectedIndex: Int = 0
    
    public var onSelectSnippet: ((Snippet) -> Void)?
    public var onCancel: (() -> Void)?
    
    public init(
        onSelectSnippet: ((Snippet) -> Void)? = nil,
        onCancel: (() -> Void)? = nil
    ) {
        self.onSelectSnippet = onSelectSnippet
        self.onCancel = onCancel
    }
    
    private var matchingSnippets: [Snippet] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        let active = store.snippets.filter { !$0.isDeleted }
        
        if q.isEmpty {
            return active.sorted { ($0.lastUsedAt ?? .distantPast) > ($1.lastUsedAt ?? .distantPast) }
        }
        
        return active.filter {
            $0.abbreviation.lowercased().contains(q) ||
            $0.title.lowercased().contains(q) ||
            $0.content.lowercased().contains(q) ||
            $0.tags.contains { $0.lowercased().contains(q) }
        }
    }
    
    private var currentSelectedSnippet: Snippet? {
        guard !matchingSnippets.isEmpty else { return nil }
        let safeIndex = max(0, min(selectedIndex, matchingSnippets.count - 1))
        return matchingSnippets[safeIndex]
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Search Input Header
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.secondary)
                
                TextField("Search Expandi snippets by name, abbreviation, or content...", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .onSubmit {
                        if let selected = currentSelectedSnippet {
                            onSelectSnippet?(selected)
                        }
                    }
                
                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            
            Divider()
            
            // Content: List (Left) and Preview (Right)
            if matchingSnippets.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "text.magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary.opacity(0.4))
                    Text("No Matching Snippets")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack(spacing: 0) {
                    // Snippets list
                    ScrollViewReader { proxy in
                        List(selection: Binding(
                            get: { currentSelectedSnippet?.id },
                            set: { newId in
                                if let idx = matchingSnippets.firstIndex(where: { $0.id == newId }) {
                                    selectedIndex = idx
                                }
                            }
                        )) {
                            ForEach(Array(matchingSnippets.enumerated()), id: \.element.id) { index, snippet in
                                HStack(spacing: 8) {
                                    Text(snippet.abbreviation)
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(Color.accentColor.opacity(0.15))
                                        .foregroundStyle(Color.accentColor)
                                        .clipShape(RoundedRectangle(cornerRadius: 3))
                                    
                                    Text(snippet.title)
                                        .font(.system(size: 12, weight: .medium))
                                        .lineLimit(1)
                                    
                                    Spacer()
                                    
                                    if snippet.hasFillIns {
                                        Image(systemName: "square.and.pencil")
                                            .font(.system(size: 10))
                                            .foregroundStyle(.green)
                                    }
                                }
                                .tag(snippet.id)
                                .onTapGesture {
                                    selectedIndex = index
                                }
                            }
                        }
                        .listStyle(.inset)
                        .frame(width: 280)
                    }
                    
                    Divider()
                    
                    // Preview Pane
                    if let selected = currentSelectedSnippet {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(selected.title)
                                    .font(.headline)
                                Spacer()
                                Text(selected.abbreviation)
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.secondary.opacity(0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                            
                            Divider()
                            
                            let evaluated = MacroEvaluator.shared.evaluate(
                                snippet: selected,
                                allSnippets: store.snippets
                            )
                            
                            ScrollView {
                                Text(evaluated.text)
                                    .font(.system(size: 12, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .textSelection(.enabled)
                            }
                            
                            Spacer()
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            
            Divider()
            
            // Footer with Shortcut Hints
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Text("↵")
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 4)
                        .background(Color.secondary.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                    Text("Insert Snippet")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                
                HStack(spacing: 4) {
                    Text("⌘C")
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 4)
                        .background(Color.secondary.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                    Text("Copy to Clipboard")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Text("⎋")
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 4)
                        .background(Color.secondary.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                    Text("Dismiss")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.bar)
        }
        .frame(width: 620, height: 380)
        .background(
            ZStack {
                VisualEffectView(material: .popover, blendingMode: .behindWindow)
                Color(NSColor.windowBackgroundColor).opacity(0.85)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}
