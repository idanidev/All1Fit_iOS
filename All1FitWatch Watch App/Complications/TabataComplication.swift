import SwiftUI
import WidgetKit
import WatchKit

// MARK: - Tabata Complication
struct TabataComplication: View {
    let context: TimelineProviderContext
    
    var body: some View {
        switch context.family {
        case .accessoryCircular:
            circularView
        case .accessoryRectangular:
            rectangularView
        case .accessoryInline:
            inlineView
        case .accessoryCorner:
            cornerView
        default:
            circularView
        }
    }
    
    // MARK: - Circular (Button style)
    private var circularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            
            VStack(spacing: 2) {
                Image(systemName: "flame.fill")
                    .font(.title3)
                    .foregroundStyle(.orange)
                
                Text("HIIT")
                    .font(.system(size: 10, weight: .bold))
            }
        }
    }
    
    // MARK: - Rectangular (More info)
    private var rectangularView: some View {
        HStack(spacing: 8) {
            Image(systemName: "flame.fill")
                .font(.title2)
                .foregroundStyle(.orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Infierno")
                    .font(.headline)
                
                Text("30/10 × 10 rondas")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Inline (Single line)
    private var inlineView: some View {
        Label("Tabata HIIT", systemImage: "flame.fill")
    }
    
    // MARK: - Corner
    private var cornerView: some View {
        Image(systemName: "flame.fill")
            .font(.title3)
            .foregroundStyle(.orange)
    }
}

// MARK: - Timeline Entry
struct TabataEntry: TimelineEntry {
    let date: Date
    let tabataName: String
    let lastWorkoutDate: Date?
    let weeklyCount: Int
}

// MARK: - Timeline Provider
struct TabataTimelineProvider: TimelineProvider {
    typealias Entry = TabataEntry
    
    func placeholder(in context: Context) -> TabataEntry {
        TabataEntry(
            date: Date(),
            tabataName: "🔥 Infierno",
            lastWorkoutDate: nil,
            weeklyCount: 0
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (TabataEntry) -> Void) {
        let entry = TabataEntry(
            date: Date(),
            tabataName: "🔥 Infierno",
            lastWorkoutDate: Date(),
            weeklyCount: 3
        )
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<TabataEntry>) -> Void) {
        // Fetch actual data from UserDefaults or WatchConnectivity
        let defaults = UserDefaults.standard
        let lastWorkoutTimestamp = defaults.double(forKey: "lastTabataWorkoutDate")
        let weeklyCount = defaults.integer(forKey: "weeklyTabataCount")
        
        let lastWorkoutDate = lastWorkoutTimestamp > 0 ? Date(timeIntervalSince1970: lastWorkoutTimestamp) : nil
        
        let entry = TabataEntry(
            date: Date(),
            tabataName: "🔥 Infierno",
            lastWorkoutDate: lastWorkoutDate,
            weeklyCount: weeklyCount
        )
        
        // Refresh every 15 minutes
        let nextUpdate = Date().addingTimeInterval(15 * 60)
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        
        completion(timeline)
    }
}

// MARK: - Complication View Entry
struct TabataComplicationEntryView: View {
    var entry: TabataEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                
                VStack(spacing: 2) {
                    Image(systemName: "flame.fill")
                        .font(.title3)
                        .foregroundStyle(.orange)
                    
                    Text("\(entry.weeklyCount)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
            }
            
        case .accessoryRectangular:
            HStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tabata")
                        .font(.headline)
                    
                    if let lastDate = entry.lastWorkoutDate {
                        Text("Último: \(lastDate, style: .relative)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("\(entry.weeklyCount) esta semana")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
        case .accessoryInline:
            Label("🔥 \(entry.weeklyCount) Tabatas", systemImage: "flame.fill")
            
        case .accessoryCorner:
            Image(systemName: "flame.fill")
                .font(.title3)
                .foregroundStyle(.orange)
                .widgetLabel {
                    Text("\(entry.weeklyCount)")
                }
            
        default:
            Text("All1Fit")
        }
    }
}

// MARK: - Widget Bundle
struct TabataWidget: Widget {
    let kind: String = "TabataComplication"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TabataTimelineProvider()) { entry in
            TabataComplicationEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Tabata")
        .description("Acceso rápido a tus Tabatas y estadísticas")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCorner
        ])
    }
}

// MARK: - Update Complication Helper
func updateTabataComplication() {
    WidgetCenter.shared.reloadTimelines(ofKind: "TabataComplication")
}

// MARK: - Track Workout Completion
func trackTabataCompletion() {
    let defaults = UserDefaults.standard
    
    // Update last workout date
    defaults.set(Date().timeIntervalSince1970, forKey: "lastTabataWorkoutDate")
    
    // Increment weekly count (reset if new week)
    let calendar = Calendar.current
    let lastResetTimestamp = defaults.double(forKey: "weeklyCountResetDate")
    let lastResetDate = Date(timeIntervalSince1970: lastResetTimestamp)
    
    if !calendar.isDate(lastResetDate, equalTo: Date(), toGranularity: .weekOfYear) {
        // New week, reset count
        defaults.set(1, forKey: "weeklyTabataCount")
        defaults.set(Date().timeIntervalSince1970, forKey: "weeklyCountResetDate")
    } else {
        // Same week, increment
        let count = defaults.integer(forKey: "weeklyTabataCount")
        defaults.set(count + 1, forKey: "weeklyTabataCount")
    }
    
    // Refresh complication
    updateTabataComplication()
}

#Preview(as: .accessoryCircular) {
    TabataWidget()
} timeline: {
    TabataEntry(date: Date(), tabataName: "Infierno", lastWorkoutDate: nil, weeklyCount: 3)
}
