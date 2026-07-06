import SwiftUI

// MARK: - RM List View
struct RMListView: View {
    @StateObject private var ejercicioService = EjercicioService()

    @State private var showingAddSheet = false
    @State private var searchText = ""
    @State private var selectedEjercicio: Ejercicio?
    @State private var ejercicioToDelete: Ejercicio?
    @State private var expandedId: String?
    @State private var filterStyle: EjercicioStyle? = nil
    @State private var errorMessage: String?

    private var filteredEjercicios: [Ejercicio] {
        var result = ejercicioService.ejercicios
        if let style = filterStyle {
            result = result.filter { $0.style == style }
        }
        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
                content
            }
            .navigationTitle("RMs")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddSheet = true
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(
                                LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Buscar ejercicio...")
            .refreshable {
                await ejercicioService.fetchEjercicios(forceRefresh: true)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            .sheet(isPresented: $showingAddSheet) {
                EjercicioFormView(mode: .new) { name, rm, style, _ in
                    Task {
                        do {
                            try await ejercicioService.createEjercicio(name: name, rm: rm, style: style)
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                }
            }
            .sheet(item: $selectedEjercicio) { ejercicio in
                EjercicioFormView(mode: .addRM(ejercicio: ejercicio)) { _, rm, _, reps in
                    Task {
                        if let id = ejercicio.id {
                            do {
                                try await ejercicioService.addRM(ejercicioId: id, valor: rm, reps: reps)
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                        }
                    }
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
            .all1FitConfirmation(Binding(
                get: {
                    ejercicioToDelete.map { ejercicio in
                        All1FitConfirmation(
                            title: "¿Eliminar ejercicio?",
                            message: "\"\(ejercicio.name)\" y todos sus RMs se eliminarán. Esta acción no se puede deshacer.",
                            icon: "trash.fill",
                            confirmTitle: "Eliminar"
                        ) {
                            deleteEjercicio(ejercicio)
                        }
                    }
                },
                set: { if $0 == nil { ejercicioToDelete = nil } }
            ))
            .task { await ejercicioService.fetchEjercicios() }
        }
        .environmentObject(ejercicioService)
    }

    // MARK: - Content
    @ViewBuilder
    private var content: some View {
        if ejercicioService.isLoading && ejercicioService.ejercicios.isEmpty {
            skeletonLoader
        } else if filteredEjercicios.isEmpty && !searchText.isEmpty {
            ContentUnavailableView.search(text: searchText)
        } else if ejercicioService.ejercicios.isEmpty {
            emptyStateView
        } else {
            ejerciciosList
        }
    }

    // MARK: - Skeleton Loader
    private var skeletonLoader: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(0..<5, id: \.self) { _ in SkeletonCard() }
            }
            .padding()
        }
    }

    // MARK: - Ejercicios List
    private var ejerciciosList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Filter chips
                filterChips
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                // Exercise rows
                LazyVStack(spacing: 10) {
                    ForEach(filteredEjercicios) { ejercicio in
                        RMListRow(
                            ejercicio: ejercicio,
                            isExpanded: expandedId == ejercicio.id,
                            onTap: {
                                withAnimation(.spring(duration: 0.3)) {
                                    expandedId = expandedId == ejercicio.id ? nil : ejercicio.id
                                }
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            },
                            onAddRM: {
                                selectedEjercicio = ejercicio
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            },
                            onDelete: {
                                ejercicioToDelete = ejercicio
                                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .animation(.smooth, value: filteredEjercicios.count)
        .animation(.spring(duration: 0.3), value: expandedId)
    }

    // MARK: - Filter Chips
    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // "Todos" chip
                Button {
                    withAnimation(.spring(duration: 0.25)) { filterStyle = nil }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Text("Todos")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(filterStyle == nil ? .white : .secondary)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)
                        .background {
                            if filterStyle == nil {
                                Capsule()
                                    .fill(LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing))
                            } else {
                                Capsule()
                                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                                    .overlay(Capsule().strokeBorder(.white.opacity(0.07), lineWidth: 1))
                            }
                        }
                }
                .buttonStyle(.plain)

                ForEach(EjercicioStyle.allCases, id: \.self) { style in
                    Button {
                        withAnimation(.spring(duration: 0.25)) {
                            filterStyle = filterStyle == style ? nil : style
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: style.icon)
                                .font(.caption.weight(.semibold))
                            Text(style.label)
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        }
                        .foregroundStyle(filterStyle == style ? .white : .secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background {
                            if filterStyle == style {
                                Capsule()
                                    .fill(LinearGradient(
                                        colors: style.gradient,
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ))
                            } else {
                                Capsule()
                                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                                    .overlay(Capsule().strokeBorder(.white.opacity(0.07), lineWidth: 1))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(RadialGradient(
                        colors: [.orange.opacity(0.3), .clear],
                        center: .center, startRadius: 0, endRadius: 80
                    ))
                    .frame(width: 160, height: 160)

                Image(systemName: "figure.cross.training")
                    .font(.system(size: 60))
                    .foregroundStyle(LinearGradient(
                        colors: [.orange, .red],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .symbolEffect(.pulse.wholeSymbol, options: .repeating)
            }

            VStack(spacing: 8) {
                Text("Sin ejercicios")
                    .font(.title2.bold())
                Text("Añade tu primer ejercicio para empezar a trackear tus RMs")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Button {
                showingAddSheet = true
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } label: {
                Label("Añadir Ejercicio", systemImage: "plus")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 200, height: 50)
                    .background(
                        LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing),
                        in: Capsule()
                    )
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Delete
    private func deleteEjercicio(_ ejercicio: Ejercicio) {
        guard let id = ejercicio.id else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        Task {
            do {
                try await ejercicioService.deleteEjercicio(id: id)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - RM List Row (expandable)
struct RMListRow: View {
    let ejercicio: Ejercicio
    let isExpanded: Bool
    let onTap: () -> Void
    let onAddRM: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            Button(action: onTap) {
                EjercicioRowView(ejercicio: ejercicio, isExpanded: isExpanded)
            }
            .buttonStyle(.plain)

            if isExpanded {
                PorcentajesInlineView(ejercicio: ejercicio)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: onDelete) {
                Label("Eliminar", systemImage: "trash.fill")
            }
            .tint(.red)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button(action: onAddRM) {
                Label("Añadir RM", systemImage: "plus.circle.fill")
            }
            .tint(.orange)
        }
    }
}

// MARK: - Ejercicio Row View
struct EjercicioRowView: View {
    let ejercicio: Ejercicio
    var isExpanded: Bool = false
    @AppStorage("weightUnit") private var weightUnit: WeightUnit = .kg

    private var latestRM: Double { ejercicio.ultimoRM?.valor ?? 0 }

    private var trend: TrendDirection {
        guard ejercicio.rmHistory.count >= 2 else { return .neutral }
        let sorted = ejercicio.rmHistory.sorted { $0.fecha < $1.fecha }
        guard let prev = sorted.dropLast().last?.valor else { return .neutral }
        if latestRM > prev { return .up }
        if latestRM < prev { return .down }
        return .neutral
    }

    var body: some View {
        HStack(spacing: 14) {
            // Icon container — gradient stroke + tint bg
            Image(systemName: ejercicio.icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(colors: ejercicio.style.gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(width: 46, height: 46)
                .background(ejercicio.style.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 13))
                .overlay(
                    RoundedRectangle(cornerRadius: 13)
                        .strokeBorder(ejercicio.style.color.opacity(0.2), lineWidth: 1)
                )

            // Name + meta
            VStack(alignment: .leading, spacing: 3) {
                Text(ejercicio.name)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .lineLimit(1)
                    .foregroundStyle(.primary)

                HStack(spacing: 6) {
                    Text("\(ejercicio.rmHistory.count) reg")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)

                    if let ultimoRM = ejercicio.ultimoRM {
                        Text("·")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Text(ultimoRM.fecha.formatted(.dateTime.day().month(.abbreviated)))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer(minLength: 4)

            // RM value + trend
            HStack(spacing: 6) {
                if trend != .neutral {
                    Image(systemName: trend == .up ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(trend == .up ? .green : .red)
                }

                VStack(alignment: .trailing, spacing: 0) {
                    Text(formatWeight(weightUnit.convert(latestRM)))
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(colors: ejercicio.style.gradient, startPoint: .top, endPoint: .bottom)
                        )
                        .contentTransition(.numericText())

                    if let reps = ejercicio.ultimoRM?.reps {
                        Text("\(weightUnit.symbol) × \(reps)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.blue.opacity(0.8))
                    } else {
                        Text(weightUnit.symbol)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                .animation(.spring(duration: 0.25), value: isExpanded)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background {
            RoundedRectangle(cornerRadius: isExpanded ? 16 : 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(ejercicio.style.color.opacity(0.05))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(.white.opacity(0.07), lineWidth: 1)
                }
        }
    }

    private func formatWeight(_ weight: Double) -> String {
        weight.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(weight))"
            : String(format: "%.1f", weight)
    }

    enum TrendDirection { case up, down, neutral }
}

// MARK: - Porcentajes Inline
struct PorcentajesInlineView: View {
    let ejercicio: Ejercicio
    @AppStorage("weightUnit") private var weightUnit: WeightUnit = .kg

    var body: some View {
        Group {
            if ejercicio.style == .dumbbell {
                gymHistorySection
            } else {
                porcentajesSection
            }
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(ejercicio.style.color.opacity(0.04))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(.white.opacity(0.07), lineWidth: 1)
                }
        }
    }

    // MARK: - Gym history
    private var gymHistorySection: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Historial")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                NavigationLink {
                    RMChartView(ejercicio: ejercicio)
                } label: {
                    HStack(spacing: 4) {
                        Text("Ver gráfica")
                        Image(systemName: "chart.line.uptrend.xyaxis")
                    }
                    .font(.caption.bold())
                    .foregroundStyle(ejercicio.style.color)
                }
            }
            .padding(.bottom, 10)

            let sorted = Array(ejercicio.rmHistory.sorted { $0.fecha > $1.fecha }.prefix(6))
            ForEach(Array(sorted.enumerated()), id: \.element.id) { index, entry in
                HStack {
                    Text(entry.fecha.formatted(.dateTime.day().month(.abbreviated)))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .frame(width: 52, alignment: .leading)

                    Spacer()

                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(formatWeight(weightUnit.convert(entry.valor)))
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        Text(weightUnit.symbol)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        if let reps = entry.reps {
                            Text("× \(reps)")
                                .font(.system(.caption, design: .rounded, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 8)

                if index < sorted.count - 1 {
                    Divider().padding(.leading, 52)
                }
            }
        }
    }

    // MARK: - Porcentajes section
    private var porcentajesSection: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Porcentajes")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                NavigationLink {
                    RMChartView(ejercicio: ejercicio)
                } label: {
                    HStack(spacing: 4) {
                        Text("Ver gráfica")
                        Image(systemName: "chart.line.uptrend.xyaxis")
                    }
                    .font(.caption.bold())
                    .foregroundStyle(ejercicio.style.color)
                }
            }
            .padding(.bottom, 10)

            let items = ejercicio.porcentajes
            ForEach(Array(items.enumerated()), id: \.element.porcentaje) { index, item in
                HStack(spacing: 10) {
                    Circle()
                        .fill(colorFor(item.porcentaje))
                        .frame(width: 6, height: 6)

                    Text("\(item.porcentaje)%")
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(colorFor(item.porcentaje))
                        .frame(width: 38, alignment: .leading)

                    Spacer()

                    Text("\(formatWeight(weightUnit.convert(item.peso))) \(weightUnit.symbol)")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(.primary)
                }
                .padding(.vertical, 7)
                .padding(.horizontal, 8)
                .background(colorFor(item.porcentaje).opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private func colorFor(_ pct: Int) -> Color {
        switch pct {
        case 95...100: return .red
        case 85...94:  return .orange
        case 75...84:  return .yellow
        case 65...74:  return .green
        case 55...64:  return .teal
        case 45...54:  return .blue
        case 35...44:  return .indigo
        default:       return .purple
        }
    }

    private func formatWeight(_ weight: Double) -> String {
        weight.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(weight))"
            : String(format: "%.1f", weight)
    }
}

// MARK: - Skeleton Card
struct SkeletonCard: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 13)
                .fill(Color.gray.opacity(0.15))
                .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 120, height: 14)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 80, height: 10)
            }

            Spacer()

            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.15))
                .frame(width: 50, height: 26)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(.white.opacity(0.05), lineWidth: 1)
                }
        }
        .opacity(isAnimating ? 0.5 : 1.0)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

#Preview {
    RMListView()
}
