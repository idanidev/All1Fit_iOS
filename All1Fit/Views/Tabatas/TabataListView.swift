import SwiftUI

// MARK: - Tabata List View
struct TabataListView: View {
    @StateObject private var tabataService = TabataService()
    @State private var selectedType: TabataType = .intervals
    @State private var showingAddTabata = false
    @State private var tabataToEdit: Tabata?
    @State private var tabataToDelete: Tabata?
    @State private var searchText = ""
    @State private var selectedTabata: Tabata?
    @State private var errorMessage: String?

    private var filteredTabatas: [Tabata] {
        let tabatas = tabataService.allTabatas.filter { $0.type == selectedType }
        if searchText.isEmpty { return tabatas }
        return tabatas.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var typeGradient: [Color] {
        selectedType == .intervals ? [.orange, .red] : [.blue, .cyan]
    }

    var body: some View {
        // Sin NavigationStack propio: se presenta pushed desde TrainingHubView
        Group {
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
                            tabataService: tabataService,
                            onTap: { selectedTabata = tabata }
                        )
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .overlay {
                if tabataService.isLoading {
                    ProgressView("Cargando...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.ultraThinMaterial)
                }
            }
            .navigationTitle("Tabatas")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddTabata = true
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(
                                LinearGradient(colors: typeGradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
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
            .navigationDestination(item: $selectedTabata) { tabata in
                TabataDetailView(tabata: tabata)
                    .environmentObject(tabataService)
            }
            .searchable(text: $searchText, prompt: "Buscar tabata...")
            .task {
                await tabataService.fetchTabatas()
                await tabataService.fetchAllResults()
            }
            .refreshable {
                await tabataService.fetchTabatas()
                await tabataService.fetchAllResults(forceRefresh: true)
            }
            .all1FitConfirmation(Binding(
                get: {
                    tabataToDelete.map { tabata in
                        All1FitConfirmation(
                            title: "¿Eliminar tabata?",
                            message: "\"\(tabata.name)\" se eliminará. Esta acción no se puede deshacer.",
                            icon: "trash.fill",
                            confirmTitle: "Eliminar"
                        ) {
                            Task {
                                do {
                                    try await tabataService.deleteTabata(tabata)
                                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                                } catch {
                                    errorMessage = error.localizedDescription
                                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                                }
                            }
                        }
                    }
                },
                set: { if $0 == nil { tabataToDelete = nil } }
            ))
            .alert("Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - Type Selector
    private var typeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(TabataType.allCases, id: \.self) { type in
                    TabataTypePill(
                        type: type,
                        isSelected: selectedType == type
                    ) {
                        withAnimation(.spring(duration: 0.3)) { selectedType = type }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
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
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            TabataCard(
                tabata: tabata,
                resultCount: tabataService.resultCount(for: tabata.id),
                lastResult: tabataService.lastResult(for: tabata.id)
            )
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if tabata.isCustom {
                Button(role: .destructive) {
                    tabataToDelete = tabata
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "trash.fill").font(.system(size: 20, weight: .semibold))
                        Text("Eliminar").font(.system(size: 11, weight: .medium))
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
                        Image(systemName: "pencil.circle.fill").font(.system(size: 20, weight: .semibold))
                        Text("Editar").font(.system(size: 11, weight: .medium))
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

    private var gradient: [Color] { type == .intervals ? [.orange, .red] : [.blue, .cyan] }
    private var accentColor: Color { type == .intervals ? .orange : .blue }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: type.icon)
                Text(type.displayName)
            }
            .font(.system(.subheadline, design: .rounded, weight: .semibold))
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background {
                if isSelected {
                    Capsule()
                        .fill(LinearGradient(colors: gradient, startPoint: .leading, endPoint: .trailing))
                } else {
                    Capsule()
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                        .overlay(Capsule().strokeBorder(.white.opacity(0.1), lineWidth: 1))
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tabata Card
struct TabataCard: View {
    let tabata: Tabata
    let resultCount: Int
    let lastResult: TabataResult?

    private var gradient: [Color] { tabata.type == .intervals ? [.orange, .red] : [.blue, .cyan] }
    private var accentColor: Color { tabata.type == .intervals ? .orange : .blue }

    var body: some View {
        HStack(spacing: 0) {
            // Left accent bar
            RoundedRectangle(cornerRadius: 3)
                .fill(LinearGradient(colors: gradient, startPoint: .top, endPoint: .bottom))
                .frame(width: 4)
                .padding(.vertical, 10)
                .padding(.trailing, 12)

            HStack(spacing: 14) {
                // Icon
                Image(systemName: tabata.type.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 44, height: 44)
                    .background(accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(accentColor.opacity(0.2), lineWidth: 1)
                    )

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(tabata.name)
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .lineLimit(1)
                            .foregroundStyle(.primary)

                        if tabata.isCustom {
                            Image(systemName: "star.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(.yellow)
                        }

                        if resultCount > 0 {
                            Text("\(resultCount)")
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(.green, in: Capsule())
                        }
                    }

                    Text(tabata.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Label(tabata.formattedDuration, systemImage: "timer")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(accentColor)

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

                Spacer(minLength: 4)

                if let lastResult = lastResult {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(lastResult.formattedTime)
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                        Text("último")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(accentColor.opacity(0.05))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(.white.opacity(0.07), lineWidth: 1)
                }
        }
    }
}

#Preview {
    TabataListView()
}
