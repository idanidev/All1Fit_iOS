import SwiftUI
import Charts

// MARK: - RM Chart View (iOS 26 Premium)
struct RMChartView: View {
    let ejercicio: Ejercicio

    @AppStorage("weightUnit") private var weightUnit: WeightUnit = .kg
    @State private var chartAnimated = false
    @State private var porcentajesRevealed = false
    @State private var selectedTimeRange: TimeRange = .all
    @State private var showingAddRM = false
    @State private var calcReps: Int = 10
    @Namespace private var animation
    @EnvironmentObject var ejercicioService: EjercicioService
    @State private var showingEdit = false
    @State private var errorMessage: String?
    @State private var editingEntry: RMEntry?

    private let calcRepOptions = [3, 5, 6, 8, 10, 12, 15, 20]

    /// Always uses latest data from service (reflects edits in real time)
    private var currentEjercicio: Ejercicio {
        ejercicioService.ejercicios.first { $0.id == ejercicio.id } ?? ejercicio
    }

    private var sortedHistory: [RMEntry] {
        let sorted = currentEjercicio.rmHistory.sorted { $0.fecha < $1.fecha }

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
        RMStats(history: currentEjercicio.rmHistory, weightUnit: weightUnit)
    }

    private var isGym: Bool { currentEjercicio.style == .dumbbell }

    /// Epley formula: 1RM = peso × (1 + reps/30)
    private func estimatedRM(peso: Double, reps: Int) -> Double {
        reps == 1 ? peso : round(peso * (1.0 + Double(reps) / 30.0) * 4) / 4
    }

    /// Best estimated 1RM across all gym entries that have reps
    private var bestEstimatedRM: Double? {
        currentEjercicio.rmHistory
            .compactMap { entry -> Double? in
                guard let reps = entry.reps else { return nil }
                return estimatedRM(peso: entry.valor, reps: reps)
            }
            .max()
    }

    /// 1RM to use in tables: saved estimate if available, else calculate from latest entry + calcReps
    private var effective1RM: Double? {
        if let best = bestEstimatedRM { return best }
        guard let latest = currentEjercicio.ultimoRM else { return nil }
        return estimatedRM(peso: latest.valor, reps: calcReps)
    }

    private var hasRepsData: Bool { bestEstimatedRM != nil }

    /// For gym chart: use estimated 1RM per entry (or raw valor if no reps)
    private var gymChartData: [(entry: RMEntry, estimated: Double)] {
        sortedHistory.map { entry in
            let est = entry.reps.map { estimatedRM(peso: entry.valor, reps: $0) } ?? entry.valor
            return (entry: entry, estimated: est)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Hero Stats
                if isGym { gymHeroSection } else { heroStatsSection }

                // Time Range Picker
                timeRangePicker

                // Chart
                if sortedHistory.count >= 2 {
                    if isGym { gymChartSection } else { chartSection }
                } else {
                    noDataView
                }

                // Gym: weight table by rep range. Barbell: % table
                if isGym {
                    if effective1RM != nil { gymRepTableSection }
                } else if !currentEjercicio.porcentajes.isEmpty {
                    porcentajesSection
                }

                // Statistics Grid
                if isGym { gymStatisticsGrid } else { statisticsGrid }

                // History
                if isGym { gymHistorySection } else { historySection }
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(currentEjercicio.name)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    showingEdit = true
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title2)
                        .foregroundStyle(currentEjercicio.style.color)
                }
                .accessibilityLabel("Editar RM")

                Button {
                    showingAddRM = true
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(currentEjercicio.style.color)
                }
                .accessibilityLabel("Añadir RM")
            }
        }
        .sheet(isPresented: $showingAddRM) {
            EjercicioFormView(mode: .addRM(ejercicio: currentEjercicio)) { _, rm, _, reps, fecha in
                guard let id = currentEjercicio.id else { return }
                Task {
                    do {
                        try await ejercicioService.addRM(ejercicioId: id, valor: rm, reps: reps, fecha: fecha)
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    } catch {
                        errorMessage = error.localizedDescription
                        UINotificationFeedbackGenerator().notificationOccurred(.error)
                    }
                }
            }
        }
        .sheet(isPresented: $showingEdit) {
            EjercicioEditSheet(ejercicio: currentEjercicio)
                .environmentObject(ejercicioService)
        }
        .sheet(item: $editingEntry) { entry in
            RMEntryEditSheet(
                entry: entry,
                isGym: isGym,
                onSave: { newValor, newReps, newFecha in updateHistoryEntry(entry, newValor: newValor, newReps: newReps, newFecha: newFecha) }
            )
        }
        .onAppear {
            withAnimation(.spring(duration: 0.8).delay(0.3)) {
                chartAnimated = true
            }
            porcentajesRevealed = true
        }
    }

    // MARK: - Hero Stats Section
    private var heroStatsSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(RadialGradient(
                        colors: [currentEjercicio.style.color.opacity(0.35), .clear],
                        center: .center, startRadius: 0, endRadius: 100
                    ))
                    .frame(width: 200, height: 200)
                    .blur(radius: 30)

                VStack(spacing: 8) {
                    Image(systemName: currentEjercicio.icon)
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(LinearGradient(colors: currentEjercicio.style.gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 72, height: 72)
                        .background(currentEjercicio.style.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 18))

                    Text(currentEjercicio.style.label)
                        .font(.caption.bold())
                        .foregroundStyle(currentEjercicio.style.color)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(currentEjercicio.style.color.opacity(0.12))
                        .clipShape(Capsule())

                    Text("RM Actual")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let current = stats.currentRM {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(formatWeight(weightUnit.convert(current)))
                                .font(.system(size: 56, weight: .black, design: .rounded))
                                .foregroundStyle(LinearGradient(colors: currentEjercicio.style.gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                                .contentTransition(.numericText())
                            Text(weightUnit.symbol)
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

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

    // MARK: - Gym Hero Section
    private var gymHeroSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [.blue.opacity(0.35), .clear], center: .center, startRadius: 0, endRadius: 100))
                    .frame(width: 200, height: 200)
                    .blur(radius: 30)

                VStack(spacing: 6) {
                    Text("Última serie")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let entry = currentEjercicio.ultimoRM {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(formatWeight(weightUnit.convert(entry.valor)))
                                .font(.system(size: 52, weight: .black, design: .rounded))
                                .foregroundStyle(LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .contentTransition(.numericText())
                            Text(weightUnit.symbol)
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }

                        if let reps = entry.reps {
                            // Reps guardadas — mostrar directamente
                            Text("× \(reps) reps")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.blue.opacity(0.85))

                            let est = estimatedRM(peso: entry.valor, reps: reps)
                            HStack(spacing: 5) {
                                Image(systemName: "sparkles")
                                    .font(.caption.weight(.semibold))
                                Text("1RM est. \(formatWeight(weightUnit.convert(est))) \(weightUnit.symbol)")
                                    .font(.subheadline.bold())
                            }
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(.orange.opacity(0.12), in: Capsule())
                        } else {
                            // Sin reps guardadas — calculadora rápida
                            VStack(spacing: 10) {
                                HStack(spacing: 6) {
                                    Text("Reps")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Picker("Reps", selection: $calcReps) {
                                        ForEach(calcRepOptions, id: \.self) { rep in
                                            Text("\(rep) reps").tag(rep)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .tint(.blue)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))

                                let est = estimatedRM(peso: entry.valor, reps: calcReps)
                                HStack(spacing: 5) {
                                    Image(systemName: "sparkles")
                                        .font(.caption.weight(.semibold))
                                    Text("1RM est. \(formatWeight(weightUnit.convert(est))) \(weightUnit.symbol)")
                                        .font(.subheadline.bold())
                                }
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(.orange.opacity(0.12), in: Capsule())
                            }
                        }
                    }
                }
            }

            if let progression = stats.progressionPercent {
                HStack(spacing: 8) {
                    Image(systemName: progression >= 0 ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill")
                        .foregroundStyle(progression >= 0 ? .green : .red)
                    Text("\(progression >= 0 ? "+" : "")\(String(format: "%.1f", progression))%")
                        .font(.headline)
                        .foregroundStyle(progression >= 0 ? .green : .red)
                    Text("en el peso")
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
                        y: .value("Peso", chartAnimated ? weightUnit.convert(entry.estimated1RM) : 0)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: currentEjercicio.style.gradient,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Fecha", entry.fecha),
                        y: .value("Peso", chartAnimated ? weightUnit.convert(entry.estimated1RM) : 0)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [currentEjercicio.style.color.opacity(0.3), currentEjercicio.style.color.opacity(0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Fecha", entry.fecha),
                        y: .value("Peso", chartAnimated ? weightUnit.convert(entry.estimated1RM) : 0)
                    )
                    .foregroundStyle(currentEjercicio.style.color)
                    .symbolSize(80)
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
            .frame(height: 220)
            .padding()
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }

    // MARK: - Gym Chart Section (estimated 1RM over time)
    private var gymChartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("1RM estimado")
                    .font(.headline)
                Spacer()
                Text("Fórmula Epley")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Chart {
                ForEach(gymChartData, id: \.entry.id) { item in
                    LineMark(
                        x: .value("Fecha", item.entry.fecha),
                        y: .value("1RM est.", chartAnimated ? weightUnit.convert(item.estimated) : 0)
                    )
                    .foregroundStyle(LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing))
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Fecha", item.entry.fecha),
                        y: .value("1RM est.", chartAnimated ? weightUnit.convert(item.estimated) : 0)
                    )
                    .foregroundStyle(LinearGradient(colors: [.blue.opacity(0.3), .blue.opacity(0)], startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Fecha", item.entry.fecha),
                        y: .value("1RM est.", chartAnimated ? weightUnit.convert(item.estimated) : 0)
                    )
                    .foregroundStyle(.blue)
                    .symbolSize(80)
                }
            }
            .chartYAxis { AxisMarks(position: .leading) }
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
            .frame(height: 220)
            .padding()
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }

    // MARK: - Porcentajes Section
    private var porcentajesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Porcentajes", systemImage: "percent")
                    .font(.headline)

                Spacer()

                if let rm = currentEjercicio.ultimoRM {
                    Text("RM: \(formatWeight(weightUnit.convert(rm.estimated1RM))) \(weightUnit.symbol)")
                        .font(.subheadline.bold())
                        .foregroundStyle(.orange)
                }
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(Array(currentEjercicio.porcentajes.enumerated()), id: \.element.porcentaje) { index, item in
                    let color = colorForPercentage(item.porcentaje)
                    HStack {
                        Text("\(item.porcentaje)%")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(color)
                            .frame(width: 44, alignment: .leading)

                        Spacer()

                        Text("\(formatWeight(weightUnit.convert(item.peso))) \(weightUnit.symbol)")
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(
                            colors: [color.opacity(0.18), color.opacity(0.06)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(color.opacity(0.22), lineWidth: 1)
                    )
                    .shadow(color: color.opacity(porcentajesRevealed ? 0.15 : 0), radius: 6, y: 3)
                    .opacity(porcentajesRevealed ? 1 : 0)
                    .scaleEffect(porcentajesRevealed ? 1 : 0.82, anchor: .center)
                    .offset(y: porcentajesRevealed ? 0 : 16)
                    .blur(radius: porcentajesRevealed ? 0 : 4)
                    .animation(.spring(response: 0.5, dampingFraction: 0.68).delay(0.12 + Double(index) * 0.05), value: porcentajesRevealed)
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    /// Escala de "calor": más caliente = más cerca del RM.
    /// Family cálida (rojo→naranja→ámbar→arena→gris), legible y sin efecto arcoíris.
    private func colorForPercentage(_ percentage: Int) -> Color {
        switch percentage {
        case 95...100: return Color(red: 1.00, green: 0.23, blue: 0.19)  // rojo intenso
        case 85...94:  return Color(red: 1.00, green: 0.35, blue: 0.16)  // rojo-naranja
        case 75...84:  return Color(red: 1.00, green: 0.47, blue: 0.13)  // naranja fuerte
        case 65...74:  return Color(red: 1.00, green: 0.58, blue: 0.00)  // naranja
        case 55...64:  return Color(red: 1.00, green: 0.69, blue: 0.20)  // ámbar
        case 45...54:  return Color(red: 0.96, green: 0.78, blue: 0.36)  // dorado
        case 35...44:  return Color(red: 0.80, green: 0.73, blue: 0.58)  // arena
        default:       return Color(red: 0.60, green: 0.60, blue: 0.64)  // gris (bajo)
        }
    }

    // MARK: - Gym Rep Table (peso recomendado por rango de reps)
    private var gymRepTableSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Peso por reps", systemImage: "table.fill")
                    .font(.headline)
                Spacer()
                if let rm = effective1RM {
                    Text("1RM est. \(formatWeight(weightUnit.convert(rm))) \(weightUnit.symbol)")
                        .font(.subheadline.bold())
                        .foregroundStyle(.blue)
                }
            }

            // Calculadora manual si no hay datos de reps guardados
            if !hasRepsData, let latest = currentEjercicio.ultimoRM {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sin datos de reps — elige con cuántas reps levantas \(formatWeight(weightUnit.convert(latest.valor))) \(weightUnit.symbol):")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(calcRepOptions, id: \.self) { rep in
                                Button {
                                    withAnimation(.spring(duration: 0.2)) { calcReps = rep }
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                } label: {
                                    Text("\(rep)")
                                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                        .foregroundStyle(calcReps == rep ? .white : .primary)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 7)
                                        .background(calcReps == rep ? AnyShapeStyle(Color.blue) : AnyShapeStyle(Color(uiColor: .tertiarySystemGroupedBackground)))
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(10)
                .background(Color.blue.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            let repRanges = [3, 5, 6, 8, 10, 12, 15, 20]
            if let rm = effective1RM {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(repRanges, id: \.self) { reps in
                        let peso = rm / (1.0 + Double(reps) / 30.0)
                        HStack {
                            Text("\(reps) reps")
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                                .foregroundStyle(repColor(reps))
                                .frame(width: 52, alignment: .leading)
                            Spacer()
                            Text("\(formatWeight(weightUnit.convert(peso))) \(weightUnit.symbol)")
                                .font(.system(.caption, design: .rounded, weight: .bold))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(repColor(reps).opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }

            Text("Fórmula de Epley · inversa para calcular el peso")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func repColor(_ reps: Int) -> Color {
        switch reps {
        case 1...5:  return .red
        case 6...8:  return .orange
        case 9...10: return .yellow
        case 11...12: return .green
        case 13...15: return .teal
        default:     return .blue
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
                value: "\(currentEjercicio.rmHistory.count)",
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

    // MARK: - Gym Statistics Grid
    private var gymStatisticsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(
                title: "1RM estimado",
                value: effective1RM.map { formatWeight(weightUnit.convert($0)) + " " + weightUnit.symbol } ?? "-",
                icon: "sparkles",
                color: .orange
            )
            StatCard(
                title: "Series",
                value: "\(currentEjercicio.rmHistory.count)",
                icon: "list.bullet.clipboard",
                color: .blue
            )
            StatCard(
                title: "Mejor peso",
                value: stats.bestRM.map { formatWeight(weightUnit.convert($0)) + " " + weightUnit.symbol } ?? "-",
                icon: "trophy.fill",
                color: .yellow
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
                            .foregroundStyle(index == 0 ? currentEjercicio.style.color : .primary)
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .contentShape(Rectangle())
                    .onTapGesture { editingEntry = entry }
                    .contextMenu {
                        Button {
                            editingEntry = entry
                        } label: {
                            Label("Editar registro", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            deleteHistoryEntry(entry)
                        } label: {
                            Label("Eliminar registro", systemImage: "trash")
                        }
                    }

                    if index < sortedHistory.count - 1 {
                        Divider().padding(.leading, 44)
                    }
                }
            }
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Gym History Section
    private var gymHistorySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Historial de series")
                .font(.headline)

            let sorted = currentEjercicio.rmHistory.sorted { $0.fecha > $1.fecha }
            LazyVStack(spacing: 0) {
                ForEach(Array(sorted.enumerated()), id: \.element.id) { index, entry in
                    HStack(spacing: 12) {
                        // Badge
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
                            if let reps = entry.reps {
                                let est = estimatedRM(peso: entry.valor, reps: reps)
                                Text("1RM est. \(formatWeight(weightUnit.convert(est))) \(weightUnit.symbol)")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            HStack(alignment: .firstTextBaseline, spacing: 3) {
                                Text(formatWeight(weightUnit.convert(entry.valor)))
                                    .font(.headline)
                                    .foregroundStyle(index == 0 ? .blue : .primary)
                                Text(weightUnit.symbol)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            if let reps = entry.reps {
                                Text("× \(reps) reps")
                                    .font(.caption.bold())
                                    .foregroundStyle(.blue.opacity(0.8))
                            }
                        }
                    }
                    .padding()
                    .contentShape(Rectangle())
                    .onTapGesture { editingEntry = entry }
                    .contextMenu {
                        Button {
                            editingEntry = entry
                        } label: {
                            Label("Editar registro", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            deleteHistoryEntry(entry)
                        } label: {
                            Label("Eliminar registro", systemImage: "trash")
                        }
                    }

                    if index < sorted.count - 1 {
                        Divider().padding(.leading, 44)
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

    private func deleteHistoryEntry(_ entry: RMEntry) {
        guard let id = currentEjercicio.id else { return }
        Task {
            do {
                try await ejercicioService.deleteRMEntry(ejercicioId: id, entryId: entry.id)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } catch {
                errorMessage = error.localizedDescription
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }

    private func updateHistoryEntry(_ entry: RMEntry, newValor: Double, newReps: Int?, newFecha: Date) {
        guard let id = currentEjercicio.id else { return }
        Task {
            do {
                try await ejercicioService.updateRMEntry(ejercicioId: id, entryId: entry.id, newValor: newValor, newReps: newReps, newFecha: newFecha)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } catch {
                errorMessage = error.localizedDescription
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
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

    // Todas las métricas usan el 1RM estimado (Epley) de cada registro: si
    // metiste 110×2, cuenta ~117. Con reps nil/1, estimated1RM == valor.
    var currentRM: Double? {
        history.max(by: { $0.fecha < $1.fecha })?.estimated1RM
    }

    var bestRM: Double? {
        history.max(by: { $0.estimated1RM < $1.estimated1RM })?.estimated1RM
    }

    var firstRM: Double? {
        history.min(by: { $0.fecha < $1.fecha })?.estimated1RM
    }

    var averageRM: Double? {
        guard !history.isEmpty else { return nil }
        return history.map(\.estimated1RM).reduce(0, +) / Double(history.count)
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

// MARK: - Ejercicio Edit Sheet
struct EjercicioEditSheet: View {
    @EnvironmentObject var ejercicioService: EjercicioService
    let ejercicioId: String
    @Environment(\.dismiss) private var dismiss
    @AppStorage("weightUnit") private var weightUnit: WeightUnit = .kg

    @State private var name: String
    @State private var style: EjercicioStyle
    @State private var editingEntry: RMEntry?
    @State private var errorMessage: String?

    private var currentEjercicio: Ejercicio? {
        ejercicioService.ejercicios.first { $0.id == ejercicioId }
    }

    private var sortedHistory: [RMEntry] {
        currentEjercicio?.rmHistory.sorted { $0.fecha > $1.fecha } ?? []
    }

    init(ejercicio: Ejercicio) {
        self.ejercicioId = ejercicio.id ?? ""
        self._name = State(initialValue: ejercicio.name)
        self._style = State(initialValue: ejercicio.style)
    }

    var body: some View {
        NavigationStack {
            List {
                // Basic info
                Section("Ejercicio") {
                    HStack {
                        Text("Nombre")
                            .foregroundStyle(.secondary)
                        Spacer()
                        TextField("Nombre", text: $name)
                            .multilineTextAlignment(.trailing)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Tipo")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 8) {
                            ForEach(EjercicioStyle.allCases, id: \.self) { s in
                                Button {
                                    withAnimation(.spring(duration: 0.2)) { style = s }
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                } label: {
                                    VStack(spacing: 5) {
                                        Image(systemName: s.icon)
                                            .font(.system(size: 20, weight: .semibold))
                                            .foregroundStyle(style == s ? s.color : .secondary)
                                        Text(s.label)
                                            .font(.caption2.bold())
                                            .foregroundStyle(style == s ? s.color : .secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        style == s
                                        ? s.color.opacity(0.12)
                                        : Color(uiColor: .tertiarySystemGroupedBackground)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(style == s ? s.color : Color.clear, lineWidth: 1.5)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                // History
                Section("\(sortedHistory.count) registros") {
                    ForEach(sortedHistory) { entry in
                        Button { editingEntry = entry } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.fecha.formatted(date: .abbreviated, time: .omitted))
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                    if let reps = entry.reps {
                                        Text("× \(reps) reps")
                                            .font(.caption)
                                            .foregroundStyle(.blue)
                                    }
                                }
                                Spacer()
                                HStack(alignment: .firstTextBaseline, spacing: 3) {
                                    Text(formatWeight(weightUnit.convert(entry.valor)))
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text(weightUnit.symbol)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteEntry(entry)
                            } label: {
                                Label("Eliminar", systemImage: "trash.fill")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Editar ejercicio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { saveBasicInfo() }
                        .fontWeight(.semibold)
                }
            }
            .sheet(item: $editingEntry) { entry in
                RMEntryEditSheet(
                    entry: entry,
                    isGym: style == .dumbbell,
                    onSave: { newValor, newReps, newFecha in updateEntry(entry, newValor: newValor, newReps: newReps, newFecha: newFecha) }
                )
            }
        }
        .presentationDetents([.large])
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func saveBasicInfo() {
        guard let id = currentEjercicio?.id else { return }
        Task {
            do {
                try await ejercicioService.updateEjercicio(id: id, name: name, style: style)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }

    private func deleteEntry(_ entry: RMEntry) {
        guard let id = currentEjercicio?.id else { return }
        Task {
            do {
                try await ejercicioService.deleteRMEntry(ejercicioId: id, entryId: entry.id)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } catch {
                errorMessage = error.localizedDescription
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }

    private func updateEntry(_ entry: RMEntry, newValor: Double, newReps: Int?, newFecha: Date) {
        guard let id = currentEjercicio?.id else { return }
        Task {
            do {
                try await ejercicioService.updateRMEntry(ejercicioId: id, entryId: entry.id, newValor: newValor, newReps: newReps, newFecha: newFecha)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } catch {
                errorMessage = error.localizedDescription
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }

    private func formatWeight(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(w))" : String(format: "%.1f", w)
    }
}

// MARK: - RM Entry Edit Sheet
struct RMEntryEditSheet: View {
    let entry: RMEntry
    let isGym: Bool
    let onSave: (Double, Int?, Date) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var valorText: String
    @State private var repsValue: Int
    @State private var editedDate: Date

    init(entry: RMEntry, isGym: Bool, onSave: @escaping (Double, Int?, Date) -> Void) {
        self.entry = entry
        self.isGym = isGym
        self.onSave = onSave
        let v = entry.valor
        self._valorText = State(initialValue: v.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(v))" : String(format: "%.1f", v))
        self._repsValue = State(initialValue: entry.reps ?? 10)
        self._editedDate = State(initialValue: entry.fecha)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Peso (kg)") {
                    HStack {
                        TextField("0", text: $valorText)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                        Text("kg")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }

                if isGym {
                    Section("Repeticiones") {
                        Stepper("\(repsValue) reps", value: $repsValue, in: 1...100)
                            .font(.headline)
                    }
                }

                Section("Fecha") {
                    DatePicker("Fecha", selection: $editedDate, in: ...Date(), displayedComponents: .date)
                        .datePickerStyle(.compact)
                }
            }
            .navigationTitle("Editar registro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        let valor = Double(valorText.replacingOccurrences(of: ",", with: ".")) ?? entry.valor
                        onSave(valor, isGym ? repsValue : nil, editedDate)
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(Double(valorText.replacingOccurrences(of: ",", with: ".")) == nil || valorText.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    NavigationStack {
        RMChartView(ejercicio: .sample)
            .environmentObject(EjercicioService())
    }
}
