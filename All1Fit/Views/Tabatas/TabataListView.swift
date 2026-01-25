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
                            TabataListRow(
                                tabata: tabata,
                                selectedType: selectedType,
                                tabataToDelete: $tabataToDelete,
                                tabataToEdit: $tabataToEdit,
                                tabataService: tabataService
                            )
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
            .navigationTitle("Tabatas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddTabata = true
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: typeColors,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .symbolRenderingMode(.hierarchical)
                    }
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

// MARK: - Tabata List Row
struct TabataListRow: View {
    let tabata: Tabata
    let selectedType: TabataType
    @Binding var tabataToDelete: Tabata?
    @Binding var tabataToEdit: Tabata?
    @ObservedObject var tabataService: TabataService

    var body: some View {
        NavigationLink {
            TabataDetailView(tabata: tabata)
                .environmentObject(tabataService)
        } label: {
            All1FitProCard(
                gradient: LinearGradient(
                    colors: tabata.type == .intervals ? [.orange, .pink] : [.blue, .cyan],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            ) {
                TabataCard(
                    tabata: tabata,
                    resultCount: tabataService.resultCount(for: tabata.id),
                    lastResult: tabataService.lastResult(for: tabata.id)
                )
            }
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if tabata.isCustom {
                Button(role: .destructive) {
                    tabataToDelete = tabata
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
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            if tabata.isCustom {
                Button {
                    tabataToEdit = tabata
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 20, weight: .semibold))
                        Text("Editar")
                            .font(.system(size: 11, weight: .medium))
                    }
                }
                .tint(.blue)
            }
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
