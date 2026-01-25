import SwiftUI

// MARK: - All1Fit Card Component
/// Modern, distinctive card design for all app screens
/// Features: Clean separation, no navigation arrows, consistent spacing

struct All1FitCard<Content: View>: View {
    let content: Content
    let gradientColors: [Color]

    init(
        gradientColors: [Color] = [.orange, .pink],
        @ViewBuilder content: () -> Content
    ) {
        self.gradientColors = gradientColors
        self.content = content()
    }

    var body: some View {
        content
            .padding(20)
            .background {
                ZStack {
                    // Subtle gradient background
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: gradientColors.map { $0.opacity(0.04) },
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    // Main card background
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))

                    // Accent border on the left
                    HStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                LinearGradient(
                                    colors: gradientColors,
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 4)
                            .padding(.leading, 0)

                        Spacer()
                    }
                }
            }
            .shadow(color: .black.opacity(0.03), radius: 8, y: 4)
    }
}

// MARK: - All1Fit Pressable Card (for tappable items)
struct All1FitPressableCard<Content: View>: View {
    let content: Content
    let gradientColors: [Color]
    @State private var isPressed = false

    init(
        gradientColors: [Color] = [.orange, .pink],
        @ViewBuilder content: () -> Content
    ) {
        self.gradientColors = gradientColors
        self.content = content()
    }

    var body: some View {
        All1FitCard(gradientColors: gradientColors) {
            content
        }
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .onLongPressGesture(minimumDuration: .infinity) {} onPressingChanged: { pressing in
            isPressed = pressing
            if pressing {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }
    }
}

// MARK: - Preview
#Preview {
    ScrollView {
        VStack(spacing: 16) {
            // Example 1: RM Card
            All1FitPressableCard(gradientColors: [.orange, .pink]) {
                HStack(spacing: 16) {
                    // Icon
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.orange.opacity(0.15), .pink.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                        .overlay {
                            Image(systemName: "figure.strengthtraining.traditional")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.orange, .pink],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }

                    // Info
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Sentadilla")
                            .font(.system(.headline, design: .rounded, weight: .bold))

                        Text("Última actualización: Hace 2 días")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    // Value
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("120")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.orange, .pink],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        Text("kg")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Example 2: Workout Card
            All1FitPressableCard(gradientColors: [.red, .pink]) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.red.opacity(0.15), .pink.opacity(0.15)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 48, height: 48)
                            .overlay {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.red, .pink],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Fran")
                                .font(.system(.title3, design: .rounded, weight: .bold))

                            Text("CrossFit • 15 min")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }

                    Text("21-15-9 reps de Thrusters y Pull-ups")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            // Example 3: Tabata Card
            All1FitPressableCard(gradientColors: [.blue, .cyan]) {
                HStack(spacing: 16) {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue.opacity(0.15), .cyan.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                        .overlay {
                            Image(systemName: "timer")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.blue, .cyan],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Cardio Blast")
                            .font(.system(.headline, design: .rounded, weight: .bold))

                        HStack(spacing: 8) {
                            Text("8 rondas")
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                            Text("•")
                                .foregroundStyle(.secondary.opacity(0.5))

                            Text("4:00 min")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()
                }
            }
        }
        .padding()
    }
    .background(Color(uiColor: .systemGroupedBackground))
}
