import SwiftUI

// MARK: - Improved Tabata Card (Train/Motra style)
struct ImprovedTabataCard: View {
    let tabata: Tabata
    let resultCount: Int
    let lastResult: TabataResult?
    @State private var isPressed = false

    var typeColor: Color {
        tabata.type == .intervals ? .orange : .blue
    }

    var typeColors: [Color] {
        tabata.type == .intervals ? [.orange, .pink] : [.blue, .cyan]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header with icon and type badge
            HStack(alignment: .top, spacing: 12) {
                // Icon with gradient
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: typeColors.map { $0.opacity(0.2) },
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)

                    Image(systemName: tabata.type.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: typeColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(tabata.name)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(.primary)

                    HStack(spacing: 6) {
                        Text(tabata.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Circle()
                            .fill(.secondary.opacity(0.5))
                            .frame(width: 3, height: 3)

                        Text(tabata.formattedDuration)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Type badge
                ModernTypeBadge(type: tabata.type)
            }

            // Details with icons
            HStack(spacing: 12) {
                if tabata.type == .intervals {
                    ModernMetadataItem(
                        icon: "repeat.circle.fill",
                        text: "\\(tabata.rounds) rounds",
                        color: typeColor
                    )

                    if tabata.sets > 1 {
                        ModernMetadataItem(
                            icon: "square.stack.3d.up.fill",
                            text: "\\(tabata.sets) sets",
                            color: typeColor
                        )
                    }
                } else {
                    if let phases = tabata.treadmillPhases {
                        ModernMetadataItem(
                            icon: "figure.run",
                            text: "\\(phases.count) fases",
                            color: typeColor
                        )
                    }
                }

                Spacer()

                // Stats badge
                if resultCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                        Text("\\(resultCount)")
                            .font(.caption.bold())
                    }
                    .foregroundStyle(.green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(.green.opacity(0.15))
                    )
                }
            }
        }
        .padding(18)
        .background {
            ZStack {
                // Gradient background
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: typeColors.map { $0.opacity(0.08) },
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // Glass overlay
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .opacity(0.7)
            }
            .shadow(color: typeColor.opacity(0.15), radius: 12, y: 6)
            .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
        }
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .onLongPressGesture(minimumDuration: .infinity) {} onPressingChanged: { pressing in
            isPressed = pressing
            if pressing {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }
    }
}

// MARK: - Modern Type Badge
struct ModernTypeBadge: View {
    let type: TabataType

    var colors: [Color] {
        type == .intervals ? [.orange, .pink] : [.blue, .cyan]
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: type.icon)
                .font(.system(size: 10, weight: .bold))

            Text(type.displayName)
                .font(.system(size: 11, weight: .bold, design: .rounded))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: colors,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .shadow(color: colors.first?.opacity(0.4) ?? .clear, radius: 4, y: 2)
        }
    }
}

// MARK: - Legacy Type Badge (backwards compatibility)
struct TypeBadge: View {
    let type: TabataType

    var body: some View {
        ModernTypeBadge(type: type)
    }
}

// MARK: - Preview
#Preview {
    ScrollView {
        VStack(spacing: 16) {
            ImprovedTabataCard(
                tabata: Tabata.all[0],
                resultCount: 5,
                lastResult: nil
            )
            
            ImprovedTabataCard(
                tabata: Tabata.all[5],
                resultCount: 12,
                lastResult: nil
            )
        }
        .padding()
    }
    .background(Color(uiColor: .systemGroupedBackground))
}
