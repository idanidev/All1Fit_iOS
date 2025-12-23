import SwiftUI

// MARK: - Porcentajes View (iOS 26)
struct PorcentajesView: View {
    let ejercicio: Ejercicio
    @AppStorage("weightUnit") private var weightUnit: WeightUnit = .kg
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        if ejercicio.porcentajes.isEmpty {
            emptyState
        } else {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Label("Tabla de Porcentajes", systemImage: "percent")
                        .font(.headline)
                    
                    Spacer()
                    
                    if let rm = ejercicio.ultimoRM {
                        Text("RM: \(formatWeight(weightUnit.convert(rm.valor))) \(weightUnit.symbol)")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                    }
                }
                
                // Grid
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(ejercicio.porcentajes, id: \.porcentaje) { item in
                        PorcentajeCell(
                            porcentaje: item.porcentaje,
                            peso: weightUnit.convert(item.peso),
                            unit: weightUnit.symbol
                        )
                    }
                }
            }
            .padding()
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "percent")
                .font(.title)
                .foregroundStyle(.secondary)
            
            Text("Sin datos de RM")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
    
    private func formatWeight(_ weight: Double) -> String {
        if weight.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(weight))"
        }
        return String(format: "%.1f", weight)
    }
}

// MARK: - Porcentaje Cell
struct PorcentajeCell: View {
    let porcentaje: Int
    let peso: Double
    let unit: String
    
    private var intensity: CellIntensity {
        switch porcentaje {
        case 100: return .max
        case 90...99: return .high
        case 80...89: return .medium
        case 70...79: return .moderate
        default: return .low
        }
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(porcentaje)%")
                .font(.caption.bold())
                .foregroundStyle(intensity.color)
            
            Text(formatWeight(peso))
                .font(.subheadline.bold())
                .foregroundStyle(.primary)
            
            Text(unit)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(intensity.backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    private func formatWeight(_ weight: Double) -> String {
        if weight.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(weight))"
        }
        return String(format: "%.1f", weight)
    }
    
    enum CellIntensity {
        case max, high, medium, moderate, low
        
        var color: Color {
            switch self {
            case .max: return .red
            case .high: return .orange
            case .medium: return .yellow
            case .moderate: return .green
            case .low: return .blue
            }
        }
        
        var backgroundColor: Color {
            color.opacity(0.15)
        }
    }
}

#Preview {
    ScrollView {
        PorcentajesView(ejercicio: .sample)
            .padding()
    }
}