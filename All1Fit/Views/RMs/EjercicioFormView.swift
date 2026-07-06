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
    let onSave: (String, Double, EjercicioStyle, Int?) -> Void

    @State private var name = ""
    @State private var selectedStyle: EjercicioStyle = .barbell
    @State private var rmValue: Double = 0
    @State private var rmText = ""
    @State private var gymReps: Int = 10
    @State private var gymRepsText = "10"
    @State private var showSuccess = false
    @State private var showRepCalculator = false
    @State private var repWeightText = ""
    @State private var repWeightValue: Double = 0
    @State private var repsText = ""
    @State private var repsValue: Int = 0
    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case name, rm, repWeight, reps, gymReps
    }

    private var isGymStyle: Bool {
        switch mode {
        case .addRM(let ejercicio): return ejercicio.style == .dumbbell
        case .new: return selectedStyle == .dumbbell
        }
    }

    /// Fórmula de Epley: 1RM ≈ peso × (1 + reps/30)
    private var calculatedRM: Double? {
        guard repWeightValue > 0, repsValue > 1 else { return nil }
        let result = repWeightValue * (1.0 + Double(repsValue) / 30.0)
        return round(result * 4) / 4  // Redondear al 0.25 más cercano
    }
    
    private var isValid: Bool {
        switch mode {
        case .new:
            return !name.trimmingCharacters(in: .whitespaces).isEmpty && rmValue > 0
        case .addRM:
            return rmValue > 0
        }
    }

    // Suggested increments — lighter for gym/dumbbell
    private var increments: [Double] { isGymStyle ? [1, 2, 4, 6] : [2.5, 5, 10, 20] }
    private var commonWeights: [Int] { isGymStyle ? [10, 12, 15, 20, 25, 30, 35, 40] : [40, 50, 60, 70, 80, 90, 100, 120] }
    private let gymRepOptions: [Int] = [5, 6, 8, 10, 12, 15, 20]
    
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

                        // Rep calculator (only for 1RM-based exercises)
                        if !isGymStyle { repCalculatorSection }

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

                // Style picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tipo de ejercicio")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        ForEach(EjercicioStyle.allCases, id: \.self) { style in
                            Button {
                                withAnimation(.spring(duration: 0.25)) {
                                    selectedStyle = style
                                }
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                VStack(spacing: 10) {
                                    Image(systemName: style.icon)
                                        .font(.system(size: 32, weight: .semibold))
                                        .foregroundStyle(
                                            selectedStyle == style
                                            ? LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing)
                                            : LinearGradient(colors: [.secondary, .secondary], startPoint: .top, endPoint: .bottom)
                                        )

                                    Text(style.label)
                                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                        .foregroundStyle(selectedStyle == style ? .primary : .secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(
                                                    selectedStyle == style
                                                    ? AnyShapeStyle(LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing))
                                                    : AnyShapeStyle(Color.clear),
                                                    lineWidth: 2
                                                )
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            // RM / Weight field
            VStack(alignment: .leading, spacing: 8) {
                Text(isGymStyle ? "Peso" : "Peso Máximo (RM)")
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

            // Reps field — only for Gym style
            if isGymStyle {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Repeticiones")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    // Stepper visual grande
                    HStack(spacing: 0) {
                        Button {
                            if gymReps > 1 {
                                withAnimation(.spring(duration: 0.2)) { gymReps -= 1 }
                                gymRepsText = "\(gymReps)"
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(gymReps > 1 ? Color.blue : Color.secondary)
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Text("\(gymReps)")
                            .font(.system(size: 56, weight: .black, design: .rounded))
                            .foregroundStyle(Color.blue)
                            .frame(minWidth: 72)
                            .multilineTextAlignment(.center)
                            .contentTransition(.numericText())

                        Text("reps")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 4)

                        Spacer()

                        Button {
                            withAnimation(.spring(duration: 0.2)) { gymReps += 1 }
                            gymRepsText = "\(gymReps)"
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(Color.blue)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // Presets rápidos
                    HStack(spacing: 6) {
                        ForEach(gymRepOptions, id: \.self) { rep in
                            Button {
                                withAnimation(.spring(duration: 0.2)) {
                                    gymReps = rep
                                    gymRepsText = "\(rep)"
                                }
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                Text("\(rep)")
                                    .font(.system(.caption, design: .rounded, weight: .bold))
                                    .foregroundStyle(gymReps == rep ? .white : .blue)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 7)
                                    .background(gymReps == rep ? Color.blue : Color.blue.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Rep Calculator Section
    private var repCalculatorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Toggle header
            Button {
                withAnimation(.spring(duration: 0.3)) {
                    showRepCalculator.toggle()
                    if !showRepCalculator {
                        repWeightText = ""
                        repWeightValue = 0
                        repsText = ""
                        repsValue = 0
                    }
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                HStack {
                    Label("Calcular desde repeticiones", systemImage: "function")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: showRepCalculator ? "chevron.up" : "chevron.down")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if showRepCalculator {
                VStack(spacing: 12) {
                    // Weight + reps inputs
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Peso levantado")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack {
                                TextField("0", text: $repWeightText)
                                    .focused($focusedField, equals: .repWeight)
                                    .keyboardType(.decimalPad)
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .multilineTextAlignment(.center)
                                    .onChange(of: repWeightText) { _, v in
                                        repWeightValue = Double(v) ?? 0
                                    }
                                Text("kg")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(12)
                            .background(Color(uiColor: .secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Repeticiones")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("0", text: $repsText)
                                .focused($focusedField, equals: .reps)
                                .keyboardType(.numberPad)
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .multilineTextAlignment(.center)
                                .onChange(of: repsText) { _, v in
                                    repsValue = Int(v) ?? 0
                                }
                                .padding(12)
                                .background(Color(uiColor: .secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    // Result or hint
                    if let estimated = calculatedRM {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("1RM estimado")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                HStack(alignment: .firstTextBaseline, spacing: 4) {
                                    Text(formatValue(estimated))
                                        .font(.system(size: 28, weight: .bold, design: .rounded))
                                        .foregroundStyle(
                                            LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing)
                                        )
                                    Text("kg")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Button {
                                withAnimation(.spring(duration: 0.3)) {
                                    rmValue = estimated
                                    rmText = formatValue(estimated)
                                    showRepCalculator = false
                                    repWeightText = ""
                                    repWeightValue = 0
                                    repsText = ""
                                    repsValue = 0
                                }
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            } label: {
                                Text("Usar")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(
                                        LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing)
                                    )
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(12)
                        .background(Color.orange.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        Text("Fórmula de Epley: peso × (1 + reps/30)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else if repWeightValue > 0 && repsValue == 1 {
                        Text("Con 1 repetición, el peso levantado ya es tu 1RM")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(10)
                            .background(Color(uiColor: .secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        Text("Introduce el peso y las reps para calcular tu 1RM estimado")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .transition(.asymmetric(
                    insertion: .push(from: .top).combined(with: .opacity),
                    removal: .push(from: .bottom).combined(with: .opacity)
                ))
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
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
                ForEach(commonWeights, id: \.self) { weight in
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
                onSave(name, rmValue, selectedStyle, isGymStyle ? gymReps : nil)
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
    EjercicioFormView(mode: .new) { _, _, _, _ in }
}

#Preview("Add RM") {
    EjercicioFormView(mode: .addRM(ejercicio: .sample)) { _, _, _, _ in }
}