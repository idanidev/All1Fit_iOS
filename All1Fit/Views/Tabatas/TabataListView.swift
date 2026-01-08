import SwiftUI

// MARK: - Tabata List View
struct TabataListView: View {
    @StateObject private var tabataService = TabataService()
    @State private var selectedType: TabataType = .intervals
    @State private var showingAddTabata = false
    @State private var tabataToEdit: Tabata?
    @State private var tabataToDelete: Tabata?
    @State private var searchText = ""
    
    private var filteredTabatas: [Tabata] {
        let tabatas = tabataService.allTabatas.filter { $0.type == selectedType }
        if searchText.isEmpty {
            return tabatas
        } else {
            return tabatas.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    private var typeColors: [Color] {
        selectedType == .intervals ? [.orange, .red] : [.blue, .cyan]
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                List {
                    // Type selector
                    Section {
                        typeSelector
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    
                    // Tabatas
                    Section {
                        ForEach(filteredTabatas) { tabata in
                            NavigationLink {
                                TabataDetailView(tabata: tabata)
                                    .environmentObject(tabataService)
                            } label: {
                                TabataCard(
                                    tabata: tabata,
                                    resultCount: tabataService.resultCount(for: tabata.id),
                                    lastResult: tabataService.lastResult(for: tabata.id)
                                )
                            }
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                if tabata.isCustom {
                                    Button(role: .destructive) {
                                        tabataToDelete = tabata
                                    } label: {
                                        Label("Eliminar", systemImage: "trash")
                                    }
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                if tabata.isCustom {
                                    Button {
                                        tabataToEdit = tabata
                                    } label: {
                                        Label("Editar", systemImage: "pencil")
                                    }
                                    .tint(.orange)
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color(uiColor: .systemGroupedBackground))
                .overlay {
                    if tabataService.isLoading {
                        ProgressView("Cargando...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(.ultraThinMaterial)
                    }
                }
                
                // Floating Add Button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            showingAddTabata = true
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "plus")
                                    .font(.title3.bold())
                                Text("Crear")
                                    .font(.headline)
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: typeColors,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(Capsule())
                            .shadow(color: typeColors[0].opacity(0.4), radius: 8, y: 4)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 30)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Image("Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 80)
                        .shadow(color: .white.opacity(0.5), radius: 10)
                }
            }
            .sheet(isPresented: $showingAddTabata) {
                TabataFormView(type: selectedType)
                    .environmentObject(tabataService)
            }
            .sheet(item: $tabataToEdit) { tabata in
                TabataFormView(tabataToEdit: tabata)
                    .environmentObject(tabataService)
            }
            .searchable(text: $searchText, prompt: "Buscar tabata...")
            .task {
                await tabataService.fetchTabatas()
                // Fetch results for all tabatas
                for tabata in tabataService.allTabatas {
                    await tabataService.fetchResults(for: tabata.id)
                }
            }
            .refreshable {
                await tabataService.fetchTabatas()
            }
            .confirmationDialog(
                "¿Eliminar tabata?",
                isPresented: Binding(
                    get: { tabataToDelete != nil },
                    set: { if !$0 { tabataToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Eliminar \(tabataToDelete?.name ?? "")", role: .destructive) {
                    if let tabata = tabataToDelete {
                        Task {
                            try? await tabataService.deleteTabata(tabata)
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        }
                    }
                }
                Button("Cancelar", role: .cancel) {
                    tabataToDelete = nil
                }
            }
        }
    }
    
    // MARK: - Type Selector
    private var typeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(TabataType.allCases, id: \.self) { type in
                    TabataTypePill(
                        type: type,
                        isSelected: selectedType == type
                    ) {
                        withAnimation(.spring(duration: 0.3)) {
                            selectedType = type
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Type Pill
struct TabataTypePill: View {
    let type: TabataType
    let isSelected: Bool
    let action: () -> Void
    
    private var typeColor: Color {
        type == .intervals ? .orange : .blue
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: type.icon)
                Text(type.displayName)
            }
            .font(.subheadline.bold())
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                isSelected
                ? AnyShapeStyle(typeColor)
                : AnyShapeStyle(Color(uiColor: .secondarySystemGroupedBackground))
            )
            .clipShape(Capsule())
        }
    }
}

// MARK: - Tabata Card
struct TabataCard: View {
    let tabata: Tabata
    let resultCount: Int
    let lastResult: TabataResult?
    
    private var cardColor: Color {
        tabata.type == .intervals ? .orange : .blue
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon with badge
            ZStack(alignment: .topTrailing) {
                ZStack {
                    Circle()
                        .fill(cardColor.opacity(0.15))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: tabata.type.icon)
                        .font(.title2)
                        .foregroundStyle(cardColor)
                }
                
                // Record badge
                if resultCount > 0 {
                    Text("\(resultCount)")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .frame(minWidth: 18, minHeight: 18)
                        .background(Color.green)
                        .clipShape(Circle())
                        .offset(x: 4, y: -4)
                }
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(tabata.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    if tabata.isCustom {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                    
                    if resultCount > 0 {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
                
                // Subtitle
                Text(tabata.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                // Last result
                if let lastResult = lastResult {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.caption2)
                        Text(lastResult.formattedTime)
                            .font(.caption.bold())
                    }
                    .foregroundStyle(.orange)
                }
                
                // Tags
                HStack(spacing: 8) {
                    Label(tabata.formattedDuration, systemImage: "timer")
                        .font(.caption2)
                        .foregroundStyle(cardColor)
                    
                    if tabata.type == .treadmill, let phases = tabata.treadmillPhases {
                        Label("\(phases.count) fases", systemImage: "stairs")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        Label("\(tabata.rounds) rondas", systemImage: "repeat")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    TabataListView()
}
