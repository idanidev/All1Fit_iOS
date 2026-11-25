import WidgetKit
import SwiftUI
import ActivityKit

// MARK: - Widget Bundle
@main
struct All1FitWidgetsBundle: WidgetBundle {
    var body: some Widget {
        TabataLiveActivity()
    }
}

// MARK: - Activity Configuration
struct TabataLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TabataActivityAttributes.self) { context in
            TabataLockScreenView(context: context)
                .activityBackgroundTint(Color.black)
                .activitySystemActionForegroundColor(Color.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    DIExpandedLeading(context: context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    DIExpandedTrailing(context: context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    DIExpandedBottom(context: context)
                }
            } compactLeading: {
                DICompactLeading(context: context)
            } compactTrailing: {
                DICompactTrailing(context: context)
            } minimal: {
                DIMinimal(context: context)
            }
            .keylineTint(LADesign.phaseColor(context.state.currentPhase))
            .widgetURL(URL(string: "all1fit://tabata"))
        }
    }
}

// MARK: - Design Tokens (matches All1Fit Design System)
private enum LADesign {
    // Tabata brand gradient (Blue → Cyan per design.md)
    static let tabataStart = Color(red: 0.04, green: 0.52, blue: 1.0)
    static let tabataEnd   = Color(red: 0.19, green: 0.82, blue: 0.95)

    static func phaseColor(_ phase: String) -> Color {
        switch phase {
        case "work":      Color(red: 0.19, green: 0.82, blue: 0.35)
        case "rest":      Color(red: 1.0, green: 0.27, blue: 0.23)
        case "countdown": Color(red: 1.0, green: 0.58, blue: 0.0)
        case "setRest":   Color(red: 1.0, green: 0.82, blue: 0.0)
        case "complete":  tabataEnd
        default:          tabataStart
        }
    }

    static func phaseGradient(_ phase: String) -> LinearGradient {
        let c = phaseColor(phase)
        return LinearGradient(
            colors: [c, c.opacity(0.7)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func phaseLabel(_ phase: String) -> String {
        switch phase {
        case "work":      "Trabajo"
        case "rest":      "Descanso"
        case "countdown": "Preparado"
        case "setRest":   "Descanso serie"
        case "complete":  "Completado"
        default:          phase.capitalized
        }
    }

    static func phaseIcon(_ phase: String) -> String {
        switch phase {
        case "work":      "flame.fill"
        case "rest":      "leaf.fill"
        case "countdown": "timer"
        case "setRest":   "pause.fill"
        case "complete":  "checkmark.seal.fill"
        default:          "timer"
        }
    }
}

// MARK: - Timer (nativo con countdown, seguro y respeta pausa)
/// Usa el contador nativo `timerInterval` solo cuando corre y `endTime` es
/// futuro. Si está en pausa o `endTime` ya pasó, muestra el tiempo estático:
/// evita el crash de `Date()...endTime` con rango invertido (lowerBound > upperBound).
@ViewBuilder
func liveTimerText(_ state: TabataActivityAttributes.ContentState) -> some View {
    if !state.isPaused && state.endTime > Date() {
        Text(timerInterval: Date()...state.endTime, countsDown: true)
    } else {
        Text(state.formattedTime)
    }
}

// MARK: - Lock Screen / Banner
struct TabataLockScreenView: View {
    let context: ActivityViewContext<TabataActivityAttributes>

    private var color: Color { LADesign.phaseColor(context.state.currentPhase) }
    private var isComplete: Bool { context.state.currentPhase == "complete" }

    var body: some View {
        HStack(spacing: 12) {
            // Phase block
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(LADesign.phaseGradient(context.state.currentPhase))
                Image(systemName: LADesign.phaseIcon(context.state.currentPhase))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 44, height: 44)

            // Info
            VStack(alignment: .leading, spacing: 1) {
                Text(context.attributes.tabataName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)

                Text(context.state.treadmillPhaseName ?? LADesign.phaseLabel(context.state.currentPhase))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                if context.state.totalRounds > 0 && !isComplete {
                    if let incline = context.state.treadmillIncline,
                       let speed = context.state.treadmillSpeed {
                        Text("\(Int(incline))% · \(String(format: "%.1f", speed)) km/h · \(context.state.currentRound)/\(context.state.totalRounds)")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.45))
                            .lineLimit(1)
                    } else {
                        Text("Ronda \(context.state.currentRound)/\(context.state.totalRounds)")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.45))
                            .contentTransition(.numericText())
                    }
                }
            }

            Spacer(minLength: 4)

            // Timer
            if !isComplete {
                liveTimerText(context.state)
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(color)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            } else {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(color)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// MARK: - Dynamic Island Expanded

struct DIExpandedLeading: View {
    let context: ActivityViewContext<TabataActivityAttributes>
    private var color: Color { LADesign.phaseColor(context.state.currentPhase) }

    var body: some View {
        HStack(spacing: 8) {
            // Phase chip
            HStack(spacing: 5) {
                Image(systemName: LADesign.phaseIcon(context.state.currentPhase))
                    .font(.system(size: 11, weight: .bold))
                Text(LADesign.phaseLabel(context.state.currentPhase))
                    .font(.system(size: 12, weight: .bold))
                    .lineLimit(1)
            }
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Capsule().fill(color.opacity(0.18)))

            // Round
            if context.state.totalRounds > 0 && context.state.currentPhase != "complete" {
                Text("\(context.state.currentRound)/\(context.state.totalRounds)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                    .contentTransition(.numericText())
            }
        }
        .padding(.leading, 4)
    }
}

struct DIExpandedTrailing: View {
    let context: ActivityViewContext<TabataActivityAttributes>
    private var color: Color { LADesign.phaseColor(context.state.currentPhase) }

    var body: some View {
        // Hero timer
        if context.state.currentPhase != "complete" {
            liveTimerText(context.state)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(minWidth: 64, alignment: .trailing)
                .padding(.trailing, 4)
        } else {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 22))
                .foregroundStyle(color)
                .padding(.trailing, 4)
        }
    }
}

struct DIExpandedBottom: View {
    let context: ActivityViewContext<TabataActivityAttributes>
    private var color: Color { LADesign.phaseColor(context.state.currentPhase) }

    var body: some View {
        VStack(spacing: 6) {
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.12))
                        .frame(height: 5)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.7), color],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(5, geo.size.width * context.state.progress), height: 5)
                        .animation(.linear(duration: 1), value: context.state.progress)
                }
            }
            .frame(height: 5)

            // Bottom info row
            HStack(spacing: 4) {
                Text(context.state.treadmillPhaseName ?? context.attributes.tabataName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)

                Spacer()

                if let incline = context.state.treadmillIncline,
                   let speed = context.state.treadmillSpeed {
                    Text("\(Int(incline))% · \(String(format: "%.1f", speed)) km/h")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(color.opacity(0.85))
                        .lineLimit(1)
                } else {
                    Text("\(Int(context.state.progress * 100))%")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(color.opacity(0.7))
                        .contentTransition(.numericText())
                }
            }
        }
        .padding(.top, 2)
    }
}

// MARK: - Dynamic Island Compact

struct DICompactLeading: View {
    let context: ActivityViewContext<TabataActivityAttributes>
    private var color: Color { LADesign.phaseColor(context.state.currentPhase) }

    var body: some View {
        if context.state.totalRounds > 0 && context.state.currentPhase != "complete" {
            Text("\(context.state.currentRound)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .contentTransition(.numericText())
        } else {
            Image(systemName: LADesign.phaseIcon(context.state.currentPhase))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
        }
    }
}

struct DICompactTrailing: View {
    let context: ActivityViewContext<TabataActivityAttributes>
    private var color: Color { LADesign.phaseColor(context.state.currentPhase) }

    var body: some View {
        if context.state.currentPhase != "complete" {
            liveTimerText(context.state)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
                .contentTransition(.numericText())
                .fixedSize()
        } else {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
        }
    }
}

// MARK: - Minimal
struct DIMinimal: View {
    let context: ActivityViewContext<TabataActivityAttributes>
    private var color: Color { LADesign.phaseColor(context.state.currentPhase) }

    var body: some View {
        ZStack {
            // Progress ring
            Circle()
                .stroke(color.opacity(0.25), lineWidth: 2)
            Circle()
                .trim(from: 0, to: context.state.progress)
                .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: context.state.progress)

            // Phase icon
            Image(systemName: LADesign.phaseIcon(context.state.currentPhase))
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(color)
        }
        .frame(width: 22, height: 22)
    }
}

// MARK: - Previews
#Preview("Lock Screen", as: .content, using: TabataActivityAttributes(
    tabataName: "Infierno HIIT",
    tabataId: "test",
    totalRounds: 10,
    workSeconds: 30,
    restSeconds: 10,
    isIntervalType: true
)) {
    TabataLiveActivity()
} contentStates: {
    TabataActivityAttributes.ContentState.work(round: 3, totalRounds: 10, seconds: 18)
    TabataActivityAttributes.ContentState.rest(round: 5, totalRounds: 10, seconds: 8)
    TabataActivityAttributes.ContentState.countdown(seconds: 5)
    TabataActivityAttributes.ContentState.complete()
}
