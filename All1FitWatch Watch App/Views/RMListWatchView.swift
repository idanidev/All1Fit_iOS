import SwiftUI

// MARK: - RM List Watch View
struct RMListWatchView: View {
    @EnvironmentObject var connectivityService: WatchConnectivityService
    @State private var searchText = ""
    
    private var filteredEjercicios: [WatchEjercicio] {
        if searchText.isEmpty {
            return connectivityService.ejercicios
        }
        return connectivityService.ejercicios.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        Group {
            if connectivityService.ejercicios.isEmpty {
                emptyState
            } else {
                ejerciciosList
            }
        }
        .navigationTitle("RMs")
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            // Actually empty - no loading spinner if iPhone not connected
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 40))
                .foregroundStyle(.orange.opacity(0.5))
            
            Text("Sin ejercicios")
                .font(.headline)
            
            Text("Añade ejercicios desde tu iPhone")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button {
                connectivityService.requestDataFromPhone()
            } label: {
                Label("Sincronizar", systemImage: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
        .padding()
    }
    
    // MARK: - Ejercicios List
    private var ejerciciosList: some View {
        List {
            ForEach(filteredEjercicios) { ejercicio in
                NavigationLink {
                    RMDetailWatchView(ejercicio: ejercicio)
                } label: {
                    RMRowWatch(ejercicio: ejercicio)
                }
            }
        }
        .searchable(text: $searchText, prompt: "Buscar")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    AddRMWatchView()
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }
}

// MARK: - RM Row Watch
struct RMRowWatch: View {
    let ejercicio: WatchEjercicio
    @EnvironmentObject var connectivityService: WatchConnectivityService
    
    private var displayRM: String {
        guard let rm = ejercicio.ultimoRM else { return "-" }
        let converted = connectivityService.weightUnit.convert(rm.valor)
        return formatWeight(converted)
    }
    
    var body: some View {
        HStack {
            Image(systemName: ejercicio.icon)
                .foregroundStyle(.orange)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(ejercicio.name)
                    .font(.system(.body, design: .rounded))
                    .lineLimit(1)
                
                if let date = ejercicio.ultimoRM?.fecha {
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text(displayRM)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(.orange)
                
                Text(connectivityService.weightUnit.symbol)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
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
    RMListWatchView()
        .environmentObject(WatchConnectivityService.shared)
}
