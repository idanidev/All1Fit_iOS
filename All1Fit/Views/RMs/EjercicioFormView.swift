import SwiftUI

// MARK: - Form Mode
enum EjercicioFormMode {
    case new
    case addRM(ejercicio: Ejercicio)
    
    var title: String {
        switch self {
        case .new: return "Nuevo Ejercicio"
        case .addRM(let ejercicio): return ejercicio.name
        }
    }
    
    var buttonTitle: String {
        switch self {
        case .new: return "Crear"
        case .addRM: return "Guardar"
        }
    }
    
    var showNameField: Bool {
        if case .new = self { return true }
        return false
    }
}

// MARK: - Ejercicio Form View (iOS 26)
struct EjercicioFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Namespace private var animation
    
    let mode: EjercicioFormMode
    let onSave: (String, Double) -> Void
    
    @State private var name = ""
    @State private var rmValue: Double = 0
    @State private var rmText = ""
    @State private var showSuccess = false
    @FocusState private var focusedField: Field?
    
    enum Field: Hashable {
        case name, rm
    }
    
    private var isValid: Bool {
        switch mode {
        case .new:
            return !name.trimmingCharacters(in: .whitespaces).isEmpty && rmValue > 0
        case .addRM:
            return rmValue > 0
        }
    }
    
    // Suggested increments
    private let increments: [Double] = [2.5, 5, 10, 20]
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header for addRM mode
                        if case .addRM(let ejercicio) = mode {
                            headerSection(ejercicio: ejercicio)
                        }
                        
                        // Form fields
                        formFields
                        
                        // Quick increment buttons
                        quickIncrementSection
                        
                        // Common weights
                        commonWeightsSection
                    }
                    .padding()
                }
                
                // Success animation
                if showSuccess {
                    successOverlay
                }
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        save()
                    } label: {
                        Text(mode.buttonTitle)
                            .fontWeight(.semibold)
                    }
                    .disabled(!isValid)
                }
                
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Listo") {
                        focusedField = nil
                    }
                }
            }
            .onAppear {
                // Delay focus to avoid sheet animation lag
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    focusedField = mode.showNameField ? .name : .rm
                }
            }
        }
        // Sheet presentation - height based on content
        .presentationDetents([.fraction(0.7), .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.ultraThickMaterial)
        .presentationCornerRadius(24)
        .interactiveDismissDisabled(showSuccess)
    }
    
    // MARK: - Header Section (for addRM)
    private func headerSection(ejercicio: Ejercicio) -> some View {
        VStack(spacing: 12) {
            // Current RM display
            if let currentRM = ejercicio.ultimoRM {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("RM Actual")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text("\(Int(currentRM.valor)) kg")
                            .font(.title.bold())
                            .foregroundStyle(.orange)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Registrado")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text(currentRM.fecha.formatted(date: .abbreviated, time: .omitted))
                            .font(.subheadline)
                    }
                }
                .padding()
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }
    
    // MARK: - Form Fields
    private var formFields: some View {
        VStack(spacing: 16) {
            // Name field (new mode only)
            if mode.showNameField {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Nombre del ejercicio")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    TextField("Ej: Back Squat, Deadlift...", text: $name)
                        .focused($focusedField, equals: .name)
                        .textInputAutocapitalization(.words)
                        .padding()
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .submitLabel(.next)
                        .onSubmit {
                            focusedField = .rm
                        }
                }
            }
            
            // RM Value field
            VStack(alignment: .leading, spacing: 8) {
                Text("Peso Máximo (RM)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 16) {
                    TextField("0", text: $rmText)
                        .focused($focusedField, equals: .rm)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .onChange(of: rmText) { _, newValue in
                            rmValue = Double(newValue) ?? 0
                        }
                    
                    Text("kg")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }
    
    // MARK: - Quick Increment Section
    private var quickIncrementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ajuste rápido")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 12) {
                ForEach(increments, id: \.self) { increment in
                    Button {
                        withAnimation(.spring(duration: 0.3)) {
                            rmValue += increment
                            rmText = formatValue(rmValue)
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Text("+\(formatValue(increment))")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .glassCapsuleStyle(tint: .orange)
                    }
                }
            }
            
            HStack(spacing: 12) {
                ForEach(increments, id: \.self) { increment in
                    Button {
                        withAnimation(.spring(duration: 0.3)) {
                            rmValue = max(0, rmValue - increment)
                            rmText = rmValue > 0 ? formatValue(rmValue) : ""
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Text("-\(formatValue(increment))")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .glassCapsuleStyle()
                    }
                }
            }
        }
    }
    
    // MARK: - Common Weights Section
    private var commonWeightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pesos comunes")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach([40, 50, 60, 70, 80, 90, 100, 120], id: \.self) { weight in
                    Button {
                        withAnimation(.spring(duration: 0.3)) {
                            rmValue = Double(weight)
                            rmText = "\(weight)"
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Text("\(weight)")
                            .font(.headline)
                            .foregroundStyle(rmValue == Double(weight) ? .white : .primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(
                                rmValue == Double(weight)
                                ? AnyShapeStyle(LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing))
                                : AnyShapeStyle(Color(uiColor: .secondarySystemGroupedBackground))
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    // MARK: - Success Overlay
    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.green)
                    .symbolEffect(.bounce, value: showSuccess)
                
                Text("¡Guardado!")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
            }
            .padding(40)
            .glassButtonStyle(tint: .green, cornerRadius: 24)
        }
        .transition(.opacity.combined(with: .scale))
    }
    
    // MARK: - Save
    private func save() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        withAnimation(.spring(duration: 0.3)) {
            showSuccess = true
        }
        
        // Delay dismiss for animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            focusedField = nil
            dismiss()
            
            // Delay save for smooth transition
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                onSave(name, rmValue)
            }
        }
    }
    
    // MARK: - Helpers
    private func formatValue(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(value))"
        }
        return String(format: "%.1f", value)
    }
}

#Preview("New") {
    EjercicioFormView(mode: .new) { name, rm in
        // print("Created: \(name) with RM: \(rm)")
    }
}

#Preview("Add RM") {
    EjercicioFormView(mode: .addRM(ejercicio: .sample)) { _, rm in
        // print("Added RM: \(rm)")
    }
}