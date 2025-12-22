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
            Form {
                // Name Field (only for new ejercicio)
                if mode.showNameField {
                    Section {
                        TextField("Nombre del ejercicio", text: $name)
                            .focused($focusedField, equals: .name)
                            .textInputAutocapitalization(.words)
                    } header: {
                        Text("Ejercicio")
                    } footer: {
                        Text("Ej: Back Squat, Deadlift, Bench Press...")
                    }
                }
                
                // RM Value
                Section {
                    HStack {
                        TextField("0", text: $rmValue)
                            .focused($focusedField, equals: .rm)
                            .keyboardType(.decimalPad)
                            .font(.title2.bold())
                        
                        Text("kg")
                            .foregroundStyle(.secondary)
                            .font(.title3)
                    }
                } header: {
                    Text("Peso Máximo (RM)")
                } footer: {
                    Text("Introduce el peso máximo que puedes levantar en una repetición")
                }
                
                // Preview of percentages
                if let rm = Double(rmValue), rm > 0 {
                    Section("Vista previa de porcentajes") {
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 8) {
                            ForEach([100, 90, 80, 70, 60, 50], id: \.self) { percent in
                                VStack(spacing: 2) {
                                    Text("\(percent)%")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("\(Int(rm * Double(percent) / 100)) kg")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.orange)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(.orange.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                        .padding(.vertical, 4)
                    }
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
                    Button(mode.buttonTitle) {
                        if let rm = Double(rmValue) {
                            onSave(name, rm)
                            dismiss()
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
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    focusedField = mode.showNameField ? .name : .rm
                }
            }
        }
        .presentationDetents([.medium])
        .interactiveDismissDisabled(!name.isEmpty || !rmValue.isEmpty)
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
