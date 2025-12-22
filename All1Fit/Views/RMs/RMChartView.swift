import SwiftUI
import Charts

struct RMChartView: View {
    let ejercicio: Ejercicio
    @State private var selectedEntry: RMEntry?
    
    private var sortedHistory: [RMEntry] {
        ejercicio.rmHistory.sorted { $0.fecha < $1.fecha }
    }
    
    private var minValue: Double {
        let min = sortedHistory.map(\.valor).min() ?? 0
        return max(0, min - 5)
    }
    
    private var maxValue: Double {
        let max = sortedHistory.map(\.valor).max() ?? 100
        return max + 5
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header with current max status
                headerStatus
                
                if sortedHistory.count >= 2 {
                    // Main Chart
                    chartContainer
                } else {
                    noDataView
                }
                
                // History List
                historyListView
            }
            .padding()
        }
        .navigationTitle(ejercicio.name)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(uiColor: .systemGroupedBackground))
    }
    
    // MARK: - Header Status
    private var headerStatus: some View {
        VStack(spacing: 8) {
            Text("Máximo Actual")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            if let max = sortedHistory.last {
                Text("\(Int(max.valor)) kg")
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text(max.fecha.formatted(date: .long, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
            }
        }
        .padding(.top)
    }
    
    // MARK: - Chart Container
    private var chartContainer: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Progreso")
                .font(.headline)
                .foregroundStyle(.primary)
                .padding(.horizontal)
            
            Chart {
                ForEach(sortedHistory) { entry in
                    LineMark(
                        x: .value("Fecha", entry.fecha),
                        y: .value("Peso", entry.valor)
                    )
                    .foregroundStyle(Color.orange)
                    .symbol {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 8, height: 8)
                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    }
                    .interpolationMethod(.catmullRom)
                    
                    AreaMark(
                        x: .value("Fecha", entry.fecha),
                        y: .value("Peso", entry.valor)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange.opacity(0.3), .orange.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }
                
                if let selected = selectedEntry {
                    RuleMark(x: .value("Fecha", selected.fecha))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                        .foregroundStyle(Color.gray)
                        .annotation(position: .top) {
                            VStack(spacing: 2) {
                                Text("\(Int(selected.valor)) kg")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.black.opacity(0.7))
                                    .cornerRadius(4)
                            }
                        }
                }
            }
            .chartYScale(domain: minValue...maxValue)
            .chartOverlay { proxy in
                GeometryReader { geometry in
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
                                }
                                .onEnded { _ in selectedEntry = nil }
                        )
                }
            }
            .frame(height: 250)
            .padding()
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    // MARK: - History List View
    private var historyListView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Historial")
                .font(.headline)
                .foregroundStyle(.primary)
                .padding(.horizontal)
            
            VStack(spacing: 0) {
                ForEach(Array(sortedHistory.reversed().enumerated()), id: \.element.id) { index, entry in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.fecha.formatted(date: .numeric, time: .omitted))
                                .font(.body)
                                .fontWeight(.medium)
                        }
                        
                        Spacer()
                        
                        Text("\(Int(entry.valor)) kg")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(index == 0 ? .orange : .primary)
                    }
                    .padding()
                    
                    if index < sortedHistory.count - 1 {
                        Divider()
                            .padding(.leading)
                    }
                }
            }
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
    }
    
    // MARK: - No Data View
    private var noDataView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.xyaxis.line")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No hay suficientes datos para la gráfica")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

#Preview {
    NavigationStack {
        RMChartView(ejercicio: .sample)
    }
}
