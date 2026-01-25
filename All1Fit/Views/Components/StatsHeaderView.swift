import SwiftUI

// MARK: - Stats Header View
struct StatsHeaderView: View {
    let title: String
    let count: Int
    let subtitle: String?
    let accentColor: Color
    
    @State private var animatedCount: Int = 0
    
    init(title: String, count: Int, subtitle: String? = nil, accentColor: Color = .orange) {
        self.title = title
        self.count = count
        self.subtitle = subtitle
        self.accentColor = accentColor
    }
    
    var body: some View {
        VStack(spacing: 4) {
            // Title
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(1.2)
            
            // Animated Count
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\\(animatedCount)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        .linearGradient(
                            colors: [accentColor, accentColor.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .contentTransition(.numericText(value: Double(animatedCount)))
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: animatedCount)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .offset(y: -2)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(accentColor.opacity(0.2), lineWidth: 1)
                )
        )
        .task {
            await animateCount()
        }
        .onChange(of: count) { _, newValue in
            Task {
                await animateCount()
            }
        }
    }
    
    private func animateCount() async {
        let duration: TimeInterval = 0.8
        let steps = min(count, 30)
        let stepDuration = duration / Double(steps)
        
        for i in 0...steps {
            let progress = Double(i) / Double(steps)
            animatedCount = Int(Double(count) * progress)
            try? await Task.sleep(for: .seconds(stepDuration))
        }
        animatedCount = count
    }
}

// MARK: - Multiple Stats Header
struct MultiStatsHeaderView: View {
    struct Stat: Identifiable {
        let id = UUID()
        let title: String
        let count: Int
        let subtitle: String?
        
        init(title: String, count: Int, subtitle: String? = nil) {
            self.title = title
            self.count = count
            self.subtitle = subtitle
        }
    }
    
    let stats: [Stat]
    let accentColor: Color
    
    var body: some View {
        HStack(spacing: 12) {
            ForEach(stats) { stat in
                VStack(spacing: 4) {
                    Text(stat.title)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.8)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\\(stat.count)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(accentColor)
                        
                        if let subtitle = stat.subtitle {
                            Text(subtitle)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                
                if stat.id != stats.last?.id {
                    Divider()
                        .frame(height: 30)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(accentColor.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Preview
#Preview("Single Stat") {
    VStack {
        StatsHeaderView(
            title: "Entrenamientos",
            count: 127,
            subtitle: "disponibles",
            accentColor: .orange
        )
        .padding()
        
        StatsHeaderView(
            title: "Tabatas",
            count: 45,
            accentColor: .blue
        )
        .padding()
    }
    .background(Color(uiColor: .systemGroupedBackground))
}

#Preview("Multiple Stats") {
    MultiStatsHeaderView(
        stats: [
            .init(title: "Total", count: 127),
            .init(title: "Completados", count: 45),
            .init(title: "Esta semana", count: 8)
        ],
        accentColor: .orange
    )
    .padding()
    .background(Color(uiColor: .systemGroupedBackground))
}
