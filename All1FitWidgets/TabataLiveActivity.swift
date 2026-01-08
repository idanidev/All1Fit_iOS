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
                // Expanded UI
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
                // Compact leading
                TabataCompactLeading(context: context)
            } compactTrailing: {
                // Compact trailing
                TabataCompactTrailing(context: context)
            } minimal: {
                // Minimal view when other apps are using Dynamic Island
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
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(phaseColor.gradient)
                    .frame(width: 50, height: 50)
                
                Image(systemName: "timer")
                    .font(.title2)
                    .foregroundStyle(.white)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(context.attributes.tabataName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                HStack(spacing: 8) {
                    Text(context.state.phaseDisplayName)
                        .font(.subheadline.bold())
                        .foregroundStyle(phaseColor)
                    
                    if context.state.totalRounds > 0 {
                        Text("•")
                        Text("R\(context.state.currentRound)/\(context.state.totalRounds)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Timer
            if context.state.currentPhase != "complete" {
                Text(timerInterval: Date()...context.state.endTime, countsDown: true)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(phaseColor)
                    .frame(minWidth: 80)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.green)
            }
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
    }
}

// MARK: - Lock Screen View
// This view is no longer used as its content has been moved directly into ActivityConfiguration
// struct TabataLockScreenView: View {
//     let context: ActivityViewContext<TabataActivityAttributes>
    
//     private var phaseColor: Color {
//         switch context.state.currentPhase {
//         case "work": return .green
//         case "rest": return .red
//         case "countdown": return .orange
//         case "complete": return .purple
//         default: return .orange
//         }
//     }
    
//     var body: some View {
//         HStack(spacing: 16) {
//             // Icon
//             ZStack {
//                 Circle()
//                     .fill(phaseColor.gradient)
//                     .frame(width: 50, height: 50)
                
//                 Image(systemName: "timer")
//                     .font(.title2)
//                     .foregroundStyle(.white)
//             }
            
//             // Info
//             VStack(alignment: .leading, spacing: 4) {
//                 Text(context.attributes.tabataName)
//                     .font(.headline)
//                     .foregroundStyle(.primary)
                
//                 HStack(spacing: 8) {
//                     Text(context.state.phaseDisplayName)
//                         .font(.subheadline.bold())
//                         .foregroundStyle(phaseColor)
                    
//                     if context.state.totalRounds > 0 {
//                         Text("•")
//                         Text("R\(context.state.currentRound)/\(context.state.totalRounds)")
//                             .font(.subheadline)
//                             .foregroundStyle(.secondary)
//                     }
//                 }
//             }
            
//             Spacer()
            
//             // Timer
//             if context.state.currentPhase != "complete" {
//                 Text(timerInterval: Date()...context.state.endTime, countsDown: true)
//                     .font(.system(size: 32, weight: .bold, design: .rounded))
//                     .monospacedDigit()
//                     .foregroundStyle(phaseColor)
//                     .frame(minWidth: 80)
//             } else {
//                 Image(systemName: "checkmark.circle.fill")
//                     .font(.system(size: 32))
//                     .foregroundStyle(.green)
//             }
//         }
//         .padding()
//         .background(Color(uiColor: .systemBackground))
//     }
// }

// MARK: - Dynamic Island Expanded Views
struct TabataExpandedLeading: View {
    let context: ActivityViewContext<TabataActivityAttributes>
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(context.attributes.tabataName)
                .font(.caption2)
                .foregroundStyle(.secondary)
            
            if context.state.totalRounds > 0 {
                Text("R\(context.state.currentRound)/\(context.state.totalRounds)")
                    .font(.headline)
            }
        }
    }
}

struct TabataExpandedTrailing: View {
    let context: ActivityViewContext<TabataActivityAttributes>
    
    private var phaseColor: Color {
        switch context.state.currentPhase {
        case "work": return .green
        case "rest": return .red
        default: return .orange
        }
    }
    
    var body: some View {
        VStack(alignment: .trailing) {
            Text(context.state.phaseDisplayName)
                .font(.caption)
                .foregroundStyle(phaseColor)
            
            // For treadmill mode
            if let incline = context.state.treadmillIncline,
               let speed = context.state.treadmillSpeed {
                HStack(spacing: 4) {
                    Text("\(Int(incline))%")
                    Text("•")
                    Text("\(String(format: "%.1f", speed))km/h")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
    }
}

struct TabataExpandedCenter: View {
    let context: ActivityViewContext<TabataActivityAttributes>
    
    private var phaseColor: Color {
        switch context.state.currentPhase {
        case "work": return .green
        case "rest": return .red
        default: return .orange
        }
    }
    
    var body: some View {
        if context.state.currentPhase != "complete" {
            Text(timerInterval: Date()...context.state.endTime, countsDown: true)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(phaseColor)
        } else {
            Text("🎉")
                .font(.system(size: 48))
        }
    }
}

struct TabataExpandedBottom: View {
    let context: ActivityViewContext<TabataActivityAttributes>
    
    private var phaseColor: Color {
        switch context.state.currentPhase {
        case "work": return .green
        case "rest": return .red
        default: return .orange
        }
    }
    
    var body: some View {
        // Progress bar
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 6)
                
                Capsule()
                    .fill(phaseColor.gradient)
                    .frame(width: geometry.size.width * context.state.progress, height: 6)
            }
        }
        .frame(height: 6)
    }
}

// MARK: - Dynamic Island Compact Views
struct TabataCompactLeading: View {
    let context: ActivityViewContext<TabataActivityAttributes>
    
    private var phaseColor: Color {
        switch context.state.currentPhase {
        case "work": return .green
        case "rest": return .red
        default: return .orange
        }
    }
    
    var body: some View {
        // Just the round indicator - minimal
        if context.state.totalRounds > 0 {
            Text("\(context.state.currentRound)/\(context.state.totalRounds)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(phaseColor)
        } else {
            Image(systemName: "timer")
                .font(.system(size: 10))
                .foregroundStyle(phaseColor)
        }
    }
}

struct TabataCompactTrailing: View {
    let context: ActivityViewContext<TabataActivityAttributes>
    
    private var phaseColor: Color {
        switch context.state.currentPhase {
        case "work": return .green
        case "rest": return .red
        default: return .orange
        }
    }
    
    var body: some View {
        if context.state.currentPhase != "complete" {
            Text(timerInterval: Date()...context.state.endTime, countsDown: true)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(phaseColor)
        } else {
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.green)
        }
    }
}

// MARK: - Minimal View
struct TabataMinimalView: View {
    let context: ActivityViewContext<TabataActivityAttributes>
    
    private var phaseColor: Color {
        switch context.state.currentPhase {
        case "work": return .green
        case "rest": return .red
        default: return .orange
        }
    }
    
    var body: some View {
        // Show timer text instead of just icon
        if context.state.currentPhase != "complete" {
            Text(timerInterval: Date()...context.state.endTime, countsDown: true)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(phaseColor)
        } else {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(.green)
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
