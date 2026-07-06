import SwiftUI

// MARK: - Calculadora de Discos
/// Dado un peso objetivo y una barra, calcula los discos por lado.
struct PlateCalculatorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var targetText: String
    @State private var barWeight: Double = 20

    private let bars: [Double] = [20, 15, 10]
    private let availablePlates: [Double] = [25, 20, 15, 10, 5, 2.5, 1.25]

    init(initialWeight: Double = 60) {
        _targetText = State(initialValue: initialWeight > 0 ? Self.format(initialWeight) : "")
    }

    private var targetWeight: Double {
        Double(targetText.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    /// (disco, cantidad por lado) usando greedy sobre discos estándar
    private var platesPerSide: [(plate: Double, count: Int)] {
        var remainingPerSide = max(0, (targetWeight - barWeight) / 2)
        var result: [(Double, Int)] = []
        for plate in availablePlates {
            let count = Int(remainingPerSide / plate)
            if count > 0 {
                result.append((plate, count))
                remainingPerSide -= Double(count) * plate
                remainingPerSide = (remainingPerSide * 100).rounded() / 100
            }
        }
        return result
    }

    private var achievableWeight: Double {
        barWeight + platesPerSide.reduce(0) { $0 + $1.plate * Double($1.count) } * 2
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Peso objetivo
                    VStack(spacing: 10) {
                        Text("Peso objetivo (kg)")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(.secondary)
                        TextField("0", text: $targetText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.center)
                            .font(.system(size: 44, weight: .black, design: .rounded))
                            .foregroundStyle(Color.all1FitBlue)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // Barra
                    VStack(spacing: 12) {
                        Text("Barra")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(.secondary)
                        HStack(spacing: 8) {
                            ForEach(bars, id: \.self) { bar in
                                Button {
                                    barWeight = bar
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                } label: {
                                    Text("\(Self.format(bar)) kg")
                                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                        .foregroundStyle(barWeight == bar ? .white : .primary)
                                        .padding(.horizontal, 18)
                                        .padding(.vertical, 8)
                                        .background(barWeight == bar ? AnyShapeStyle(Color.all1FitBlue) : AnyShapeStyle(Color(uiColor: .tertiarySystemGroupedBackground)))
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // Resultado
                    resultCard
                }
                .padding(20)
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Discos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
        .presentationDetents([.fraction(0.75), .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
    }

    @ViewBuilder
    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Por lado", systemImage: "circle.circle.fill")
                .font(.headline)

            if targetWeight <= barWeight {
                Text(targetWeight == 0 ? "Introduce un peso objetivo" : "Solo la barra (\(Self.format(barWeight)) kg)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(platesPerSide, id: \.plate) { entry in
                        HStack {
                            Circle()
                                .fill(plateColor(entry.plate).opacity(0.25))
                                .overlay {
                                    Circle().strokeBorder(plateColor(entry.plate), lineWidth: 2)
                                }
                                .frame(width: plateSize(entry.plate), height: plateSize(entry.plate))
                                .overlay {
                                    Text(Self.format(entry.plate))
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .foregroundStyle(plateColor(entry.plate))
                                }
                            Spacer()
                            Text("× \(entry.count)")
                                .font(.system(.title3, design: .rounded, weight: .black))
                                .foregroundStyle(Color.all1FitBlue)
                        }
                    }
                }

                Divider()

                HStack {
                    Text("Total montado")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Self.format(achievableWeight)) kg")
                        .font(.system(.headline, design: .rounded, weight: .black))
                        .foregroundStyle(achievableWeight == targetWeight ? Color.all1FitSuccess : Color.all1FitWarning)
                }

                if achievableWeight != targetWeight {
                    Text("No se puede montar exacto con discos estándar; faltan \(Self.format(targetWeight - achievableWeight)) kg")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    /// Colores IWF aproximados por disco
    private func plateColor(_ plate: Double) -> Color {
        switch plate {
        case 25: return .red
        case 20: return .blue
        case 15: return .yellow
        case 10: return .green
        case 5: return .white
        default: return .gray
        }
    }

    private func plateSize(_ plate: Double) -> CGFloat {
        switch plate {
        case 25, 20: return 44
        case 15, 10: return 38
        default: return 32
        }
    }

    private static func format(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(value))" : String(format: "%g", value)
    }
}

#Preview {
    PlateCalculatorView(initialWeight: 102.5)
        .preferredColorScheme(.dark)
}
