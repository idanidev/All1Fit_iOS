import SwiftUI

struct ExpandablePorcentajesView: View {
    let ejercicio: Ejercicio
    @AppStorage("weightUnit") private var weightUnit: WeightUnit = .kg
    @State private var selectedPercentage: Int? = nil
    @State private var animateIn = false

    private let columns = [
        GridItem(.adaptive(minimum: 80, maximum: 100), spacing: Layout.md)
    ]

    var body: some View {
        if ejercicio.porcentajes.isEmpty {
            Text("No hay datos de 1RM para calcular porcentajes.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding()
        } else {
            VStack(spacing: Layout.sm) {
                // Lista de porcentajes
                ForEach(ejercicio.porcentajes, id: \.porcentaje) { item in
                    PorcentajeRow(
                        porcentaje: item.porcentaje,
                        peso: weightUnit.convert(item.peso),
                        unit: weightUnit.symbol,
                        isSelected: selectedPercentage == item.porcentaje
                    )
                    .onTapGesture { selectItem(item.porcentaje) }
                }
            }
            .padding(.top, Layout.md)
        }
    }

    private func selectItem(_ porcentaje: Int) {
        if selectedPercentage == porcentaje {
            selectedPercentage = nil
        } else {
            selectedPercentage = porcentaje
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }
}

// MARK: - Porcentaje Row
struct PorcentajeRow: View {
    let porcentaje: Int
    let peso: Double
    let unit: String
    var isSelected: Bool = false

    private var color: Color {
        switch porcentaje {
        case 90...100: return .all1FitRed
        case 80...89: return .all1FitOrange
        case 70...79: return .all1FitWarning
        default: return .all1FitSuccess
        }
    }

    var body: some View {
        HStack(spacing: Layout.md) {
            // Porcentaje badge
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 44, height: 44)

                Text("\(porcentaje)%")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(color)
            }

            // Peso
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(formatWeight(peso))
                        .font(.all1FitHeaderMedium)
                        .foregroundStyle(.white)

                    Text(unit)
                        .font(.all1FitSmall)
                        .foregroundStyle(.secondary)
                }

                Text(suggestedReps(for: porcentaje) + " reps")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Arrow indicator
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, Layout.md)
        .padding(.vertical, Layout.sm)
        .background(
            RoundedRectangle(cornerRadius: Layout.radiusSm)
                .fill(isSelected ? color.opacity(0.1) : Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Layout.radiusSm)
                .strokeBorder(isSelected ? color.opacity(0.5) : Color.clear, lineWidth: 1.5)
        )
    }

    private func formatWeight(_ weight: Double) -> String {
        if weight.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(weight))"
        }
        return String(format: "%.1f", weight)
    }

    private func suggestedReps(for percent: Int) -> String {
        switch percent {
        case 100: return "1"
        case 90: return "3-4"
        case 80: return "7-8"
        case 70: return "12"
        case 60: return "15+"
        case 50: return "20+"
        case 40: return "25+"
        case 30: return "30+"
        default: return "15+"
        }
    }
}
