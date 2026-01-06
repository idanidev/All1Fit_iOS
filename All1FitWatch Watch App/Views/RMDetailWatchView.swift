import SwiftUI

// MARK: - RM Detail Watch View
struct RMDetailWatchView: View {
    let ejercicio: WatchEjercicio
    @EnvironmentObject var connectivityService: WatchConnectivityService
    @State private var selectedTab = 0
    
    private var displayRM: String {
        guard let rm = ejercicio.ultimoRM else { return "-" }
        let converted = connectivityService.weightUnit.convert(rm.valor)
        return formatWeight(converted)
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: RM Info
            rmInfoView
                .tag(0)
            
            // Tab 2: Percentage Table
            percentageTableView
                .tag(1)
        }
        .tabViewStyle(.verticalPage)
        .navigationTitle(ejercicio.name)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - RM Info View
    private var rmInfoView: some View {
        VStack(spacing: 8) {
            // Icon
            ZStack {
                Circle()
                    .fill(.orange.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: ejercicio.icon)
                    .font(.title2)
                    .foregroundStyle(.orange)
            }
            
            // RM Value
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(displayRM)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)
                
                Text(connectivityService.weightUnit.symbol)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            
            // Date
            if let date = ejercicio.ultimoRM?.fecha {
                Text(date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // History count
            Text("\(ejercicio.rmHistory.count) registros")
                .font(.caption2)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            // Swipe hint
            HStack {
                Image(systemName: "chevron.down")
                Text("Porcentajes")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding()
    }
    
    // MARK: - Percentage Table View
    private var percentageTableView: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("%")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .frame(width: 40, alignment: .leading)
                    
                    Spacer()
                    
                    Text(connectivityService.weightUnit.symbol)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 4)
                
                Divider()
                
                // Rows
                ForEach(ejercicio.porcentajes, id: \.porcentaje) { item in
                    percentageRow(item: item)
                }
            }
        }
    }
    
    // MARK: - Percentage Row
    private func percentageRow(item: (porcentaje: Int, peso: Double)) -> some View {
        let converted = connectivityService.weightUnit.convert(item.peso)
        let isHighIntensity = item.porcentaje >= 85
        let isMediumIntensity = item.porcentaje >= 70 && item.porcentaje < 85
        
        return HStack {
            // Percentage
            Text("\(item.porcentaje)%")
                .font(.system(.body, design: .rounded, weight: isHighIntensity ? .bold : .regular))
                .foregroundStyle(colorForPercentage(item.porcentaje))
                .frame(width: 50, alignment: .leading)
            
            // Intensity indicator
            Circle()
                .fill(colorForPercentage(item.porcentaje))
                .frame(width: 8, height: 8)
            
            Spacer()
            
            // Weight
            Text(formatWeight(converted))
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            item.porcentaje == 100 ? Color.orange.opacity(0.15) : Color.clear
        )
    }
    
    // MARK: - Helpers
    private func colorForPercentage(_ percentage: Int) -> Color {
        switch percentage {
        case 95...100: return .red
        case 85...94: return .orange
        case 75...84: return .yellow
        case 65...74: return .green
        case 50...64: return .teal
        default: return .blue
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
    let sampleEjercicio = WatchEjercicio(
        id: "1",
        name: "Back Squat",
        rmHistory: [
            WatchRMEntry(valor: 120, fecha: Date())
        ]
    )
    
    return NavigationStack {
        RMDetailWatchView(ejercicio: sampleEjercicio)
    }
    .environmentObject(WatchConnectivityService.shared)
}
