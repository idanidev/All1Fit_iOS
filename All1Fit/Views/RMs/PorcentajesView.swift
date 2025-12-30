import SwiftUI

// MARK: - Porcentajes View (iOS 26 Premium)
struct PorcentajesView: View {
    let ejercicio: Ejercicio
    @AppStorage("weightUnit") private var weightUnit: WeightUnit = .kg
    @State private var selectedPercentage: Int? = nil
    @State private var animateIn = false
    
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
                // Header with RM badge
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "percent")
                            .font(.title3)
                            .foregroundStyle(.orange)
                        
                        Text("Tabla de Porcentajes")
                            .font(.headline)
                    }
                    
                    Spacer()
                    
                    if let rm = ejercicio.ultimoRM {
                        HStack(spacing: 4) {
                            Text("RM")
                                .font(.caption.bold())
                                .foregroundStyle(.white.opacity(0.8))
                            Text("\(formatWeight(weightUnit.convert(rm.valor)))")
                                .font(.subheadline.bold())
                                .foregroundStyle(.white)
                            Text(weightUnit.symbol)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            LinearGradient(
                                colors: [.orange, .red],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                    }
                }
                
                // Selected weight display
                if let selected = selectedPercentage,
                   let item = ejercicio.porcentajes.first(where: { $0.porcentaje == selected }) {
                    selectedWeightDisplay(item: item)
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .opacity
                        ))
                }
                
                // Grid with staggered animation
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Array(ejercicio.porcentajes.enumerated()), id: \.element.porcentaje) { index, item in
                        PorcentajeCell(
                            porcentaje: item.porcentaje,
                            peso: weightUnit.convert(item.peso),
                            unit: weightUnit.symbol,
                            isSelected: selectedPercentage == item.porcentaje
                        )
                        .scaleEffect(animateIn ? 1 : 0.5)
                        .opacity(animateIn ? 1 : 0)
                        .animation(
                            .spring(response: 0.4, dampingFraction: 0.7)
                            .delay(Double(index) * 0.05),
                            value: animateIn
                        )
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                if selectedPercentage == item.porcentaje {
                                    selectedPercentage = nil
                                } else {
                                    selectedPercentage = item.porcentaje
                                }
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    }
                }
            }
            .padding()
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .onAppear {
                withAnimation {
                    animateIn = true
                }
            }
        }
    }
    
    // MARK: - Selected Weight Display
    private func selectedWeightDisplay(item: (porcentaje: Int, peso: Double)) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Peso seleccionado")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(formatWeight(weightUnit.convert(item.peso)))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    
                    Text(weightUnit.symbol)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Percentage ring
            ZStack {
                Circle()
                    .stroke(Color.orange.opacity(0.2), lineWidth: 6)
                
                Circle()
                    .trim(from: 0, to: CGFloat(item.porcentaje) / 100)
                    .stroke(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                
                Text("\(item.porcentaje)%")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)
            }
            .frame(width: 50, height: 50)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.orange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "percent")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            
            Text("Sin datos de RM")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Text("Añade un RM para ver los porcentajes")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    private func formatWeight(_ weight: Double) -> String {
        if weight.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(weight))"
        }
        return String(format: "%.1f", weight)
    }
}

// MARK: - Porcentaje Cell (Enhanced)
struct PorcentajeCell: View {
    let porcentaje: Int
    let peso: Double
    let unit: String
    var isSelected: Bool = false
    
    @State private var isPressed = false
    
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
        VStack(spacing: 6) {
            // Percentage badge
            Text("\(porcentaje)%")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(intensity.gradient)
                )
            
            // Weight
            Text(formatWeight(peso))
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            
            // Unit
            Text(unit)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isSelected ? intensity.color.opacity(0.2) : Color(uiColor: .tertiarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isSelected ? intensity.color : Color.clear, lineWidth: 2)
                )
        )
        .scaleEffect(isSelected ? 1.05 : 1)
        .shadow(color: isSelected ? intensity.color.opacity(0.3) : .clear, radius: 8, y: 4)
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
        
        var gradient: LinearGradient {
            switch self {
            case .max:
                return LinearGradient(colors: [.red, .pink], startPoint: .leading, endPoint: .trailing)
            case .high:
                return LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing)
            case .medium:
                return LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing)
            case .moderate:
                return LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing)
            case .low:
                return LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing)
            }
        }
    }
}

#Preview {
    ScrollView {
        PorcentajesView(ejercicio: .sample)
            .padding()
    }
    .background(Color(uiColor: .systemGroupedBackground))
}