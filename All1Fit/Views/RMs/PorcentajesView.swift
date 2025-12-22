import SwiftUI

struct PorcentajesView: View {
    let ejercicio: Ejercicio
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        if ejercicio.porcentajes.isEmpty {
            Text("Sin datos de RM")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding()
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("Tabla de Porcentajes")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(ejercicio.porcentajes, id: \.porcentaje) { item in
                        PorcentajeCell(
                            porcentaje: item.porcentaje,
                            peso: item.peso
                        )
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Porcentaje Cell
struct PorcentajeCell: View {
    let porcentaje: Int
    let peso: Double
    
    private var backgroundColor: Color {
        switch porcentaje {
        case 100:
            return .red.opacity(0.15)
        case 90...99:
            return .orange.opacity(0.15)
        case 80...89:
            return .yellow.opacity(0.15)
        case 70...79:
            return .green.opacity(0.15)
        default:
            return .blue.opacity(0.15)
        }
    }
    
    private var textColor: Color {
        switch porcentaje {
        case 100:
            return .red
        case 90...99:
            return .orange
        case 80...89:
            return .yellow
        case 70...79:
            return .green
        default:
            return .blue
        }
    }
    
    var body: some View {
        VStack(spacing: 2) {
            Text("\(porcentaje)%")
                .font(.caption2.bold())
                .foregroundStyle(textColor)
            
            Text(formatWeight(peso))
                .font(.footnote.bold())
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(backgroundColor)
        .cornerRadius(8)
    }
    
    private func formatWeight(_ weight: Double) -> String {
        if weight.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(weight)) kg"
        } else {
            return String(format: "%.1f kg", weight)
        }
    }
}

#Preview {
    List {
        PorcentajesView(ejercicio: .sample)
    }
}
