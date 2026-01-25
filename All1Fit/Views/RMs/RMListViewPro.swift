import SwiftUI

// MARK: - RM List View (Professional - Apple Design Award Level)
/// Premium RM tracking with professional design system
/// Dark-mode first, athlete-focused, fluid interactions

struct RMListViewPro: View {
    @StateObject private var ejercicioService = EjercicioService()
    @Namespace private var animation

    @State private var showingAddSheet = false
    @State private var searchText = ""
    @State private var selectedEjercicio: Ejercicio?
    @State private var expandedEjercicioId: String?
    @State private var ejercicioToDelete: Ejercicio?

    private var filteredEjercicios: [Ejercicio] {
        if searchText.isEmpty {
            return ejercicioService.ejercicios
        }
        return ejercicioService.ejercicios.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Premium Background
                Color.all1FitBackground
                    .ignoresSafeArea()

                // Content
                content

                // Professional Loading State
                if ejercicioService.isLoading {
                    VStack(spacing: All1FitSpacing.md) {
                        ProgressView()
                            .tint(.all1FitOrange)
                            .scaleEffect(1.3)

                        Text("Cargando RMs...")
                            .font(.all1FitLabelMedium)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial)
                }
            }
            .navigationTitle("RMs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddSheet = true
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.all1FitRunningGradient)
                            .symbolRenderingMode(.hierarchical)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Buscar ejercicio...")
            .refreshable {
                await ejercicioService.fetchEjercicios(forceRefresh: true)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            .sheet(isPresented: $showingAddSheet) {
                EjercicioFormView(mode: .new) { name, rm in
                    Task {
                        try? await ejercicioService.createEjercicio(name: name, rm: rm)
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    }
                }
            }
            .sheet(item: $selectedEjercicio) { ejercicio in
                EjercicioFormView(mode: .addRM(ejercicio: ejercicio)) { _, rm in
                    Task {
                        if let id = ejercicio.id {
                            try? await ejercicioService.addRM(ejercicioId: id, valor: rm)
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        }
                    }
                }
            }
            .confirmationDialog(
                "¿Eliminar ejercicio?",
                isPresented: Binding(
                    get: { ejercicioToDelete != nil },
                    set: { if !$0 { ejercicioToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Eliminar \(ejercicioToDelete?.name ?? "")", role: .destructive) {
                    if let ejercicio = ejercicioToDelete {
                        deleteEjercicio(ejercicio)
                    }
                }
                Button("Cancelar", role: .cancel) {
                    ejercicioToDelete = nil
                }
            } message: {
                Text("Se eliminarán todos los RMs registrados. Esta acción no se puede deshacer.")
            }
            .task {
                await ejercicioService.fetchEjercicios()
            }
        }
    }

    // MARK: - Content
    @ViewBuilder
    private var content: some View {
        if ejercicioService.isLoading && ejercicioService.ejercicios.isEmpty {
            // Professional Skeleton Loader
            proSkeletonLoader
        } else if filteredEjercicios.isEmpty && !searchText.isEmpty {
            ContentUnavailableView.search(text: searchText)
        } else if ejercicioService.ejercicios.isEmpty {
            proEmptyState
        } else {
            proEjerciciosList
        }
    }

    // MARK: - Professional Skeleton Loader
    private var proSkeletonLoader: some View {
        ScrollView {
            LazyVStack(spacing: All1FitSpacing.md) {
                ForEach(0..<5, id: \.self) { _ in
                    ProSkeletonCard()
                }
            }
            .padding(All1FitSpacing.md)
        }
    }

    // MARK: - Professional Ejercicios List
    private var proEjerciciosList: some View {
        ScrollViewReader { proxy in
            List {
                // Stats Header (if not searching)
                if searchText.isEmpty && !ejercicioService.ejercicios.isEmpty {
                    Section {
                        ProStatsHeader(ejercicios: ejercicioService.ejercicios)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }

                // Ejercicios
                Section {
                    ForEach(filteredEjercicios) { ejercicio in
                        VStack(spacing: 0) {
                            // Main row with navigation
                            NavigationLink {
                                RMChartView(ejercicio: ejercicio)
                            } label: {
                                ProEjercicioRow(
                                    ejercicio: ejercicio,
                                    onAddRM: {
                                        selectedEjercicio = ejercicio
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    }
                                )
                            }
                            .buttonStyle(.plain)

                            // Expandable percentage table
                            if expandedEjercicioId == ejercicio.id {
                                ProExpandablePorcentajes(ejercicio: ejercicio)
                                    .transition(.asymmetric(
                                        insertion: .push(from: .top).combined(with: .opacity),
                                        removal: .push(from: .bottom).combined(with: .opacity)
                                    ))
                                    .padding(.top, All1FitSpacing.xs)
                            }
                        }
                        .id(ejercicio.id)
                        .listRowInsets(EdgeInsets(top: All1FitSpacing.xs, leading: All1FitSpacing.md, bottom: All1FitSpacing.xs, trailing: All1FitSpacing.md))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                ejercicioToDelete = ejercicio
                            } label: {
                                Label("Eliminar", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                selectedEjercicio = ejercicio
                            } label: {
                                Label("Añadir RM", systemImage: "plus.circle")
                            }
                            .tint(.all1FitOrange)
                        }
                        .contextMenu {
                            Button {
                                withAnimation(.all1FitSpring) {
                                    if expandedEjercicioId == ejercicio.id {
                                        expandedEjercicioId = nil
                                    } else {
                                        expandedEjercicioId = ejercicio.id
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                            withAnimation(.all1FitSmooth) {
                                                proxy.scrollTo(ejercicio.id, anchor: .top)
                                            }
                                        }
                                    }
                                }
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                Label(
                                    expandedEjercicioId == ejercicio.id ? "Ocultar Porcentajes" : "Ver Porcentajes",
                                    systemImage: "percent"
                                )
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .animation(.all1FitSpring, value: filteredEjercicios.count)
            .animation(.all1FitSpring, value: expandedEjercicioId)
        }
    }

    // MARK: - Professional Empty State
    private var proEmptyState: some View {
        VStack(spacing: All1FitSpacing.xl) {
            // Animated icon with gradient
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.all1FitOrange.opacity(0.2), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 100
                        )
                    )
                    .frame(width: 200, height: 200)

                All1FitIconContainer(
                    icon: "figure.strengthtraining.traditional",
                    size: 80,
                    gradient: Color.all1FitRunningGradient
                )
                .symbolEffect(.pulse.wholeSymbol, options: .repeating)
            }

            VStack(spacing: All1FitSpacing.sm) {
                Text("Sin Ejercicios")
                    .font(.all1FitHeadlineLarge)

                Text("Añade tu primer ejercicio para empezar a trackear tus récords personales")
                    .font(.all1FitBodyMedium)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, All1FitSpacing.xl)
            }

            Button {
                showingAddSheet = true
            } label: {
                Label("Añadir Ejercicio", systemImage: "plus")
            }
            .buttonStyle(All1FitPrimaryButtonStyle(gradient: Color.all1FitRunningGradient))
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Delete
    private func deleteEjercicio(_ ejercicio: Ejercicio) {
        guard let id = ejercicio.id else { return }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        Task {
            try? await ejercicioService.deleteEjercicio(id: id)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}

// MARK: - Professional Stats Header
struct ProStatsHeader: View {
    let ejercicios: [Ejercicio]

    private var totalRMs: Int {
        ejercicios.reduce(0) { $0 + $1.rmHistory.count }
    }

    private var avgRM: Double {
        let allRMs = ejercicios.flatMap { $0.rmHistory.map { $0.valor } }
        guard !allRMs.isEmpty else { return 0 }
        return allRMs.reduce(0, +) / Double(allRMs.count)
    }

    var body: some View {
        HStack(spacing: All1FitSpacing.lg) {
            All1FitStatDisplay(
                value: "\(ejercicios.count)",
                label: "Ejercicios",
                color: .all1FitOrange
            )

            Divider()
                .frame(height: 40)

            All1FitStatDisplay(
                value: "\(totalRMs)",
                label: "RMs Totales",
                color: .all1FitRed
            )

            Spacer()
        }
        .padding(All1FitSpacing.lg)
        .all1FitCard(gradient: Color.all1FitRunningGradient)
        .padding(.horizontal, All1FitSpacing.md)
        .padding(.top, All1FitSpacing.sm)
    }
}

// MARK: - Professional Ejercicio Row
struct ProEjercicioRow: View {
    let ejercicio: Ejercicio
    let onAddRM: () -> Void

    @AppStorage("weightUnit") private var weightUnit: WeightUnit = .kg

    private var latestRM: Double {
        ejercicio.ultimoRM?.valor ?? 0
    }

    private var previousRM: Double? {
        guard ejercicio.rmHistory.count >= 2 else { return nil }
        let sorted = ejercicio.rmHistory.sorted { $0.fecha < $1.fecha }
        return sorted.dropLast().last?.valor
    }

    private var trend: Trend {
        guard let previous = previousRM else { return .neutral }
        if latestRM > previous { return .up }
        if latestRM < previous { return .down }
        return .neutral
    }

    private var gradientColors: [Color] {
        switch trend {
        case .up: return [.all1FitSuccess, Color(red: 0.4, green: 1.0, blue: 0.7)]
        case .down: return [.all1FitError, .all1FitOrange]
        case .neutral: return [.all1FitOrange, Color(red: 1.0, green: 0.75, blue: 0.4)]
        }
    }

    private var gradient: LinearGradient {
        LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var body: some View {
        HStack(spacing: All1FitSpacing.md) {
            // Professional Icon with trend
            All1FitIconContainer(icon: ejercicio.icon, size: 64, gradient: gradient)
                .overlay(alignment: .bottomTrailing) {
                    if trend != .neutral {
                        ZStack {
                            Circle()
                                .fill(.background)
                                .frame(width: 24, height: 24)

                            Image(systemName: trend == .up ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(trend == .up ? Color.all1FitSuccess : Color.all1FitError)
                        }
                        .offset(x: 4, y: 4)
                    }
                }

            // Info
            VStack(alignment: .leading, spacing: All1FitSpacing.xxs) {
                Text(ejercicio.name)
                    .font(.all1FitHeadlineSmall)

                HStack(spacing: All1FitSpacing.xs) {
                    All1FitBadge(
                        "\(ejercicio.rmHistory.count)",
                        color: .all1FitOrange,
                        style: .solid
                    )

                    if let ultimoRM = ejercicio.ultimoRM {
                        Text("•")
                            .foregroundStyle(.secondary.opacity(0.5))
                            .font(.all1FitCaption)
                        Text(ultimoRM.fecha.formatted(date: .abbreviated, time: .omitted))
                            .font(.all1FitCaption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            // RM Value - Hero Number
            VStack(alignment: .trailing, spacing: All1FitSpacing.xxxs) {
                Text(formatWeight(weightUnit.convert(latestRM)))
                    .font(.all1FitDisplaySmall)
                    .foregroundStyle(gradient)
                    .contentTransition(.numericText())

                Text(weightUnit.symbol)
                    .font(.all1FitLabelSmall)
                    .foregroundStyle(.secondary)
            }

            // Quick Add Button
            Button {
                onAddRM()
            } label: {
                ZStack {
                    Circle()
                        .fill(gradient.opacity(0.2))
                        .frame(width: 44, height: 44)

                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(gradient)
                        .symbolEffect(.bounce, value: latestRM)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(All1FitSpacing.md)
        .all1FitCard(gradient: gradient)
        .all1FitPressable()
    }

    private func formatWeight(_ weight: Double) -> String {
        if weight.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(weight))"
        }
        return String(format: "%.1f", weight)
    }

    enum Trend {
        case up, down, neutral
    }
}

// MARK: - Professional Expandable Porcentajes
struct ProExpandablePorcentajes: View {
    let ejercicio: Ejercicio
    @AppStorage("weightUnit") private var weightUnit: WeightUnit = .kg

    var body: some View {
        VStack(alignment: .leading, spacing: All1FitSpacing.sm) {
            // Header
            HStack {
                Label("Tabla de Porcentajes", systemImage: "percent")
                    .font(.all1FitLabelLarge)
                    .foregroundStyle(.secondary)

                Spacer()

                if let rm = ejercicio.ultimoRM {
                    All1FitBadge(
                        "RM: \(formatWeight(weightUnit.convert(rm.valor))) \(weightUnit.symbol)",
                        color: .all1FitOrange,
                        style: .gradient(Color.all1FitRunningGradient)
                    )
                }
            }

            // Compact professional table
            VStack(spacing: All1FitSpacing.xxs) {
                ForEach(ejercicio.porcentajes, id: \.porcentaje) { item in
                    HStack(spacing: 0) {
                        // Percentage with modern color bar
                        HStack(spacing: All1FitSpacing.xs) {
                            RoundedRectangle(cornerRadius: All1FitCornerRadius.xs / 2)
                                .fill(colorForPercentage(item.porcentaje))
                                .frame(width: 4, height: 32)

                            Text("\(item.porcentaje)%")
                                .font(.all1FitHeadlineSmall)
                                .foregroundStyle(colorForPercentage(item.porcentaje))
                                .frame(width: 56, alignment: .leading)
                        }

                        Spacer()

                        // Weight value - Bold and clear
                        HStack(alignment: .firstTextBaseline, spacing: All1FitSpacing.xxxs) {
                            Text(formatWeight(weightUnit.convert(item.peso)))
                                .font(.all1FitHeadlineMedium)
                                .foregroundStyle(.primary)

                            Text(weightUnit.symbol)
                                .font(.all1FitLabelSmall)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, All1FitSpacing.sm)
                    .padding(.vertical, All1FitSpacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: All1FitCornerRadius.sm)
                            .fill(colorForPercentage(item.porcentaje).opacity(0.1))
                    )
                }
            }
        }
        .padding(All1FitSpacing.md)
        .background {
            RoundedRectangle(cornerRadius: All1FitCornerRadius.lg)
                .fill(.ultraThinMaterial)
                .shadow(
                    color: All1FitShadow.medium.color,
                    radius: All1FitShadow.medium.radius,
                    x: All1FitShadow.medium.x,
                    y: All1FitShadow.medium.y
                )
        }
    }

    private func colorForPercentage(_ percentage: Int) -> Color {
        switch percentage {
        case 100: return .all1FitRed
        case 90: return .all1FitOrange
        case 80: return .all1FitWarning
        case 70: return .all1FitSuccess
        case 60: return Color.cyan
        case 50: return .all1FitBlue
        case 40: return Color.indigo
        case 30: return .all1FitPurple
        default: return .gray
        }
    }

    private func formatWeight(_ weight: Double) -> String {
        if weight.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(weight))"
        }
        return String(format: "%.1f", weight)
    }
}

// MARK: - Professional Skeleton Card
struct ProSkeletonCard: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: All1FitSpacing.md) {
            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: All1FitSpacing.xs) {
                RoundedRectangle(cornerRadius: All1FitCornerRadius.xs)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 140, height: 18)

                RoundedRectangle(cornerRadius: All1FitCornerRadius.xs)
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 90, height: 14)
            }

            Spacer()

            RoundedRectangle(cornerRadius: All1FitCornerRadius.sm)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 70, height: 36)
        }
        .padding(All1FitSpacing.md)
        .background {
            RoundedRectangle(cornerRadius: All1FitCornerRadius.lg)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        }
        .opacity(isAnimating ? 0.5 : 1.0)
        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnimating)
        .onAppear {
            isAnimating = true
        }
    }
}

#Preview {
    RMListViewPro()
}
