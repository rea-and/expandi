import SwiftUI

public struct OnboardingWelcomeView: View {
    let onChooseStarterPack: () -> Void
    let onChooseEmpty: () -> Void
    
    @State private var hoveredCard: Int? = nil
    
    public init(
        onChooseStarterPack: @escaping () -> Void,
        onChooseEmpty: @escaping () -> Void
    ) {
        self.onChooseStarterPack = onChooseStarterPack
        self.onChooseEmpty = onChooseEmpty
    }
    
    public var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 64, height: 64)
                    
                    Image(systemName: "sparkles.rectangle.stack.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(.white)
                }
                .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
                
                Text("Welcome to Expandi")
                    .font(.system(size: 24, weight: .bold))
                
                Text("Effortless text expansion and snippet management for macOS.\nHow would you like to set up your library?")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
            .padding(.top, 10)
            
            // Cards Grid
            HStack(spacing: 16) {
                // Option 1: Starter Pack (Recommended)
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "sparkles")
                            .font(.system(size: 20))
                            .foregroundStyle(.blue)
                        Spacer()
                        Text("Recommended")
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.blue.opacity(0.15))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                    }
                    
                    Text("Sample Snippets")
                        .font(.system(size: 15, weight: .semibold))
                    
                    Text("Pre-loaded with ready-to-use snippets for dates & times, email templates, code macros, emojis, and dynamic fill-in forms.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineSpacing(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Spacer()
                    
                    Button {
                        onChooseStarterPack()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Use Sample Snippets")
                                .font(.system(size: 13, weight: .medium))
                            Spacer()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.secondary.opacity(hoveredCard == 1 ? 0.1 : 0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(hoveredCard == 1 ? 0.5 : 0.2), lineWidth: 1.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .onHover { isHovered in
                    hoveredCard = isHovered ? 1 : nil
                }
                
                // Option 2: Start Empty
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "square.dashed")
                            .font(.system(size: 20))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("Clean Slate")
                            .font(.system(size: 10, weight: .medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.secondary.opacity(0.12))
                            .foregroundStyle(.secondary)
                            .clipShape(Capsule())
                    }
                    
                    Text("Start Empty")
                        .font(.system(size: 15, weight: .semibold))
                    
                    Text("Start with zero snippets and a clean workspace. Perfect if you prefer to build your own or import an existing CSV / JSON collection.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineSpacing(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Spacer()
                    
                    Button {
                        onChooseEmpty()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Start Empty")
                                .font(.system(size: 13, weight: .medium))
                            Spacer()
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.secondary.opacity(hoveredCard == 2 ? 0.1 : 0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.secondary.opacity(hoveredCard == 2 ? 0.4 : 0.2), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .onHover { isHovered in
                    hoveredCard = isHovered ? 2 : nil
                }
            }
            .frame(height: 200)
            
            // Footer Info
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.system(size: 11))
                Text("You can change your starter library or restore factory defaults anytime in Preferences > Advanced.")
                    .font(.system(size: 11))
            }
            .foregroundStyle(.secondary)
            .padding(.bottom, 6)
        }
        .padding(28)
        .frame(width: 580, height: 440)
    }
}
