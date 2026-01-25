import WidgetKit
import SwiftUI
import ActivityKit

// MARK: - Tabata Live Activity Widget
@main
struct All1FitWidgetsBundle: WidgetBundle {
    var body: some Widget {
        TabataLiveActivity()
    }
}

struct TabataLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TabataActivityAttributes.self) { context in
            // Lock Screen / Banner UI
            TabataLockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI - Redesigned
                DynamicIslandExpandedRegion(.leading) {
                    TabataExpandedLeading(context: context)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    TabataExpandedTrailing(context: context)
                }

                DynamicIslandExpandedRegion(.center) {
                    TabataExpandedCenter(context: context)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    TabataExpandedBottom(context: context)
                }
            } compactLeading: {
                TabataCompactLeading(context: context)
            } compactTrailing: {
                TabataCompactTrailing(context: context)
            } minimal: {
                TabataMinimalView(context: context)
            }
        }
    }
}

// MARK: - Lock Screen View
struct TabataLockScreenView: View {
    let context: ActivityViewContext<TabataActivityAttributes>

    private var phaseColor: Color {
        switch context.state.currentPhase {
        case "work": return .green
        case "rest": return .red
        case "countdown": return .orange
        case "complete": return .purple
        default: return .orange
        }
    }

    private var progress: CGFloat {
        context.state.progress
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left side: Large progress ring
            ZStack {
                // Background ring
                Circle()
                    .stroke(phaseColor.opacity(0.2), lineWidth: 8)
                    .frame(width: 80, height: 80)

                // Progress ring with animation
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(
                            colors: [phaseColor, phaseColor.opacity(0.6)],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)

                // Center content
                VStack(spacing: 2) {
                    if context.state.totalRounds > 0 && context.state.currentPhase != "complete" {
                        Text("\(context.state.currentRound)")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(phaseColor)
                            .contentTransition(.numericText())

                        Text("/\(context.state.totalRounds)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                    } else if context.state.currentPhase == "complete" {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(.green)
                            .symbolEffect(.bounce, value: context.state.currentPhase)
                    } else {
                        Image(systemName: "figure.run")
                            .font(.system(size: 32))
                            .foregroundStyle(phaseColor)
                            .symbolEffect(.pulse)
                    }
                }
            }
            .padding(.leading, 16)
            .padding(.vertical, 12)

            // Right side: Info
            VStack(alignment: .leading, spacing: 6) {
                Text(context.attributes.tabataName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(context.state.phaseDisplayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(phaseColor)
                    .contentTransition(.interpolate)

                if context.state.currentPhase != "complete" {
                    HStack(spacing: 4) {
                        Image(systemName: "timer")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)

                        Text(timerInterval: Date()...context.state.endTime, countsDown: true)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                            .contentTransition(.numericText())
                    }
                } else {
                    Text("¡Completado!")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.green)
                }

                if let _ = context.state.treadmillPhaseName,
                   let incline = context.state.treadmillIncline,
                   let speed = context.state.treadmillSpeed {
                    HStack(spacing: 4) {
                        Image(systemName: "figure.walk")
                            .font(.system(size: 10))
                        Text("\(Int(incline))% • \(String(format: "%.1f", speed)) km/h")
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.leading, 12)
            .padding(.trailing, 16)
            .padding(.vertical, 12)

            Spacer()
        }
        .background(Color(uiColor: .systemBackground))
    }
}

// MARK: - Dynamic Island Expanded Views (IMPROVED)
struct TabataExpandedLeading: View {
    let context: ActivityViewContext<TabataActivityAttributes>

    private var phaseColor: Color {
        switch context.state.currentPhase {
        case "work": return .green
        case "rest": return .red
        case "countdown": return .orange
        case "complete": return .purple
        default: return .orange
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Round indicator with icon
            HStack(spacing: 4) {
                Circle()
                    .fill(phaseColor.gradient)
                    .frame(width: 8, height: 8)

                if context.state.totalRounds > 0 {
                    Text("\(context.state.currentRound)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(phaseColor)
                        .contentTransition(.numericText())

                    Text("/\(context.state.totalRounds)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }

            // Phase name
            Text(context.state.phaseDisplayName)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
        }
    }
}

struct TabataExpandedTrailing: View {
    let context: ActivityViewContext<TabataActivityAttributes>

    private var phaseColor: Color {
        switch context.state.currentPhase {
        case "work": return .green
        case "rest": return .red
        case "countdown": return .orange
        case "complete": return .purple
        default: return .orange
        }
    }

    private var phaseIcon: String {
        switch context.state.currentPhase {
        case "work": return "flame.fill"
        case "rest": return "wind"
        case "countdown": return "timer"
        case "complete": return "checkmark.circle.fill"
        default: return "timer"
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            // Animated icon
            Image(systemName: phaseIcon)
                .font(.system(size: 24))
                .foregroundStyle(phaseColor.gradient)
                .symbolEffect(.pulse, options: .repeating, value: context.state.currentPhase)

            // Progress percentage
            Text("\(Int(context.state.progress * 100))%")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
        }
    }
}

struct TabataExpandedCenter: View {
    let context: ActivityViewContext<TabataActivityAttributes>

    private var phaseColor: Color {
        switch context.state.currentPhase {
        case "work": return .green
        case "rest": return .red
        case "countdown": return .orange
        case "complete": return .purple
        default: return .orange
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            if context.state.currentPhase != "complete" {
                // Big timer
                Text(timerInterval: Date()...context.state.endTime, countsDown: true)
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(phaseColor.gradient)
                    .contentTransition(.numericText())

                // Tabata name
                Text(context.attributes.tabataName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                // Completion state
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.green.gradient)
                        .symbolEffect(.bounce, value: context.state.currentPhase)

                    Text("¡Completado!")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.green)
                }
            }
        }
    }
}

struct TabataExpandedBottom: View {
    let context: ActivityViewContext<TabataActivityAttributes>

    private var phaseColor: Color {
        switch context.state.currentPhase {
        case "work": return .green
        case "rest": return .red
        case "countdown": return .orange
        case "complete": return .purple
        default: return .orange
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            // Progress bar with better visual
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    Capsule()
                        .fill(.tertiary)
                        .frame(height: 8)

                    // Progress with gradient
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [phaseColor.opacity(0.8), phaseColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(8, geometry.size.width * context.state.progress), height: 8)
                        .animation(.linear(duration: 1), value: context.state.progress)
                }
            }
            .frame(height: 8)

            // Treadmill info if applicable
            if let phaseName = context.state.treadmillPhaseName,
               let incline = context.state.treadmillIncline,
               let speed = context.state.treadmillSpeed {
                HStack(spacing: 8) {
                    Label {
                        Text("\(Int(incline))%")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                    } icon: {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 9))
                    }

                    Label {
                        Text("\(String(format: "%.1f", speed)) km/h")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                    } icon: {
                        Image(systemName: "speedometer")
                            .font(.system(size: 9))
                    }

                    Spacer()

                    Text(phaseName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(phaseColor)
            }
        }
    }
}

// MARK: - Dynamic Island Compact Views (IMPROVED)
struct TabataCompactLeading: View {
    let context: ActivityViewContext<TabataActivityAttributes>

    private var phaseColor: Color {
        switch context.state.currentPhase {
        case "work": return .green
        case "rest": return .red
        case "countdown": return .orange
        case "complete": return .purple
        default: return .orange
        }
    }

    var body: some View {
        HStack(spacing: 3) {
            // Animated pulse indicator
            Circle()
                .fill(phaseColor.gradient)
                .frame(width: 6, height: 6)
                .symbolEffect(.pulse, options: .repeating)

            if context.state.totalRounds > 0 && context.state.currentPhase != "complete" {
                Text("\(context.state.currentRound)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(phaseColor)
                    .contentTransition(.numericText())
            }
        }
    }
}

struct TabataCompactTrailing: View {
    let context: ActivityViewContext<TabataActivityAttributes>

    private var phaseColor: Color {
        switch context.state.currentPhase {
        case "work": return .green
        case "rest": return .red
        case "countdown": return .orange
        case "complete": return .purple
        default: return .orange
        }
    }

    var body: some View {
        if context.state.currentPhase != "complete" {
            Text(timerInterval: Date()...context.state.endTime, countsDown: true)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(phaseColor)
                .contentTransition(.numericText())
        } else {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(.green)
                .symbolEffect(.bounce, value: context.state.currentPhase)
        }
    }
}

// MARK: - Minimal View (IMPROVED)
struct TabataMinimalView: View {
    let context: ActivityViewContext<TabataActivityAttributes>

    private var phaseColor: Color {
        switch context.state.currentPhase {
        case "work": return .green
        case "rest": return .red
        case "countdown": return .orange
        case "complete": return .purple
        default: return .orange
        }
    }

    var body: some View {
        ZStack {
            if context.state.currentPhase != "complete" {
                // Progress ring
                Circle()
                    .trim(from: 0, to: context.state.progress)
                    .stroke(phaseColor, lineWidth: 2)
                    .frame(width: 16, height: 16)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: context.state.progress)

                // Timer seconds
                Text("\(context.state.secondsRemaining)")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundStyle(phaseColor)
                    .contentTransition(.numericText())
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.green)
                    .symbolEffect(.bounce, value: context.state.currentPhase)
            }
        }
    }
}

// MARK: - Previews
#Preview("Lock Screen", as: .content, using: TabataActivityAttributes(
    tabataName: "🔥 Infierno",
    tabataId: "test",
    totalRounds: 10,
    workSeconds: 30,
    restSeconds: 10,
    isIntervalType: true
)) {
    TabataLiveActivity()
} contentStates: {
    TabataActivityAttributes.ContentState.work(round: 3, totalRounds: 10, seconds: 18)
    TabataActivityAttributes.ContentState.rest(round: 3, totalRounds: 10, seconds: 8)
    TabataActivityAttributes.ContentState.complete()
}
