import SwiftUI

public struct PermissionsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isGranted: Bool = KeyboardMonitor.shared.isAccessibilityGranted
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "hand.raised.square.on.square.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentColor)
            
            VStack(spacing: 6) {
                Text("Enable Accessibility for Expandi")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("To detect abbreviations as you type and automatically expand them across your apps, Expandi requires macOS Accessibility permission.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            VStack(alignment: .leading, spacing: 10) {
                StepRow(number: "1", text: "Click the button below to open macOS System Settings.")
                StepRow(number: "2", text: "Find 'Expandi' in the Accessibility list.")
                StepRow(number: "3", text: "Turn on the toggle switch next to Expandi.")
            }
            .padding(16)
            .background(Color.secondary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            
            HStack(spacing: 12) {
                Button("Open System Settings") {
                    KeyboardMonitor.shared.openSystemSettingsAccessibility()
                }
                .buttonStyle(.borderedProminent)
                
                Button("Check Status") {
                    isGranted = KeyboardMonitor.shared.checkAccessibilityPermissions()
                    if isGranted {
                        dismiss()
                    }
                }
                
                Button("Later") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            
            if isGranted {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Permission Granted! Expandi is ready.")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.green)
                }
            }
        }
        .padding(24)
        .frame(width: 440)
    }
}

private struct StepRow: View {
    let number: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.system(size: 11, weight: .bold))
                .frame(width: 18, height: 18)
                .background(Color.accentColor.opacity(0.2))
                .foregroundStyle(Color.accentColor)
                .clipShape(Circle())
            
            Text(text)
                .font(.system(size: 12))
        }
    }
}
