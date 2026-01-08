import SwiftUI

// MARK: - Add RM Watch View
struct AddRMWatchView: View {
    @EnvironmentObject var connectivityService: WatchConnectivityService
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedEjercicio: WatchEjercicio?
    @State private var newEjercicioName = ""
    @State private var isNewEjercicio = false
    @State private var peso: Double = 60
    @State private var isSaving = false
    @State private var showSuccess = false
    
    private let pesoRange: ClosedRange<Double> = 10...300
    private let pesoStep: Double = 2.5
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Ejercicio Selection
                ejercicioSection
                
                // Peso Input
                pesoSection
                
                // Save Button
                saveButton
            }
            .padding(.horizontal)
        }
        .navigationTitle("Nuevo RM")
        .overlay {
            if showSuccess {
                successOverlay
            }
        }
    }
    
    // MARK: - Ejercicio Section
    private var ejercicioSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ejercicio")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            if isNewEjercicio {
                TextField("Nombre", text: $newEjercicioName)
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                
                Button {
                    isNewEjercicio = false
                    newEjercicioName = ""
                } label: {
                    Text("Elegir existente")
                        .font(.caption2)
                }
            } else {
                if connectivityService.ejercicios.isEmpty {
                    TextField("Nombre", text: $newEjercicioName)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                } else {
                    Picker("Ejercicio", selection: $selectedEjercicio) {
                        Text("Seleccionar...").tag(nil as WatchEjercicio?)
                        ForEach(connectivityService.ejercicios) { ejercicio in
                            Text(ejercicio.name).tag(ejercicio as WatchEjercicio?)
                        }
                    }
                    .pickerStyle(.navigationLink)
                    
                    Button {
                        isNewEjercicio = true
                        selectedEjercicio = nil
                    } label: {
                        Label("Nuevo ejercicio", systemImage: "plus")
                            .font(.caption2)
                    }
                }
            }
        }
    }
    
    // MARK: - Peso Section
    private var pesoSection: some View {
        VStack(spacing: 8) {
            Text("Peso")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack {
                Text("\(formatWeight(peso))")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)
                
                Text(connectivityService.weightUnit.symbol)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            .focusable()
            .digitalCrownRotation(
                $peso,
                from: pesoRange.lowerBound,
                through: pesoRange.upperBound,
                by: pesoStep,
                sensitivity: .medium,
                isContinuous: false,
                isHapticFeedbackEnabled: true
            )
            
            // Quick adjust buttons
            HStack(spacing: 12) {
                Button {
                    peso = max(pesoRange.lowerBound, peso - 5)
                } label: {
                    Text("-5")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                
                Button {
                    peso = min(pesoRange.upperBound, peso + 5)
                } label: {
                    Text("+5")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }
            
            Text("Usa la corona para ajustar")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
    
    // MARK: - Save Button
    private var saveButton: some View {
        Button {
            saveRM()
        } label: {
            if isSaving {
                ProgressView()
            } else {
                Label("Guardar", systemImage: "checkmark.circle.fill")
            }
        }
        .buttonStyle(.borderedProminent)
        .tint(.orange)
        .disabled(!canSave || isSaving)
    }
    
    // MARK: - Success Overlay
    private var successOverlay: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 50))
                .foregroundStyle(.green)
            
            Text("¡Guardado!")
                .font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Helpers
    private var canSave: Bool {
        let hasEjercicio = selectedEjercicio != nil || !newEjercicioName.trimmingCharacters(in: .whitespaces).isEmpty
        return hasEjercicio && peso > 0
    }
    
    private var ejercicioName: String {
        if let selected = selectedEjercicio {
            return selected.name
        }
        return newEjercicioName.trimmingCharacters(in: .whitespaces)
    }
    
    private func formatWeight(_ weight: Double) -> String {
        if weight.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(weight))"
        }
        return String(format: "%.1f", weight)
    }
    
    private func saveRM() {
        isSaving = true
        
        // Convert to kg if user uses lbs
        let valorKg: Double
        if connectivityService.weightUnit == .lbs {
            valorKg = peso / 2.20462
        } else {
            valorKg = peso
        }
        
        connectivityService.sendNewRM(
            ejercicioId: selectedEjercicio?.id,
            ejercicioName: ejercicioName,
            valor: valorKg
        ) { success in
            isSaving = false
            
            if success {
                WKInterfaceDevice.current().play(.success)
                showSuccess = true
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    dismiss()
                }
            } else {
                WKInterfaceDevice.current().play(.failure)
            }
        }
    }
}

#Preview {
    NavigationStack {
        AddRMWatchView()
            .environmentObject(WatchConnectivityService.shared)
    }
}
