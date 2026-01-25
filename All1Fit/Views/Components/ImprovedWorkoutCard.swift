import SwiftUI

// MARK: - Improved Workout Card (Train/Motra style)
struct ImprovedWorkoutCard: View {
    let workout: Workout
    let resultCount: Int
    let lastResult: WorkoutResult?
    @State private var isPressed = false

    var categoryColor: Color {
        switch workout.category {
        case .running: return .orange
        case .crossfit: return .red
        case .competition: return .purple
        }
    }

    var categoryColors: [Color] {
        switch workout.category {
        case .running: return [.orange, .yellow]
        case .crossfit: return [.red, .pink]
        case .competition: return [.purple, .blue]
        }
    }

    var difficultyColor: Color {
        switch workout.difficulty {
        case .beginner: return .green
        case .intermediate: return .blue
        case .advanced: return .orange
        case .elite: return .purple
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header with title and difficulty
            HStack(alignment: .top, spacing: 12) {
                // Icon with gradient
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: categoryColors.map { $0.opacity(0.2) },
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)

                    Image(systemName: workout.isForTime ? "stopwatch.fill" : "infinity")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: categoryColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.name)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(.primary)

                    HStack(spacing: 6) {
                        Text(workout.category.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Circle()
                            .fill(.secondary.opacity(0.5))
                            .frame(width: 3, height: 3)

                        Text("\\(workout.estimatedDurationMinutes) min")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Difficulty badge
                ModernDifficultyBadge(difficulty: workout.difficulty)
            }

            // Description with subtle background
            Text(workout.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(categoryColor.opacity(0.05))
                )

            // Metadata row with icons
            HStack(spacing: 12) {
                ModernMetadataItem(
                    icon: workout.isForTime ? "timer" : "arrow.triangle.2.circlepath",
                    text: workout.isForTime ? "For Time" : "AMRAP",
                    color: categoryColor
                )

                if !workout.equipment.isEmpty {
                    ModernMetadataItem(
                        icon: "dumbbell.fill",
                        text: "\\(workout.equipment.count)",
                        color: categoryColor
                    )
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

            // Tags with shimmer effect
            if !workout.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(workout.tags.prefix(3), id: \\.self) { tag in
                            ModernTagPill(text: tag, colors: categoryColors)
                        }
                    }
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
                            colors: categoryColors.map { $0.opacity(0.08) },
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // Glass overlay
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .opacity(0.7)
            }
            .shadow(color: categoryColor.opacity(0.15), radius: 12, y: 6)
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

// MARK: - Modern Difficulty Badge
struct ModernDifficultyBadge: View {
    let difficulty: DifficultyLevel

    var color: Color {
        switch difficulty {
        case .beginner: return .green
        case .intermediate: return .blue
        case .advanced: return .orange
        case .elite: return .purple
        }
    }

    var colors: [Color] {
        switch difficulty {
        case .beginner: return [.green, .mint]
        case .intermediate: return [.blue, .cyan]
        case .advanced: return [.orange, .yellow]
        case .elite: return [.purple, .pink]
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: difficulty.icon)
                .font(.system(size: 10, weight: .bold))

            Text(difficulty.rawValue)
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
                .shadow(color: color.opacity(0.4), radius: 4, y: 2)
        }
    }
}

// MARK: - Legacy Difficulty Badge (for backwards compatibility)
struct DifficultyBadge: View {
    let difficulty: DifficultyLevel

    var body: some View {
        ModernDifficultyBadge(difficulty: difficulty)
    }
}

// MARK: - Modern Metadata Item
struct ModernMetadataItem: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 28, height: 28)

                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(color)
            }

            Text(text)
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Modern Tag Pill
struct ModernTagPill: View {
    let text: String
    let colors: [Color]

    var body: some View {
        Text(text)
            .font(.system(.caption2, design: .rounded, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: colors.map { $0.opacity(0.8) },
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
    }
}

// MARK: - Legacy Components (backwards compatibility)
struct MetadataItem: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        ModernMetadataItem(icon: icon, text: text, color: color)
    }
}

struct TagPill: View {
    let text: String
    let color: Color

    var body: some View {
        ModernTagPill(text: text, colors: [color, color.opacity(0.7)])
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let accentColor: Color
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundStyle(accentColor.opacity(0.5))
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview
#Preview {
    ScrollView {
        VStack(spacing: 16) {
            ImprovedWorkoutCard(
                workout: Workout.all[0],
                resultCount: 5,
                lastResult: nil
            )
            
            ImprovedWorkoutCard(
                workout: Workout.all[4],
                resultCount: 12,
                lastResult: nil
            )
        }
        .padding()
    }
    .background(Color(uiColor: .systemGroupedBackground))
}
