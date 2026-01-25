import SwiftUI

// MARK: - RM List View (iOS 26 Premium)
struct RMListView: View {
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
                // Background
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                // Content
                content

                // Loading overlay
                if ejercicioService.isLoading {
                    VStack {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Cargando...")
                            .font(.caption)
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
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.orange, .pink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
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
            // Skeleton Loader
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
                ForEach(0..<5, id: \.self) { _ in
                    SkeletonCard()
                }
            }
            .padding()
        }
    }
    
    // MARK: - Ejercicios List
    private var ejerciciosList: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(filteredEjercicios) { ejercicio in
                    RMListRow(
                        ejercicio: ejercicio,
                        expandedEjercicioId: $expandedEjercicioId,
                        selectedEjercicio: $selectedEjercicio,
                        ejercicioToDelete: $ejercicioToDelete,
                        proxy: proxy,
                        animation: animation
                    )
                    .id(ejercicio.id)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .animation(.smooth, value: filteredEjercicios.count)
            .animation(.spring(duration: 0.3), value: expandedEjercicioId)
        }
    }


// MARK: - List Row View
struct RMListRow: View {
    let ejercicio: Ejercicio
    @Binding var expandedEjercicioId: String?
    @Binding var selectedEjercicio: Ejercicio?
    @Binding var ejercicioToDelete: Ejercicio?
    let proxy: ScrollViewProxy
    var animation: Namespace.ID

    var body: some View {
        VStack(spacing: 0) {
            // Main card with navigation
            NavigationLink {
                RMChartView(ejercicio: ejercicio)
            } label: {
                All1FitProCard(
                    gradient: LinearGradient(
                        colors: [.orange, .pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                ) {
                    HStack(spacing: 0) {
                        EjercicioRowView(
                            ejercicio: ejercicio,
                            onAddRM: {
                                selectedEjercicio = ejercicio
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }
                        )

                        // Expand button
                        Button {
                            withAnimation(.spring(duration: 0.3)) {
                                if expandedEjercicioId == ejercicio.id {
                                    expandedEjercicioId = nil
                                } else {
                                    expandedEjercicioId = ejercicio.id
                                    // Auto-scroll to make expanded content visible
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            proxy.scrollTo(ejercicio.id, anchor: .top)
                                        }
                                    }
                                }
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            Image(systemName: "percent")
                                .font(.body)
                                .foregroundStyle(.orange)
                                .rotationEffect(.degrees(expandedEjercicioId == ejercicio.id ? 180 : 0))
                                .padding(8)
                                .background(Color.orange.opacity(0.1), in: Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .buttonStyle(.plain)

            // Expandable percentage table
            if expandedEjercicioId == ejercicio.id {
                ExpandablePorcentajesView(ejercicio: ejercicio)
                    .padding(.horizontal)
                    .transition(.asymmetric(
                        insertion: .push(from: .top).combined(with: .opacity),
                        removal: .push(from: .bottom).combined(with: .opacity)
                    ))
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                ejercicioToDelete = ejercicio
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "trash.fill")
                    .font(.system(size: 20, weight: .semibold))
                    Text("Eliminar")
                    .font(.system(size: 11, weight: .medium))
                }
            }
            .tint(.red)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                selectedEjercicio = ejercicio
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    Text("Añadir")
                    .font(.system(size: 11, weight: .medium))
                }
            }
            .tint(
                LinearGradient(
                    colors: [.orange, .pink],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }
}
    
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            // Animated icon
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.orange.opacity(0.3), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)
                
                Image(systemName: "figure.cross.training")
                    .font(.system(size: 60))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
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
                        LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(Capsule())
            }
        }
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

// MARK: - Ejercicio Row View (Train/Motra style)
struct EjercicioRowView: View {
    let ejercicio: Ejercicio
    let onAddRM: () -> Void
    @State private var isPressed = false

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
        [.orange, .pink]
    }

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Circle()
                .fill(
                    LinearGradient(
                        colors: gradientColors.map { $0.opacity(0.15) },
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 56, height: 56)
                .overlay {
                    Image(systemName: ejercicio.icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: gradientColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

            // Info
            VStack(alignment: .leading, spacing: 6) {
                Text(ejercicio.name)
                    .font(.system(.headline, design: .rounded, weight: .bold))

                HStack(spacing: 8) {
                    // Record count badge
                    HStack(spacing: 3) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 10, weight: .semibold))
                        Text("\(ejercicio.rmHistory.count)")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(.orange.opacity(0.12))
                    )

                    // Last update date
                    if let ultimoRM = ejercicio.ultimoRM {
                        Text(ultimoRM.fecha.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            // RM Value
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatWeight(weightUnit.convert(latestRM)))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .contentTransition(.numericText())

                Text(weightUnit.symbol)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Quick add button
            Button {
                onAddRM()
            } label: {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.orange.opacity(0.15), .pink.opacity(0.12)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                    .overlay {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.orange, .pink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
            }
            .buttonStyle(.plain)
        }
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

// MARK: - Skeleton Card
struct SkeletonCard: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 50, height: 50)
            
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 120, height: 16)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 80, height: 12)
            }
            
            Spacer()
            
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 60, height: 30)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .opacity(isAnimating ? 0.6 : 1.0)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Expandable Porcentajes View
struct ExpandablePorcentajesView: View {
    let ejercicio: Ejercicio
    @AppStorage("weightUnit") private var weightUnit: WeightUnit = .kg

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Label("Tabla de Porcentajes", systemImage: "percent")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                Spacer()

                if let rm = ejercicio.ultimoRM {
                    Text("RM: \(formatWeight(weightUnit.convert(rm.valor))) \(weightUnit.symbol)")
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                }
            }

            // Compact table with better visual hierarchy
            VStack(spacing: 6) {
                ForEach(ejercicio.porcentajes, id: \.porcentaje) { item in
                    HStack(spacing: 0) {
                        // Percentage with color bar
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(colorForPercentage(item.porcentaje))
                                .frame(width: 4, height: 28)

                            Text("\(item.porcentaje)%")
                                .font(.system(.callout, design: .rounded, weight: .semibold))
                                .foregroundStyle(colorForPercentage(item.porcentaje))
                                .frame(width: 50, alignment: .leading)
                        }

                        Spacer()

                        // Weight value - larger and more prominent
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text(formatWeight(weightUnit.convert(item.peso)))
                                .font(.system(.title3, design: .rounded, weight: .bold))
                                .foregroundStyle(.primary)

                            Text(weightUnit.symbol)
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(colorForPercentage(item.porcentaje).opacity(0.08))
                    )
                }
            }
        }
        .padding()
        .background(Color(uiColor: .tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.top, 8)
    }

    private func colorForPercentage(_ percentage: Int) -> Color {
        switch percentage {
        case 100: return .red
        case 90: return .orange
        case 80: return .yellow
        case 70: return .green
        case 60: return .teal
        case 50: return .blue
        case 40: return .indigo
        case 30: return .purple
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

#Preview {
    RMListView()
}