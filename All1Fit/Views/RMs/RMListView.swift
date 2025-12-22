import SwiftUI

struct RMListView: View {
    @StateObject private var ejercicioService = EjercicioService()
    @State private var showingAddSheet = false
    @State private var searchText = ""
    
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
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()
                
                content
                
                // FAB - always on top
                fabButton
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Image("Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 32)
                }
            }
            .searchable(text: $searchText, prompt: "Buscar...")
            .refreshable {
                await ejercicioService.fetchEjercicios(forceRefresh: true)
            }
            .sheet(isPresented: $showingAddSheet) {
                EjercicioFormView(mode: .new) { name, rm in
                    Task {
                        try? await ejercicioService.createEjercicio(name: name, rm: rm)
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
            ProgressView()
                .scaleEffect(1.5)
                .tint(.orange)
        } else if filteredEjercicios.isEmpty && !searchText.isEmpty {
            ContentUnavailableView.search(text: searchText)
        } else if ejercicioService.ejercicios.isEmpty {
            emptyStateView
        } else {
            ejerciciosList
        }
    }
    
    // MARK: - List (Optimized with LazyVStack for better performance)
    private var ejerciciosList: some View {
        List {
            ForEach(filteredEjercicios) { ejercicio in
                NavigationLink {
                    RMChartView(ejercicio: ejercicio)
                } label: {
                    EjercicioRowView(ejercicio: ejercicio)
                }
            }
            .onDelete(perform: deleteEjercicios)
            
            // Spacer for FAB
            Color.clear
                .frame(height: 80)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
    }
    
    private func deleteEjercicios(at offsets: IndexSet) {
        for index in offsets {
            let ejercicio = filteredEjercicios[index]
            if let id = ejercicio.id {
                Task {
                    try? await ejercicioService.deleteEjercicio(id: id)
                }
            }
        }
    }
    
    // MARK: - FAB
    private var fabButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button {
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(
                            Circle()
                                .fill(Color.orange)
                                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                        )
                }
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            }
        }
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 50))
                .foregroundStyle(.tertiary)
            
            Text("Sin ejercicios")
                .font(.title3.bold())
            
            Text("Añade tu primer ejercicio para empezar")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Button {
                showingAddSheet = true
            } label: {
                Label("Añadir Ejercicio", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
    }
}

// MARK: - Row View (Optimized - equatable for diff)
struct EjercicioRowView: View, Equatable {
    let ejercicio: Ejercicio
    
    static func == (lhs: EjercicioRowView, rhs: EjercicioRowView) -> Bool {
        lhs.ejercicio.id == rhs.ejercicio.id &&
        lhs.ejercicio.rmHistory.count == rhs.ejercicio.rmHistory.count &&
        lhs.ejercicio.ultimoRM?.valor == rhs.ejercicio.ultimoRM?.valor
    }
    
    private var latestRM: Double {
        ejercicio.ultimoRM?.valor ?? 0
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(ejercicio.name)
                    .font(.headline)
                Text("\(ejercicio.rmHistory.count) registros")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text("\(Int(latestRM))")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)
                Text("kg")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    RMListView()
}
