import SwiftUI
import Charts

// MARK: - Workout History Chart View
struct WorkoutHistoryChartView: View {
    let results: [WorkoutResult]
    let isForTime: Bool
    
    private var sortedResults: [WorkoutResult] {
        results.sorted { ($0.date ?? Date.distantPast) < ($1.date ?? Date.distantPast) }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(.orange)
                Text("Progreso")
                    .font(.headline)
            }
            
            if sortedResults.count >= 2 {
                chartView
                    .frame(height: 200)
            } else {
                emptyState
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Chart View
    private var chartView: some View {
        Chart(sortedResults) { result in
            if isForTime {
                // For time workouts: lower is better
                LineMark(
                    x: .value("Fecha", result.date ?? Date()),
                    y: .value("Tiempo", Double(result.timeSeconds) / 60.0)
                )
                .foregroundStyle(.orange.gradient)
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .symbol {
                    Circle()
                        .fill(.orange)
                        .frame(width: 8, height: 8)
                }
                
                AreaMark(
                    x: .value("Fecha", result.date ?? Date()),
                    y: .value("Tiempo", Double(result.timeSeconds) / 60.0)
                )
                .foregroundStyle(.orange.opacity(0.1).gradient)
            } else {
                // AMRAP: more rounds is better
                LineMark(
                    x: .value("Fecha", result.date ?? Date()),
                    y: .value("Rondas", result.rounds ?? 0)
                )
                .foregroundStyle(.blue.gradient)
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .symbol {
                    Circle()
                        .fill(.blue)
                        .frame(width: 8, height: 8)
                }
                
                AreaMark(
                    x: .value("Fecha", result.date ?? Date()),
                    y: .value("Rondas", result.rounds ?? 0)
                )
                .foregroundStyle(.blue.opacity(0.1).gradient)
            }
        }
        .chartYAxisLabel(position: .trailing) {
            Text(isForTime ? "min" : "rondas")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { value in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.largeTitle)
                .foregroundStyle(.secondary.opacity(0.5))
            
            Text("Registra al menos 2 resultados para ver tu progreso")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(height: 100)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    let sampleResults = [
        WorkoutResult(
            id: "1",
            workoutId: "fran",
            userId: "test",
            date: Date().addingTimeInterval(-86400 * 7),
            timeSeconds: 420,
            rounds: nil,
            notes: nil
        ),
        WorkoutResult(
            id: "2",
            workoutId: "fran",
            userId: "test",
            date: Date().addingTimeInterval(-86400 * 3),
            timeSeconds: 380,
            rounds: nil,
            notes: nil
        ),
        WorkoutResult(
            id: "3",
            workoutId: "fran",
            userId: "test",
            date: Date(),
            timeSeconds: 350,
            rounds: nil,
            notes: nil
        )
    ]
    
    return WorkoutHistoryChartView(results: sampleResults, isForTime: true)
        .padding()
}
