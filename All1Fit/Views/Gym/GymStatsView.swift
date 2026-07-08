import SwiftUI
import Charts

// MARK: - Progreso y Medidas
/// Estadísticas de entrenamiento (volumen, frecuencia muscular, historial)
/// y medidas corporales (peso, grasa, perímetros).
struct GymStatsView: View {
    enum StatsTab: String, CaseIterable {
        case progreso = "Progreso"
        case medidas = "Medidas"
    }

    @ObservedObject var sessionService: GymSessionService
    @ObservedObject var measurementService: BodyMeasurementService
    @State private var selectedTab: StatsTab
    @State private var showingAddMeasurement = false
    @State private var selectedSession: GymSession?
    @State private var chartAnimated = false
    @State private var errorMessage: String?
    @AppStorage("weightUnit") private var weightUnit: WeightUnit = .kg

    init(sessionService: GymSessionService, measurementService: BodyMeasurementService, initialTab: StatsTab = .progreso) {
        self.sessionService = sessionService
        self.measurementService = measurementService
        _selectedTab = State(initialValue: initialTab)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Picker("Sección", selection: $selectedTab) {
                    ForEach(StatsTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)

                switch selectedTab {
                case .progreso:
                    progressContent
                case .medidas:
                    measurementsContent
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Progreso")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if selectedTab == .medidas {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        showingAddMeasurement = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.title2)
                    }
                    .accessibilityLabel("Añadir medida")
                }
            }
        }
        .sheet(isPresented: $showingAddMeasurement) {
            AddMeasurementSheet(measurementService: measurementService)
        }
        .sheet(item: $selectedSession) { session in
            GymSessionDetailSheet(session: session, weightUnit: weightUnit)
        }
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .task {
            await sessionService.fetchSessions()
            await measurementService.fetchMeasurements()
        }
        .onAppear {
            withAnimation(.spring(duration: 0.8).delay(0.3)) { chartAnimated = true }
        }
    }

    // MARK: - PROGRESO

    @ViewBuilder
    private var progressContent: some View {
        if sessionService.sessions.isEmpty {
            emptyState(
                icon: "chart.bar.fill",
                title: "Sin entrenamientos",
                subtitle: "Completa tu primera sesión de gym para ver tu progreso"
            )
        } else {
            statsGrid
            streakCard
            monthComparisonCard
            GymHeatmapView(sessions: sessionService.sessions)
            weeklyVolumeChart
            muscleDistributionChart
            muscleFrequencySection
            globalRecordsSection
            sessionHistorySection
        }
    }

    // MARK: Racha semanal

    /// Semanas consecutivas entrenando (lógica compartida en GymSessionService)
    private var weekStreak: Int { sessionService.weekStreak }

    private var streakCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [.all1FitOrange.opacity(0.3), .clear], center: .center, startRadius: 0, endRadius: 30))
                    .frame(width: 54, height: 54)
                Image(systemName: "flame.fill")
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(colors: [.all1FitOrange, .yellow], startPoint: .top, endPoint: .bottom)
                    )
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(weekStreak)")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())
                    Text(weekStreak == 1 ? "semana" : "semanas")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Text("Racha de entrenamiento")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: Mes vs mes

    private func monthSessions(offset: Int) -> [GymSession] {
        let calendar = Calendar.current
        guard let month = calendar.date(byAdding: .month, value: offset, to: Date()),
              let interval = calendar.dateInterval(of: .month, for: month) else { return [] }
        return sessionService.sessions.filter { interval.contains($0.startDate) }
    }

    private var monthComparisonCard: some View {
        let current = monthSessions(offset: 0)
        let previous = monthSessions(offset: -1)
        let currentVolume = current.reduce(0.0) { $0 + $1.totalVolume }
        let previousVolume = previous.reduce(0.0) { $0 + $1.totalVolume }

        return VStack(alignment: .leading, spacing: 12) {
            Label("Este mes vs anterior", systemImage: "arrow.left.arrow.right")
                .font(.headline)

            HStack(spacing: 10) {
                comparisonPill(title: "Sesiones", current: Double(current.count), previous: Double(previous.count), format: { "\(Int($0))" })
                comparisonPill(title: "Volumen", current: currentVolume, previous: previousVolume, format: { formatVolume($0) })
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func comparisonPill(title: String, current: Double, previous: Double, format: (Double) -> String) -> some View {
        let up = current >= previous
        return VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(format(current))
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
                HStack(spacing: 2) {
                    Image(systemName: up ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 9, weight: .bold))
                    Text(format(previous))
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(up ? Color.all1FitSuccess : Color.all1FitError)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: Distribución muscular (últimos 30 días)

    private var muscleDistribution: [(muscle: BodyPart, sets: Int)] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        var counts: [BodyPart: Int] = [:]
        for session in sessionService.sessions where session.startDate >= cutoff {
            for log in session.exercises {
                guard let muscle = log.catalogExercise?.primaryMuscle else { continue }
                counts[muscle, default: 0] += log.workingSets.count
            }
        }
        return counts.map { ($0.key, $0.value) }.sorted { $0.1 > $1.1 }
    }

    @ViewBuilder
    private var muscleDistributionChart: some View {
        let distribution = muscleDistribution
        if distribution.count >= 2 {
            VStack(alignment: .leading, spacing: 12) {
                Label("Distribución muscular (30 días)", systemImage: "chart.pie.fill")
                    .font(.headline)

                HStack(spacing: 16) {
                    Chart(distribution, id: \.muscle) { entry in
                        SectorMark(
                            angle: .value("Series", chartAnimated ? entry.sets : 0),
                            innerRadius: .ratio(0.6),
                            angularInset: 2
                        )
                        .foregroundStyle(entry.muscle.color)
                        .cornerRadius(4)
                    }
                    .frame(width: 140, height: 140)

                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(distribution.prefix(6), id: \.muscle) { entry in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(entry.muscle.color)
                                    .frame(width: 8, height: 8)
                                Text(entry.muscle.rawValue)
                                    .font(.system(size: 11, weight: .medium))
                                    .lineLimit(1)
                                Spacer()
                                Text("\(entry.sets)")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(entry.muscle.color)
                            }
                        }
                    }
                }
            }
            .padding()
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: Records globales

    @ViewBuilder
    private var globalRecordsSection: some View {
        let records = sessionService.topEstimated1RMs(limit: 5)
        if !records.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                Label("Mejores marcas (1RM est.)", systemImage: "trophy.fill")
                    .font(.headline)

                VStack(spacing: 8) {
                    ForEach(Array(records.enumerated()), id: \.element.exerciseName) { index, record in
                        HStack(spacing: 12) {
                            if index == 0 {
                                Image(systemName: "crown.fill")
                                    .font(.caption)
                                    .foregroundStyle(.yellow)
                                    .frame(width: 24)
                            } else {
                                Text("#\(index + 1)")
                                    .font(.system(.caption, design: .rounded, weight: .bold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 24)
                            }
                            Text(record.exerciseName)
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                .lineLimit(1)
                            Spacer()
                            Text("\(formatWeight(record.oneRM)) \(weightUnit.symbol)")
                                .font(.system(.subheadline, design: .rounded, weight: .black))
                                .foregroundStyle(
                                    LinearGradient(colors: [.all1FitBlue, .all1FitCyan], startPoint: .leading, endPoint: .trailing)
                                )
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding()
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private var totalDurationHours: Double {
        sessionService.sessions.reduce(0.0) { $0 + $1.duration } / 3600
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statCard(icon: "figure.strengthtraining.traditional", value: "\(sessionService.sessions.count)", label: "sesiones", color: .all1FitBlue)
            statCard(icon: "scalemass.fill", value: formatVolume(sessionService.sessions.reduce(0) { $0 + $1.totalVolume }), label: "volumen total", color: .all1FitCyan)
            statCard(icon: "checkmark.circle.fill", value: "\(sessionService.sessions.reduce(0) { $0 + $1.totalCompletedSets })", label: "series", color: .all1FitSuccess)
            statCard(icon: "clock.fill", value: String(format: "%.1fh", totalDurationHours), label: "tiempo total", color: .all1FitPurple)
        }
    }

    private func statCard(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())

            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: Volumen semanal

    private var weeklyVolume: [(week: Date, volume: Double)] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: sessionService.sessions) { session in
            calendar.dateInterval(of: .weekOfYear, for: session.startDate)?.start ?? session.startDate
        }
        return grouped
            .map { (week: $0.key, volume: $0.value.reduce(0) { $0 + $1.totalVolume }) }
            .sorted { $0.week < $1.week }
            .suffix(8)
    }

    private var weeklyVolumeChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Volumen semanal", systemImage: "chart.bar.fill")
                .font(.headline)

            Chart(weeklyVolume, id: \.week) { entry in
                BarMark(
                    x: .value("Semana", entry.week, unit: .weekOfYear),
                    y: .value("Volumen", chartAnimated ? weightUnit.convert(entry.volume) : 0)
                )
                .foregroundStyle(
                    LinearGradient(colors: [.all1FitBlue, .all1FitCyan], startPoint: .bottom, endPoint: .top)
                )
                .cornerRadius(6)
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                    AxisValueLabel(format: .dateTime.day().month(), centered: true)
                        .font(.caption2)
                }
            }
            .frame(height: 220)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: Frecuencia muscular

    private var muscleFrequency: [(muscle: BodyPart, sets: Int)] {
        var counts: [BodyPart: Int] = [:]
        for session in sessionService.sessions {
            for log in session.exercises {
                guard let muscle = log.catalogExercise?.primaryMuscle else { continue }
                counts[muscle, default: 0] += log.completedSets.count
            }
        }
        return counts
            .map { (muscle: $0.key, sets: $0.value) }
            .sorted { $0.sets > $1.sets }
            .prefix(5)
            .map { $0 }
    }

    @ViewBuilder
    private var muscleFrequencySection: some View {
        if !muscleFrequency.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                Label("Frecuencia por músculo", systemImage: "figure.arms.open")
                    .font(.headline)

                let maxSets = muscleFrequency.first?.sets ?? 1
                VStack(spacing: 10) {
                    ForEach(muscleFrequency, id: \.muscle) { entry in
                        HStack(spacing: 10) {
                            Text(entry.muscle.rawValue)
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                                .foregroundStyle(.primary)
                                .frame(width: 90, alignment: .leading)

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color(uiColor: .tertiarySystemGroupedBackground))
                                    Capsule()
                                        .fill(
                                            LinearGradient(colors: [entry.muscle.color, entry.muscle.color.opacity(0.6)],
                                                           startPoint: .leading, endPoint: .trailing)
                                        )
                                        .frame(width: chartAnimated ? geo.size.width * CGFloat(entry.sets) / CGFloat(maxSets) : 0)
                                }
                            }
                            .frame(height: 10)

                            Text("\(entry.sets)")
                                .font(.system(.caption, design: .rounded, weight: .bold))
                                .foregroundStyle(entry.muscle.color)
                                .frame(width: 32, alignment: .trailing)
                        }
                    }
                }
            }
            .padding()
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: Historial

    private var sessionHistorySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Historial", systemImage: "calendar")
                .font(.headline)

            LazyVStack(spacing: 10) {
                ForEach(sessionService.sessions) { session in
                    Button {
                        selectedSession = session
                    } label: {
                        sessionRow(session)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            deleteSession(session)
                        } label: {
                            Label("Eliminar", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    private func sessionRow(_ session: GymSession) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(colors: [.all1FitBlue, .all1FitCyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(width: 40, height: 40)
                .background(Color.all1FitBlue.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(session.routineName)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text("\(session.dateFormatted) · \(session.durationFormatted) · \(session.totalCompletedSets) series")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(formatVolume(session.totalVolume))
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(Color.all1FitCyan)
                Text("volumen")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        }
    }

    private func deleteSession(_ session: GymSession) {
        guard let id = session.id else { return }
        Task {
            do {
                try await sessionService.deleteSession(id: id)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - MEDIDAS

    @ViewBuilder
    private var measurementsContent: some View {
        if measurementService.measurements.isEmpty {
            emptyState(
                icon: "figure.arms.open",
                title: "Sin medidas",
                subtitle: "Registra tu peso y perímetros para seguir tu evolución física"
            )

            Button {
                showingAddMeasurement = true
            } label: {
                Text("Añadir primera medida")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(colors: [.all1FitBlue, .all1FitCyan], startPoint: .leading, endPoint: .trailing),
                        in: Capsule()
                    )
            }
            .buttonStyle(.plain)
        } else {
            if let latest = measurementService.latestWeight {
                currentWeightHero(latest)
            }

            if measurementService.weightHistory.count >= 2 {
                weightChart
            }

            measurementsList
        }
    }

    private func currentWeightHero(_ weight: Double) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [.all1FitBlue.opacity(0.35), .clear], center: .center, startRadius: 0, endRadius: 80))
                    .frame(width: 160, height: 160)
                    .blur(radius: 30)

                VStack(spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(String(format: "%.1f", weight))
                            .font(.system(size: 56, weight: .black, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(colors: [.all1FitBlue, .all1FitCyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .contentTransition(.numericText())
                        Text("kg")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    Text("Peso actual")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(Color.all1FitBlue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.all1FitBlue.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var weightChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Evolución del peso", systemImage: "chart.line.uptrend.xyaxis")
                .font(.headline)

            Chart(Array(measurementService.weightHistory.enumerated()), id: \.offset) { _, point in
                LineMark(
                    x: .value("Fecha", point.date),
                    y: .value("Peso", chartAnimated ? point.weight : 0)
                )
                .foregroundStyle(
                    LinearGradient(colors: [.all1FitBlue, .all1FitCyan], startPoint: .leading, endPoint: .trailing)
                )
                .lineStyle(StrokeStyle(lineWidth: 3))
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Fecha", point.date),
                    y: .value("Peso", chartAnimated ? point.weight : 0)
                )
                .foregroundStyle(Color.all1FitCyan)
                .symbolSize(80)
            }
            .chartYScale(domain: .automatic(includesZero: false))
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

    private var measurementsList: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Registros", systemImage: "list.bullet.clipboard.fill")
                .font(.headline)

            LazyVStack(spacing: 10) {
                ForEach(measurementService.measurements) { measurement in
                    measurementRow(measurement)
                        .contextMenu {
                            Button(role: .destructive) {
                                deleteMeasurement(measurement)
                            } label: {
                                Label("Eliminar", systemImage: "trash")
                            }
                        }
                }
            }
        }
    }

    private func measurementRow(_ measurement: BodyMeasurement) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(measurement.dateFormatted)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(measurement.filledFields, id: \.label) { field in
                        HStack(spacing: 3) {
                            Text(field.label)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                            Text("\(field.value, specifier: field.value.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f")\(field.unit)")
                                .font(.system(.caption, design: .rounded, weight: .bold))
                                .foregroundStyle(Color.all1FitCyan)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.all1FitBlue.opacity(0.08))
                        .clipShape(Capsule())
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        }
    }

    private func deleteMeasurement(_ measurement: BodyMeasurement) {
        guard let id = measurement.id else { return }
        Task {
            do {
                try await measurementService.deleteMeasurement(id: id)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Helpers

    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [.all1FitBlue.opacity(0.25), .clear], center: .center, startRadius: 0, endRadius: 70))
                    .frame(width: 140, height: 140)
                Image(systemName: icon)
                    .font(.system(size: 48))
                    .foregroundStyle(
                        LinearGradient(colors: [.all1FitBlue, .all1FitCyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
            }

            VStack(spacing: 6) {
                Text(title)
                    .font(.title3.bold())
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 32)
    }

    private func formatVolume(_ volume: Double) -> String {
        let converted = weightUnit.convert(volume)
        if converted >= 1000 {
            return String(format: "%.1fk", converted / 1000)
        }
        return "\(Int(converted))"
    }

    private func formatWeight(_ value: Double) -> String {
        let converted = weightUnit.convert(value)
        return converted.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(converted))" : String(format: "%.1f", converted)
    }
}

// MARK: - Detalle de sesión
struct GymSessionDetailSheet: View {
    let session: GymSession
    let weightUnit: WeightUnit
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Resumen
                    HStack(spacing: 10) {
                        summaryPill(value: session.durationFormatted, label: "duración")
                        summaryPill(value: "\(session.totalCompletedSets)", label: "series")
                        summaryPill(value: formatVolume(session.totalVolume), label: "volumen")
                    }

                    // Ejercicios
                    LazyVStack(spacing: 12) {
                        ForEach(session.exercises) { log in
                            exerciseSummary(log)
                        }
                    }
                }
                .padding(20)
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationTitle(session.routineName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
        .presentationDetents([.fraction(0.7), .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
    }

    private func summaryPill(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(colors: [.all1FitBlue, .all1FitCyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func exerciseSummary(_ log: GymExerciseLog) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(log.exerciseName)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle((log.catalogExercise?.primaryMuscle ?? .none).color)

            VStack(spacing: 4) {
                ForEach(Array(log.completedSets.enumerated()), id: \.element.id) { index, set in
                    HStack {
                        Text("Serie \(index + 1)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(formatWeight(set.weight)) \(weightUnit.symbol) × \(set.reps)")
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func formatWeight(_ value: Double) -> String {
        let converted = weightUnit.convert(value)
        return converted.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(converted))" : String(format: "%.1f", converted)
    }

    private func formatVolume(_ volume: Double) -> String {
        let converted = weightUnit.convert(volume)
        if converted >= 1000 {
            return String(format: "%.1fk", converted / 1000)
        }
        return "\(Int(converted))"
    }
}

// MARK: - Añadir medida
struct AddMeasurementSheet: View {
    @ObservedObject var measurementService: BodyMeasurementService
    @Environment(\.dismiss) private var dismiss

    @State private var date = Date()
    @State private var weight = ""
    @State private var bodyFat = ""
    @State private var chest = ""
    @State private var waist = ""
    @State private var hips = ""
    @State private var arm = ""
    @State private var thigh = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var hasAnyValue: Bool {
        [weight, bodyFat, chest, waist, hips, arm, thigh].contains { parseDouble($0) != nil }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    DatePicker("Fecha", selection: $date, in: ...Date(), displayedComponents: .date)
                }

                Section("Peso y composición") {
                    measurementField("Peso corporal", value: $weight, unit: "kg")
                    measurementField("Grasa corporal", value: $bodyFat, unit: "%")
                }

                Section("Perímetros (cm)") {
                    measurementField("Pecho", value: $chest, unit: "cm")
                    measurementField("Cintura", value: $waist, unit: "cm")
                    measurementField("Cadera", value: $hips, unit: "cm")
                    measurementField("Brazo", value: $arm, unit: "cm")
                    measurementField("Muslo", value: $thigh, unit: "cm")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Nueva Medida")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        save()
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Guardar").bold()
                        }
                    }
                    .disabled(!hasAnyValue || isSaving)
                }
            }
            .alert("Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
    }

    private func measurementField(_ label: String, value: Binding<String>, unit: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("—", text: value)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.system(.body, design: .rounded, weight: .semibold))
                .frame(width: 80)
            Text(unit)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .leading)
        }
    }

    private func parseDouble(_ text: String) -> Double? {
        let normalized = text.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        guard !normalized.isEmpty, let value = Double(normalized), value > 0 else { return nil }
        return value
    }

    private func save() {
        isSaving = true
        let measurement = BodyMeasurement(
            date: date,
            weight: parseDouble(weight),
            bodyFat: parseDouble(bodyFat),
            chest: parseDouble(chest),
            waist: parseDouble(waist),
            hips: parseDouble(hips),
            arm: parseDouble(arm),
            thigh: parseDouble(thigh)
        )
        Task {
            do {
                try await measurementService.addMeasurement(measurement)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isSaving = false
            }
        }
    }
}

#Preview {
    NavigationStack {
        GymStatsView(sessionService: GymSessionService(), measurementService: BodyMeasurementService())
    }
    .preferredColorScheme(.dark)
}
