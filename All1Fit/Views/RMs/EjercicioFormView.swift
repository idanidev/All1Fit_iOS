import SwiftUI

enum EjercicioFormMode {
    case new
    case addRM(ejercicio: Ejercicio)
    
    var title: String {
        switch self {
        case .new:
            return "Nuevo Ejercicio"
        case .addRM(let ejercicio):
            return "Añadir RM a \(ejercicio.name)"
        }
    }
    
    var buttonTitle: String {
        switch self {
        case .new:
            return "Crear Ejercicio"
        case .addRM:
            return "Guardar RM"
        }
    }
    
    var showNameField: Bool {
        switch self {
        case .new:
            return true
        case .addRM:
            return false
        }
    }
}

struct EjercicioFormView: View {
    @Environment(\.dismiss) private var dismiss
    
    let mode: EjercicioFormMode
    let onSave: (String, Double) -> Void
    
    @State private var name: String = ""
    @State private var rmValue: String = ""
    @FocusState private var focusedField: Field?
    
    enum Field {
        case name, rm
    }
    
    private var isValid: Bool {
        switch mode {
        case .new:
            return !name.trimmingCharacters(in: .whitespaces).isEmpty &&
                   Double(rmValue) != nil &&
                   (Double(rmValue) ?? 0) > 0
        case .addRM:
            return Double(rmValue) != nil && (Double(rmValue) ?? 0) > 0
        }
    }
    
    var body: some View {
        NavigationStack {
            FormContent(
                mode: mode,
                name: $name,
                rmValue: $rmValue,
                focusedField: $focusedField
            )
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(mode.buttonTitle) {
                        guard let rm = Double(rmValue) else { return }
                        let savedName = name
                        focusedField = nil
                        dismiss()
                        // Ejecutar después de que el dismiss comience
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            onSave(savedName, rm)
                        }
                    }
                    .fontWeight(.semibold)
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
                // ✅ CLAVE: Retrasar el foco hasta que la animación del sheet termine
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    focusedField = mode.showNameField ? .name : .rm
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(false)
    }
}

// MARK: - Form Content (Separated for performance)
private struct FormContent: View {
    let mode: EjercicioFormMode
    @Binding var name: String
    @Binding var rmValue: String
    var focusedField: FocusState<EjercicioFormView.Field?>.Binding
    
    var body: some View {
        Form {
            if mode.showNameField {
                Section {
                    TextField("Nombre del ejercicio", text: $name)
                        .focused(focusedField, equals: .name)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.next)
                        .onSubmit {
                            focusedField.wrappedValue = .rm
                        }
                } header: {
                    Text("Ejercicio")
                } footer: {
                    Text("Ej: Back Squat, Deadlift, Bench Press...")
                }
            }
            
            Section {
                HStack {
                    TextField("0", text: $rmValue)
                        .focused(focusedField, equals: .rm)
                        .keyboardType(.decimalPad)
                        .font(.title2.bold())
                    
                    Text("kg")
                        .foregroundStyle(.secondary)
                        .font(.title3)
                }
            } header: {
                Text("Peso Máximo (RM)")
            } footer: {
                Text("Peso máximo en una repetición")
            }
        }
    }
}

#Preview("New") {
    EjercicioFormView(mode: .new) { name, rm in
        print("Created: \(name) with RM: \(rm)")
    }
}

#Preview("Add RM") {
    EjercicioFormView(mode: .addRM(ejercicio: .sample)) { _, rm in
        print("Added RM: \(rm)")
    }
}
