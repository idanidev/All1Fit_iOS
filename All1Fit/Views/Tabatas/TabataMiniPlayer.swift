import SwiftUI

struct TabataMiniPlayer: View {
    @StateObject private var sessionManager = TabataSessionManager.shared
    @Binding var showFullPlayer: Bool
    
    var body: some View {
        if sessionManager.isActive, let tabata = sessionManager.activeTabata {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    // Compact Icon
                    Circle()
                        .fill(phaseColor)
                        .frame(width: 8, height: 8)
                    
                    // Info
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tabata.name)
                            .font(.subheadline.bold())
                            .lineLimit(1)
                        
                        Text("\(sessionManager.phase.displayName) • \(formattedTime(sessionManager.secondsRemaining))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    // Compact Controls
                    Button {
                        sessionManager.togglePause()
                    } label: {
                        Image(systemName: sessionManager.isPaused ? "play.fill" : "pause.fill")
                            .font(.body)
                            .foregroundStyle(.primary)
                            .frame(width: 32, height: 32)
                    }
                    
                    Button {
                        sessionManager.stopSession()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 32, height: 32)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.1), radius: 5)
                .onTapGesture {
                    showFullPlayer = true
                }
                
                // Minimal Progress Bar
                GeometryReader { geometry in
                    Rectangle()
                        .fill(phaseColor)
                        .frame(width: geometry.size.width * sessionManager.progress)
                }
                .frame(height: 3)
            }
            .padding(.horizontal)
        }
    }
    
    private var phaseColor: Color {
        switch sessionManager.phase {
        case .countdown: return .orange
        case .work: return .green
        case .rest: return .red
        case .setRest: return .blue
        case .complete: return .purple
        }
    }
    
    private func formattedTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
