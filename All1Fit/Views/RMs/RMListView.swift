import SwiftUI

// MARK: - RM List View (iOS 26 Premium)
struct RMListView: View {
    @StateObject private var ejercicioService = EjercicioService()
    @Namespace private var animation
    
    @State private var showingAddSheet = false
    @State private var searchText = ""
    @State private var selectedEjercicio: Ejercicio?
    @State private var expandedEjercicioId: String?
    
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
                
                // Floating Add Button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            showingAddSheet = true
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        } label: {
                            Image(systemName: "plus")
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                                .frame(width: 56, height: 56)
                                .background(
                                    LinearGradient(
                                        colors: [.orange, .yellow],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .clipShape(Circle())
                                .shadow(color: .orange.opacity(0.4), radius: 8, y: 4)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Image("Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 80) // Reduced to fit Dynamic Island
                        .shadow(color: .white.opacity(0.5), radius: 10) // Glow for dark mode
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
        List {
            ForEach(filteredEjercicios) { ejercicio in
                VStack(spacing: 0) {
                    // Main row with navigation
                    HStack {
                        NavigationLink {
                            RMChartView(ejercicio: ejercicio)
                        } label: {
                            EjercicioRowView(
                                ejercicio: ejercicio,
                                onAddRM: {
                                    selectedEjercicio = ejercicio
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }
                            )
                        }
                        
                        // Expand button
                        Button {
                            withAnimation(.spring(duration: 0.3)) {
                                if expandedEjercicioId == ejercicio.id {
                                    expandedEjercicioId = nil
                                } else {
                                    expandedEjercicioId = ejercicio.id
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
                    
                    // Expandable percentage table
                    if expandedEjercicioId == ejercicio.id {
                        ExpandablePorcentajesView(ejercicio: ejercicio)
                            .transition(.asymmetric(
                                insertion: .push(from: .top).combined(with: .opacity),
                                removal: .push(from: .bottom).combined(with: .opacity)
                            ))
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        deleteEjercicio(ejercicio)
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
                    .tint(.orange)
                }
            }
        }
        .listStyle(.plain)
        .animation(.smooth, value: filteredEjercicios.count)
        .animation(.spring(duration: 0.3), value: expandedEjercicioId)
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

// MARK: - Ejercicio Row View (iOS 26)
struct EjercicioRowView: View {
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
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon with trend indicator
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.orange.opacity(0.2), .red.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                
                Image(systemName: ejercicio.icon)
                    .font(.title3)
                    .foregroundStyle(.orange)
                    .frame(width: 50, height: 50)
                
                // Trend badge
                if trend != .neutral {
                    Image(systemName: trend == .up ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                        .font(.caption)
                        .foregroundStyle(trend == .up ? .green : .red)
                        .background(Circle().fill(.background))
                        .offset(x: 4, y: 4)
                }
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(ejercicio.name)
                    .font(.headline)
                
                HStack(spacing: 4) {
                    Text("\(ejercicio.rmHistory.count) registros")
                    
                    if let ultimoRM = ejercicio.ultimoRM {
                        Text("•")
                        Text(ultimoRM.fecha.formatted(date: .abbreviated, time: .omitted))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // RM Value
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatWeight(weightUnit.convert(latestRM)))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .red],
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
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
                    .symbolEffect(.bounce, value: latestRM)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
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
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
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
            
            // Grid
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(ejercicio.porcentajes, id: \.porcentaje) { item in
                    VStack(spacing: 2) {
                        Text("\(item.porcentaje)%")
                            .font(.caption2.bold())
                            .foregroundStyle(colorForPercentage(item.porcentaje))
                        
                        Text(formatWeight(weightUnit.convert(item.peso)))
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)
                        
                        Text(weightUnit.symbol)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(colorForPercentage(item.porcentaje).opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
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