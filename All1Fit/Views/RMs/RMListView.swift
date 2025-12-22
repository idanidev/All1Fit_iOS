import SwiftUI

struct RMListView: View {
    @StateObject private var ejercicioService = EjercicioService()
    @State private var showingAddSheet = false
    @State private var searchText = ""
    
    var filteredEjercicios: [Ejercicio] {
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
    
    // MARK: - List
    private var ejerciciosList: some View {
        List {
            ForEach(filteredEjercicios) { ejercicio in
                NavigationLink {
                    RMChartView(ejercicio: ejercicio)
                } label: {
                    EjercicioRowView(ejercicio: ejercicio)
                }
            }
            .onDelete { indexSet in
                for index in indexSet {
                    let ejercicio = filteredEjercicios[index]
                    if let id = ejercicio.id {
                        Task { try? await ejercicioService.deleteEjercicio(id: id) }
                    }
                }
            }
        }
        .listStyle(.plain)
    }
    
    // MARK: - FAB
    private var fabButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button { showingAddSheet = true } label: {
                    Image(systemName: "plus")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.orange)
                        .clipShape(Circle())
                        .shadow(radius: 4)
                }
                .padding()
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
            Button("Añadir") { showingAddSheet = true }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
        }
    }
}

// MARK: - Row View
struct EjercicioRowView: View {
    let ejercicio: Ejercicio
    
    private var latestRM: Double {
        ejercicio.rmHistory.max(by: { $0.fecha < $1.fecha })?.valor ?? 0
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
