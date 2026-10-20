import SwiftUI

public struct StatsView: View {
    @ObservedObject var store = SnippetStore.shared
    @Environment(\.dismiss) private var dismiss
    
    public init() {}
    
    private var timeSavedFormatted: String {
        let totalMinutes = store.stats.estimatedTimeSavedMinutes
        if totalMinutes < 60 {
            return String(format: "%.1f min", totalMinutes)
        } else {
            let hours = Int(totalMinutes) / 60
            let mins = Int(totalMinutes) % 60
            return "\(hours)h \(mins)m"
        }
    }
    
    private var topSnippets: [Snippet] {
        store.snippets
            .filter { !$0.isDeleted && $0.usageCount > 0 }
            .sorted { $0.usageCount > $1.usageCount }
            .prefix(5)
            .map { $0 }
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Typing Analytics & Stats")
                        .font(.headline)
                    Text("Track productivity and time saved using Expandi")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(16)
            .background(.bar)
            
            Divider()
            
            ScrollView {
                VStack(spacing: 20) {
                    // KPI Cards Grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                        KPICard(
                            title: "Total Expansions",
                            value: "\(store.stats.totalExpansions)",
                            icon: "bolt.fill",
                            color: .blue
                        )
                        
                        KPICard(
                            title: "Keystrokes Saved",
                            value: "\(store.stats.totalKeystrokesSaved)",
                            icon: "keyboard.fill",
                            color: .green
                        )
                        
                        KPICard(
                            title: "Estimated Time Saved",
                            value: timeSavedFormatted,
                            icon: "clock.badge.checkmark.fill",
                            color: .orange
                        )
                        
                        KPICard(
                            title: "Active Snippets",
                            value: "\(store.snippets.filter { !$0.isDeleted }.count)",
                            icon: "tray.full.fill",
                            color: .purple
                        )
                    }
                    
                    // Top Used Snippets
                    if !topSnippets.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Most Used Snippets")
                                .font(.system(size: 13, weight: .bold))
                            
                            VStack(spacing: 6) {
                                ForEach(topSnippets) { snippet in
                                    HStack {
                                        Text(snippet.abbreviation)
                                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 2)
                                            .background(Color.accentColor.opacity(0.15))
                                            .foregroundStyle(Color.accentColor)
                                            .clipShape(RoundedRectangle(cornerRadius: 3))
                                        
                                        Text(snippet.title)
                                            .font(.system(size: 12))
                                            .lineLimit(1)
                                        
                                        Spacer()
                                        
                                        Text("\(snippet.usageCount) expansions")
                                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                            .padding(12)
                            .background(Color.secondary.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    
                    // Group Usage Breakdown
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Group Activity")
                            .font(.system(size: 13, weight: .bold))
                        
                        VStack(spacing: 8) {
                            ForEach(store.groups) { group in
                                let count = store.stats.groupUsage[group.id.uuidString] ?? 0
                                HStack {
                                    Image(systemName: group.iconName)
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color(hex: group.colorHex))
                                        .frame(width: 18)
                                    
                                    Text(group.name)
                                        .font(.system(size: 12))
                                    
                                    Spacer()
                                    
                                    Text("\(count) uses")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(12)
                        .background(Color.secondary.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 460, height: 480)
    }
}

// MARK: - KPI Card Component

private struct KPICard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.system(size: 16))
                Spacer()
            }
            
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
            
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
        )
    }
}
