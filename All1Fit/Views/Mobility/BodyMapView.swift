import SwiftUI

// MARK: - Body Map View
/// Interactive human body silhouette with tappable zones
struct BodyMapView: View {
    @Binding var selectedZone: BodyZone
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Body silhouette background
                bodyBackground
                
                // Human figure
                VStack(spacing: 0) {
                    // Head
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 50, height: 50)
                    
                    // Neck
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 20, height: 15)
                    
                    // Torso with shoulder hotspots
                    ZStack {
                        // Torso
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 100, height: 120)
                        
                        // Shoulder hotspots
                        HStack(spacing: 70) {
                            // Left shoulder
                            shoulderHotspot
                            
                            // Right shoulder
                            shoulderHotspot
                        }
                        .offset(y: -35)
                    }
                    
                    // Hip area
                    ZStack {
                        // Pelvis
                        Ellipse()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 100, height: 50)
                        
                        // Hip hotspots
                        HStack(spacing: 50) {
                            hipHotspot
                            hipHotspot
                        }
                    }
                    
                    // Legs
                    HStack(spacing: 15) {
                        // Left leg
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 35, height: 120)
                        
                        // Right leg
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 35, height: 120)
                    }
                }
                
                // Zone labels
                VStack {
                    // Shoulder label
                    if selectedZone == .shoulders {
                        Text("HOMBROS")
                            .font(.caption.bold())
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.orange.opacity(0.2))
                            .clipShape(Capsule())
                            .transition(.scale.combined(with: .opacity))
                    }
                    
                    Spacer()
                    
                    // Hip label
                    if selectedZone == .hips {
                        Text("CADERA")
                            .font(.caption.bold())
                            .foregroundStyle(.purple)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.purple.opacity(0.2))
                            .clipShape(Capsule())
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(maxHeight: .infinity)
                .padding(.vertical, 30)
                .animation(.spring(duration: 0.3), value: selectedZone)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    // MARK: - Body Background
    private var bodyBackground: some View {
        RoundedRectangle(cornerRadius: 24)
            .fill(Color(uiColor: .secondarySystemGroupedBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(
                        LinearGradient(
                            colors: [.orange.opacity(0.3), .purple.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
            )
    }
    
    // MARK: - Shoulder Hotspot
    private var shoulderHotspot: some View {
        Button {
            withAnimation(.spring(duration: 0.3)) {
                selectedZone = .shoulders
            }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } label: {
            ZStack {
                // Glow effect when selected
                if selectedZone == .shoulders {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.orange.opacity(0.5), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 30
                            )
                        )
                        .frame(width: 60, height: 60)
                }
                
                // Hotspot circle
                Circle()
                    .fill(selectedZone == .shoulders ? Color.orange : Color.orange.opacity(0.3))
                    .frame(width: 30, height: 30)
                    .overlay(
                        Circle()
                            .stroke(Color.orange, lineWidth: selectedZone == .shoulders ? 3 : 1)
                    )
                    .scaleEffect(selectedZone == .shoulders ? 1.2 : 1.0)
            }
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Hip Hotspot
    private var hipHotspot: some View {
        Button {
            withAnimation(.spring(duration: 0.3)) {
                selectedZone = .hips
            }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } label: {
            ZStack {
                // Glow effect when selected
                if selectedZone == .hips {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.purple.opacity(0.5), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 30
                            )
                        )
                        .frame(width: 60, height: 60)
                }
                
                // Hotspot circle
                Circle()
                    .fill(selectedZone == .hips ? Color.purple : Color.purple.opacity(0.3))
                    .frame(width: 30, height: 30)
                    .overlay(
                        Circle()
                            .stroke(Color.purple, lineWidth: selectedZone == .hips ? 3 : 1)
                    )
                    .scaleEffect(selectedZone == .hips ? 1.2 : 1.0)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    BodyMapView(selectedZone: .constant(.shoulders))
        .frame(height: 400)
        .padding()
}
