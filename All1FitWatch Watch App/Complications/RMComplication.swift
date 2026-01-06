import SwiftUI
import WidgetKit

// MARK: - Watch Complication Provider
struct RMComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> RMEntry {
        RMEntry(date: Date(), exerciseName: "Back Squat", rmValue: 120, unit: "kg")
    }
    
    func getSnapshot(in context: Context, completion: @escaping (RMEntry) -> Void) {
        // Get cached favorite exercise
        let entry = getCachedEntry()
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<RMEntry>) -> Void) {
        let entry = getCachedEntry()
        // Refresh every hour
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    private func getCachedEntry() -> RMEntry {
        // Try to get favorite exercise from UserDefaults (synced from phone)
        if let data = UserDefaults.standard.data(forKey: "cachedEjercicios"),
           let ejercicios = try? JSONDecoder().decode([WatchEjercicio].self, from: data),
           let first = ejercicios.first,
           let rm = first.ultimoRM {
            return RMEntry(
                date: Date(),
                exerciseName: first.name,
                rmValue: rm.valor,
                unit: "kg"
            )
        }
        
        // Fallback
        return RMEntry(date: Date(), exerciseName: "Sin datos", rmValue: 0, unit: "kg")
    }
}

// MARK: - RM Entry
struct RMEntry: TimelineEntry {
    let date: Date
    let exerciseName: String
    let rmValue: Double
    let unit: String
    
    var formattedRM: String {
        if rmValue.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(rmValue))"
        }
        return String(format: "%.1f", rmValue)
    }
}

// MARK: - Complication Views
struct RMComplicationView: View {
    var entry: RMEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .accessoryCircular:
            circularView
        case .accessoryCorner:
            cornerView
        case .accessoryRectangular:
            rectangularView
        case .accessoryInline:
            inlineView
        default:
            circularView
        }
    }
    
    // MARK: - Circular
    private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            
            VStack(spacing: 0) {
                Image(systemName: "dumbbell.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                
                Text(entry.formattedRM)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .minimumScaleFactor(0.5)
                
                Text(entry.unit)
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    // MARK: - Corner
    private var cornerView: some View {
        Text(entry.formattedRM)
            .font(.system(.title2, design: .rounded, weight: .bold))
            .foregroundStyle(.orange)
            .widgetCurvesContent()
            .widgetLabel {
                Text("\(entry.exerciseName) RM")
            }
    }
    
    // MARK: - Rectangular
    private var rectangularView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "dumbbell.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                    
                    Text(entry.exerciseName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(entry.formattedRM)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                    
                    Text(entry.unit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
        }
    }
    
    // MARK: - Inline
    private var inlineView: some View {
        HStack(spacing: 4) {
            Image(systemName: "dumbbell.fill")
            Text("\(entry.exerciseName): \(entry.formattedRM) \(entry.unit)")
        }
    }
}

struct RMComplication: Widget {
    let kind: String = "com.idanidev.All1Fit.watchkitapp.complication"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RMComplicationProvider()) { entry in
            RMComplicationView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("RM Actual")
        .description("Muestra tu RM más reciente")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryCorner,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

// MARK: - Previews
#Preview("Circular", as: .accessoryCircular) {
    RMComplication()
} timeline: {
    RMEntry(date: Date(), exerciseName: "Back Squat", rmValue: 120, unit: "kg")
}

#Preview("Rectangular", as: .accessoryRectangular) {
    RMComplication()
} timeline: {
    RMEntry(date: Date(), exerciseName: "Back Squat", rmValue: 120, unit: "kg")
}

#Preview("Corner", as: .accessoryCorner) {
    RMComplication()
} timeline: {
    RMEntry(date: Date(), exerciseName: "Back Squat", rmValue: 120, unit: "kg")
}
