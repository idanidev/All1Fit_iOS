import SwiftUI

struct RMListView: View {
    @StateObject private var ejercicioService = EjercicioService()
    @State private var showingAddSheet = false
    @State private var searchText = ""
    
    var filteredEjercicios: [Ejercicio] {
        if searchText.isEmpty {
            return ejercicioService.ejercicios
        } else {
            return ejercicioService.ejercicios.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
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
                
                // FAB
                fabButton
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HeaderLogo()
                }
            }
            .searchable(text: $searchText, prompt: "Buscar ejercicio...")
            .sheet(isPresented: $showingAddSheet) {
                EjercicioFormView(mode: .new) { name, rm in
                    Task {
                        try? await ejercicioService.createEjercicio(name: name, rm: rm)
                    }
                }
            }
            .onAppear {
                ejercicioService.fetchEjercicios()
            }
        }
    }
    
    // MARK: - Ejercicios List (Optimized with List instead of ScrollView+LazyVStack)
    private var ejerciciosList: some View {
        List {
            ForEach(filteredEjercicios) { ejercicio in
                EjercicioRow(ejercicio: ejercicio, ejercicioService: ejercicioService)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            .onDelete { indexSet in
                for index in indexSet {
                    let ejercicio = filteredEjercicios[index]
                    if let id = ejercicio.id {
                        Task {
                            try? await ejercicioService.deleteEjercicio(id: id)
                        }
                    }
                }
            }
            
            // Spacer for FAB
            Color.clear.frame(height: 80)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
    
    // MARK: - FAB Button
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
                        .background(Color.orange)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
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
                .foregroundStyle(.secondary)
            
            Text("Añade tu primer ejercicio")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
            
            Button("Añadir") {
                showingAddSheet = true
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
    }
}

// MARK: - Ejercicio Row (Simplified)
struct EjercicioRow: View {
    let ejercicio: Ejercicio
    @ObservedObject var ejercicioService: EjercicioService
    @State private var showingAddRM = false
    
    private var latestRM: Double {
        ejercicio.rmHistory.max(by: { $0.fecha < $1.fecha })?.valor ?? 0
    }
    
    var body: some View {
        NavigationLink {
            EjercicioDetailView(ejercicio: ejercicio, ejercicioService: ejercicioService)
        } label: {
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
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.orange)
                    Text("kg")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Ejercicio Detail View
struct EjercicioDetailView: View {
    let ejercicio: Ejercicio
    @ObservedObject var ejercicioService: EjercicioService
    @State private var showingAddRM = false
    
    private var latestRM: Double {
        ejercicio.rmHistory.max(by: { $0.fecha < $1.fecha })?.valor ?? 0
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Current RM Card
                VStack(spacing: 8) {
                    Text("RM Actual")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(Int(latestRM))")
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                        Text("kg")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(16)
                
                // Add RM Button
                Button {
                    showingAddRM = true
                } label: {
                    Label("Añadir Nuevo RM", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                }
                
                // Percentages
                VStack(alignment: .leading, spacing: 12) {
                    Text("Porcentajes")
                        .font(.headline)
                    
                    PorcentajesView(ejercicio: ejercicio)
                }
                .padding()
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(16)
                
                // Chart
                if ejercicio.rmHistory.count >= 2 {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Progreso")
                            .font(.headline)
                        
                        RMChartView(ejercicio: ejercicio)
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .cornerRadius(16)
                }
                
                // History
                VStack(alignment: .leading, spacing: 12) {
                    Text("Historial")
                        .font(.headline)
                    
                    ForEach(ejercicio.rmHistory.sorted(by: { $0.fecha > $1.fecha })) { entry in
                        HStack {
                            Text(entry.fecha.formatted)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(Int(entry.valor)) kg")
                                .fontWeight(.semibold)
                        }
                        .padding(.vertical, 8)
                        
                        if entry.id != ejercicio.rmHistory.sorted(by: { $0.fecha > $1.fecha }).last?.id {
                            Divider()
                        }
                    }
                }
                .padding()
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(16)
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(ejercicio.name)
        .sheet(isPresented: $showingAddRM) {
            EjercicioFormView(mode: .addRM(ejercicio: ejercicio)) { _, rm in
                if let id = ejercicio.id {
                    Task {
                        try? await ejercicioService.addRM(ejercicioId: id, valor: rm)
                    }
                }
            }
        }
    }
}

#Preview {
    RMListView()
}
