import SwiftUI
import Charts

// MARK: - Detalle de Ejercicio
/// Ficha completa: músculo, equipamiento, técnica e historial personal.
struct ExerciseDetailView: View {
    enum DetailTab: String, CaseIterable {
        case info = "Info"
        case historial = "Historial"
        case records = "Records"
    }

    let exercise: GymExercise
    var sessionService: GymSessionService?

    @AppStorage("weightUnit") private var weightUnit: WeightUnit = .kg
    @State private var chartAnimated = false
    @State private var selectedTab: DetailTab = .info
    @State private var isFavorite = false

    private var muscleColor: Color { exercise.primaryMuscle.color }

    private var weightHistory: [(date: Date, weight: Double)] {
        sessionService?.weightHistory(for: exercise.name) ?? []
    }

    private var bestWeight: Double {
        sessionService?.bestWeight(for: exercise.name) ?? 0
    }

    private var lastLog: GymExerciseLog? {
        sessionService?.lastLog(for: exercise.name)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                heroSection
                muscleChips

                if sessionService != nil {
                    Picker("Sección", selection: $selectedTab) {
                        ForEach(DetailTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                switch selectedTab {
                case .info:
                    instructionsSection
                case .historial:
                    if weightHistory.count >= 2 {
                        progressChart
                    }
                    historySection
                case .records:
                    recordsSection
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    ExerciseFavorites.toggle(exercise.name)
                    isFavorite = ExerciseFavorites.isFavorite(exercise.name)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .foregroundStyle(isFavorite ? .yellow : .secondary)
                }
            }
        }
        .onAppear {
            isFavorite = ExerciseFavorites.isFavorite(exercise.name)
            withAnimation(.spring(duration: 0.8).delay(0.3)) { chartAnimated = true }
        }
    }

    // MARK: - Historial

    @ViewBuilder
    private var historySection: some View {
        let history = sessionService?.history(for: exercise.name) ?? []
        if history.isEmpty {
            emptyTabMessage("Sin registros aún", subtitle: "Completa series de este ejercicio en un entreno para ver tu historial")
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Label("Sesiones", systemImage: "calendar")
                    .font(.headline)

                VStack(spacing: 8) {
                    ForEach(Array(history.enumerated()), id: \.offset) { _, entry in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(entry.date, format: .dateTime.day().month(.wide).year())
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                                .foregroundStyle(.secondary)
                            ForEach(Array(entry.log.completedSets.enumerated()), id: \.element.id) { index, set in
                                HStack {
                                    Text("Serie \(index + 1)\(set.type.badge.map { " (\($0))" } ?? "")")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text("\(formatWeight(set.weight)) \(weightUnit.symbol) × \(set.reps)\(set.rpe.map { "  RPE \($0)" } ?? "")")
                                        .font(.system(.caption, design: .rounded, weight: .semibold))
                                }
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
    }

    // MARK: - Records

    @ViewBuilder
    private var recordsSection: some View {
        if bestWeight <= 0 {
            emptyTabMessage("Sin records aún", subtitle: "Tus mejores marcas aparecerán aquí cuando entrenes este ejercicio")
        } else {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                recordCard(icon: "trophy.fill", title: "Mejor peso", value: "\(formatWeight(bestWeight)) \(weightUnit.symbol)", color: .yellow)
                if let oneRM = sessionService?.best1RM(for: exercise.name) {
                    recordCard(icon: "flame.fill", title: "1RM estimado", value: "\(formatWeight(oneRM)) \(weightUnit.symbol)", color: .all1FitOrange)
                }
                if let bestVolume = sessionService?.bestSessionVolume(for: exercise.name) {
                    recordCard(icon: "scalemass.fill", title: "Mejor volumen", value: "\(formatWeight(bestVolume)) \(weightUnit.symbol)", color: .all1FitCyan)
                }
                if let best = lastLog?.bestSet {
                    recordCard(icon: "clock.fill", title: "Última mejor serie", value: "\(formatWeight(best.weight))×\(best.reps)", color: .all1FitBlue)
                }
            }
        }
    }

    private func recordCard(icon: String, title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func emptyTabMessage(_ title: String, subtitle: String) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [muscleColor.opacity(0.3), .clear], center: .center, startRadius: 0, endRadius: 100))
                    .frame(width: 200, height: 200)
                    .blur(radius: 30)

                // Mapa vectorial: músculo exacto resaltado, sin marcos ni fondos
                MuscleMapView(primary: exercise.primaryMuscle, secondary: exercise.secondaryMuscles)
                    .scaleEffect(0.62)
                    .frame(width: 202, height: 188)
            }

            Text(exercise.name)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var muscleChips: some View {
        HStack(spacing: 8) {
            chip(label: exercise.primaryMuscle.rawValue, color: muscleColor, prominent: true)
            ForEach(exercise.secondaryMuscles, id: \.self) { muscle in
                chip(label: muscle.rawValue, color: muscle.color, prominent: false)
            }
            chip(label: exercise.equipment.rawValue, color: .all1FitCyan, prominent: false, icon: exercise.equipment.icon)
        }
    }

    private func chip(label: String, color: Color, prominent: Bool, icon: String? = nil) -> some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.caption2.weight(.semibold))
            }
            Text(label)
                .font(.system(.caption, design: .rounded, weight: .semibold))
        }
        .foregroundStyle(prominent ? .white : color)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(prominent ? AnyShapeStyle(color) : AnyShapeStyle(color.opacity(0.12)))
        .clipShape(Capsule())
    }

    // MARK: - Gráfica de progreso

    private var progressChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Progreso", systemImage: "chart.line.uptrend.xyaxis")
                .font(.headline)

            Chart(Array(weightHistory.enumerated()), id: \.offset) { _, point in
                LineMark(
                    x: .value("Fecha", point.date),
                    y: .value("Peso", chartAnimated ? weightUnit.convert(point.weight) : 0)
                )
                .foregroundStyle(
                    LinearGradient(colors: [.all1FitBlue, .all1FitCyan], startPoint: .leading, endPoint: .trailing)
                )
                .lineStyle(StrokeStyle(lineWidth: 3))
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("Fecha", point.date),
                    y: .value("Peso", chartAnimated ? weightUnit.convert(point.weight) : 0)
                )
                .foregroundStyle(
                    LinearGradient(colors: [.all1FitBlue.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom)
                )
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Fecha", point.date),
                    y: .value("Peso", chartAnimated ? weightUnit.convert(point.weight) : 0)
                )
                .foregroundStyle(Color.all1FitCyan)
                .symbolSize(80)
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                    AxisValueLabel()
                        .font(.caption2)
                }
            }
            .frame(height: 220)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Técnica

    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Técnica", systemImage: "list.number")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(exercise.instructions.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 26, height: 26)
                            .background(
                                LinearGradient(colors: [.all1FitBlue, .all1FitCyan], startPoint: .topLeading, endPoint: .bottomTrailing),
                                in: Circle()
                            )
                        Text(step)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Helpers

    private func formatWeight(_ value: Double) -> String {
        let converted = weightUnit.convert(value)
        return converted.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(converted))" : String(format: "%.1f", converted)
    }
}

#Preview {
    NavigationStack {
        ExerciseDetailView(exercise: GymExerciseCatalog.all[0])
    }
    .preferredColorScheme(.dark)
}
