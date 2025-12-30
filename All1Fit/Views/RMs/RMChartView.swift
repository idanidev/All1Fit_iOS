import SwiftUI
import Charts

// MARK: - RM Chart View (iOS 26 Premium)
struct RMChartView: View {
    let ejercicio: Ejercicio
    
    @AppStorage("weightUnit") private var weightUnit: WeightUnit = .kg
    @State private var selectedEntry: RMEntry?
    @State private var chartAnimated = false
    @State private var selectedTimeRange: TimeRange = .all
    @State private var showingAddRM = false
    @Namespace private var animation
    
    private var sortedHistory: [RMEntry] {
        let sorted = ejercicio.rmHistory.sorted { $0.fecha < $1.fecha }
        
        switch selectedTimeRange {
        case .month:
            let cutoff = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
            return sorted.filter { $0.fecha >= cutoff }
        case .quarter:
            let cutoff = Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
            return sorted.filter { $0.fecha >= cutoff }
        case .year:
            let cutoff = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
            return sorted.filter { $0.fecha >= cutoff }
        case .all:
            return sorted
        }
    }
    
    private var stats: RMStats {
        RMStats(history: ejercicio.rmHistory, weightUnit: weightUnit)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Hero Stats
                heroStatsSection
                
                // Time Range Picker
                timeRangePicker
                
                // Chart
                if sortedHistory.count >= 2 {
                    chartSection
                } else {
                    noDataView
                }
                
                // Statistics Grid
                statisticsGrid
                
                // History
                historySection
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(ejercicio.name)
        .navigationBarTitleDisplayMode(.inline)
        .logoToolbar(height: 100)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddRM = true
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.orange)
                }
            }
        }
        .sheet(isPresented: $showingAddRM) {
            EjercicioFormView(mode: .addRM(ejercicio: ejercicio)) { _, rm in
                // Handle save - would need service injection in real app
            }
        }
        .onAppear {
            withAnimation(.spring(duration: 0.8).delay(0.3)) {
                chartAnimated = true
            }
        }
    }
    
    // MARK: - Hero Stats Section
    private var heroStatsSection: some View {
        VStack(spacing: 16) {
            // Current RM with glow
            ZStack {
                // Glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.orange.opacity(0.4), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 100
                        )
                    )
                    .frame(width: 200, height: 200)
                    .blur(radius: 30)
                
                VStack(spacing: 4) {
                    Text("RM Actual")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    if let current = stats.currentRM {
                        Text(formatWeight(weightUnit.convert(current)))
                            .font(.system(size: 56, weight: .black, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.orange, .red],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .contentTransition(.numericText())
                        
                        Text(weightUnit.symbol)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // Trend indicator
            if let progression = stats.progressionPercent {
                HStack(spacing: 8) {
                    Image(systemName: progression >= 0 ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill")
                        .foregroundStyle(progression >= 0 ? .green : .red)
                    
                    Text("\(progression >= 0 ? "+" : "")\(String(format: "%.1f", progression))%")
                        .font(.headline)
                        .foregroundStyle(progression >= 0 ? .green : .red)
                    
                    Text("desde el inicio")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(Capsule())
            }
        }
        .padding(.top)
    }
    
    // MARK: - Time Range Picker
    private var timeRangePicker: some View {
        Picker("Rango", selection: $selectedTimeRange) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Text(range.title).tag(range)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: selectedTimeRange) { _, _ in
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }
    
    // MARK: - Chart Section
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Progreso")
                .font(.headline)
            
            Chart {
                ForEach(sortedHistory) { entry in
                    LineMark(
                        x: .value("Fecha", entry.fecha),
                        y: .value("Peso", chartAnimated ? weightUnit.convert(entry.valor) : 0)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                    .interpolationMethod(.catmullRom)
                    
                    AreaMark(
                        x: .value("Fecha", entry.fecha),
                        y: .value("Peso", chartAnimated ? weightUnit.convert(entry.valor) : 0)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange.opacity(0.3), .orange.opacity(0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                    
                    PointMark(
                        x: .value("Fecha", entry.fecha),
                        y: .value("Peso", chartAnimated ? weightUnit.convert(entry.valor) : 0)
                    )
                    .foregroundStyle(.orange)
                    .symbolSize(selectedEntry?.id == entry.id ? 150 : 80)
                }
                
                if let selected = selectedEntry {
                    RuleMark(x: .value("Selected", selected.fecha))
                        .foregroundStyle(.orange.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                        .annotation(position: .automatic, alignment: .center, spacing: 8) {
                            VStack(spacing: 2) {
                                Text(formatWeight(weightUnit.convert(selected.valor)) + " " + weightUnit.symbol)
                                    .font(.caption.bold())
                                Text(selected.fecha.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption2)
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Color.orange)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 3)) { value in
                    if let date = value.as(Date.self) {
                        AxisValueLabel {
                            Text(date.formatted(.dateTime.day(.twoDigits).month(.twoDigits)))
                                .font(.caption2)
                        }
                    }
                    AxisGridLine()
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let x = value.location.x
                                    if let date: Date = proxy.value(atX: x) {
                                        selectedEntry = sortedHistory.min(by: {
                                            abs($0.fecha.timeIntervalSince(date)) < abs($1.fecha.timeIntervalSince(date))
                                        })
                                    }
                                    UISelectionFeedbackGenerator().selectionChanged()
                                }
                                .onEnded { _ in
                                    withAnimation(.spring(duration: 0.2)) {
                                        selectedEntry = nil
                                    }
                                }
                        )
                }
            }
            .frame(height: 250)
            .padding()
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }
    
    // MARK: - Statistics Grid
    private var statisticsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            StatCard(
                title: "Mejor RM",
                value: stats.bestRM.map { formatWeight(weightUnit.convert($0)) + " " + weightUnit.symbol } ?? "-",
                icon: "trophy.fill",
                color: .yellow
            )
            
            StatCard(
                title: "Registros",
                value: "\(ejercicio.rmHistory.count)",
                icon: "list.bullet.clipboard",
                color: .blue
            )
            
            StatCard(
                title: "Primer RM",
                value: stats.firstRM.map { formatWeight(weightUnit.convert($0)) + " " + weightUnit.symbol } ?? "-",
                icon: "flag.fill",
                color: .green
            )
            
            StatCard(
                title: "Promedio",
                value: stats.averageRM.map { formatWeight(weightUnit.convert($0)) + " " + weightUnit.symbol } ?? "-",
                icon: "chart.bar.fill",
                color: .purple
            )
        }
    }
    
    // MARK: - History Section
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Historial")
                .font(.headline)
            
            LazyVStack(spacing: 0) {
                ForEach(Array(sortedHistory.reversed().enumerated()), id: \.element.id) { index, entry in
                    HStack {
                        // Position badge
                        if index == 0 {
                            Image(systemName: "crown.fill")
                                .font(.caption)
                                .foregroundStyle(.yellow)
                                .frame(width: 24)
                        } else {
                            Text("#\(index + 1)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 24)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.fecha.formatted(date: .long, time: .omitted))
                                .font(.subheadline)
                        }
                        
                        Spacer()
                        
                        Text("\(formatWeight(weightUnit.convert(entry.valor))) \(weightUnit.symbol)")
                            .font(.headline)
                            .foregroundStyle(index == 0 ? .orange : .primary)
                    }
                    .padding()
                    
                    if index < sortedHistory.count - 1 {
                        Divider()
                            .padding(.leading, 44)
                    }
                }
            }
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
    
    // MARK: - No Data View
    private var noDataView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            
            Text("Añade más registros para ver el gráfico")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    // MARK: - Helpers
    private func formatWeight(_ weight: Double) -> String {
        if weight.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(weight))"
        }
        return String(format: "%.1f", weight)
    }
}

// MARK: - Time Range
enum TimeRange: String, CaseIterable {
    case month, quarter, year, all
    
    var title: String {
        switch self {
        case .month: return "1M"
        case .quarter: return "3M"
        case .year: return "1A"
        case .all: return "Todo"
        }
    }
}

// MARK: - RM Stats
struct RMStats {
    let history: [RMEntry]
    let weightUnit: WeightUnit
    
    var currentRM: Double? {
        history.max(by: { $0.fecha < $1.fecha })?.valor
    }
    
    var bestRM: Double? {
        history.max(by: { $0.valor < $1.valor })?.valor
    }
    
    var firstRM: Double? {
        history.min(by: { $0.fecha < $1.fecha })?.valor
    }
    
    var averageRM: Double? {
        guard !history.isEmpty else { return nil }
        return history.map(\.valor).reduce(0, +) / Double(history.count)
    }
    
    var progressionPercent: Double? {
        guard let first = firstRM, let current = currentRM, first > 0 else { return nil }
        return ((current - first) / first) * 100
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.title3.bold())
                    .foregroundStyle(.primary)
                
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    NavigationStack {
        RMChartView(ejercicio: .sample)
    }
}